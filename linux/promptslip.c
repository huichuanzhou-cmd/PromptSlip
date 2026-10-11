#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <errno.h>
#include <fcntl.h>
#include <glib/gstdio.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
    GtkWidget *window, *editor, *name, *format, *status, *card_title;
    gchar *root, *draft, *drag_path;
    guint save_source;
    gboolean dirty, recovery_blocked;
} App;

static void fail(const gchar *message) {
    g_printerr("promptslip: %s\n", message);
}

static gboolean write_new_file(const gchar *path, const guint8 *data, gsize length, GError **error) {
    int fd = g_open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (fd < 0) {
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno), "cannot create %s: %s", path, g_strerror(errno));
        return FALSE;
    }
    gsize offset = 0;
    while (offset < length) {
        ssize_t n = write(fd, data + offset, length - offset);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) {
            int saved = errno ? errno : EIO;
            close(fd);
            g_unlink(path);
            g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(saved), "cannot write %s: %s", path, g_strerror(saved));
            return FALSE;
        }
        offset += (gsize)n;
    }
    if (fsync(fd) != 0) {
        int saved = errno;
        close(fd);
        g_unlink(path);
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(saved), "cannot sync %s: %s", path, g_strerror(saved));
        return FALSE;
    }
    if (close(fd) != 0) {
        int saved = errno;
        g_unlink(path);
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(saved), "cannot close %s: %s", path, g_strerror(saved));
        return FALSE;
    }
    return TRUE;
}

static gchar *safe_stem(const gchar *input) {
    gchar *stem = g_strdup(input ? input : "");
    g_strstrip(stem);
    gsize len = strlen(stem);
    if (len >= 3 && g_ascii_strcasecmp(stem + len - 3, ".md") == 0) stem[len - 3] = '\0';
    else if (len >= 4 && g_ascii_strcasecmp(stem + len - 4, ".txt") == 0) stem[len - 4] = '\0';
    GString *clean = g_string_new(NULL);
    for (const gchar *p = stem; *p;) {
        gunichar ch = g_utf8_get_char_validated(p, -1);
        if (ch == (gunichar)-1 || ch == (gunichar)-2) { g_string_append_c(clean, '_'); p++; continue; }
        const gchar *next = g_utf8_next_char(p);
        if (g_unichar_iscntrl(ch) || ch == '/' || ch == '\\' || ch == ':' || ch == '*' ||
            ch == '?' || ch == '"' || ch == '<' || ch == '>' || ch == '|') g_string_append_c(clean, '_');
        else g_string_append_len(clean, p, next - p);
        p = next;
    }
    g_free(stem);
    while (clean->len && (clean->str[clean->len - 1] == '.' || clean->str[clean->len - 1] == ' '))
        g_string_truncate(clean, clean->len - 1);
    while (clean->len && (clean->str[0] == '.' || clean->str[0] == ' '))
        g_string_erase(clean, 0, 1);
    if (!clean->len) g_string_assign(clean, "prompt");
    gchar *first_dot = strchr(clean->str, '.');
    gchar *device = first_dot ? g_strndup(clean->str, first_dot - clean->str) : g_strdup(clean->str);
    gboolean reserved = !g_ascii_strcasecmp(device, "CON") || !g_ascii_strcasecmp(device, "PRN") ||
                        !g_ascii_strcasecmp(device, "AUX") || !g_ascii_strcasecmp(device, "NUL");
    if (!reserved && strlen(device) == 4 &&
        (!g_ascii_strncasecmp(device, "COM", 3) || !g_ascii_strncasecmp(device, "LPT", 3)) &&
        device[3] >= '1' && device[3] <= '9') reserved = TRUE;
    if (reserved) g_string_prepend_c(clean, '_');
    g_free(device);
    /* Bound characters and bytes so UTF-8 names stay comfortably under NAME_MAX. */
    GString *bounded = g_string_sized_new(192);
    guint chars = 0;
    for (const gchar *p = clean->str; *p && chars < 64;) {
        const gchar *next = g_utf8_next_char(p);
        if ((gsize)(next - clean->str) > 192) break;
        g_string_append_len(bounded, p, next - p);
        p = next;
        chars++;
    }
    g_string_free(clean, TRUE);
    return g_string_free(bounded, FALSE);
}

static gchar *data_root(void) {
    const gchar *xdg = g_get_user_data_dir();
    return g_build_filename(xdg, "promptslip", NULL);
}

static gchar *files_dir(void) {
    gchar *root = data_root();
    gchar *path = g_build_filename(root, "files", NULL);
    g_free(root);
    return path;
}

static gchar *make_snapshot(const gchar *text, gsize length, const gchar *name, const gchar *extension,
                            const gchar *directory, GError **error) {
    if (!length) {
        g_set_error_literal(error, G_FILE_ERROR, G_FILE_ERROR_INVAL, "input is empty");
        return NULL;
    }
    if (!g_utf8_validate(text, (gssize)length, NULL)) {
        g_set_error_literal(error, G_FILE_ERROR, G_FILE_ERROR_INVAL, "input is not valid UTF-8");
        return NULL;
    }
    if (g_mkdir_with_parents(directory, 0700) != 0) {
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno), "cannot create output directory: %s", g_strerror(errno));
        return NULL;
    }
    gchar *stem = safe_stem(name);
    gchar *result = NULL;
    for (guint attempt = 0; attempt < 64; attempt++) {
        gchar *leaf = g_strdup_printf("%s_%" G_GINT64_FORMAT "_%08x%s", stem,
                g_get_real_time() / G_USEC_PER_SEC, g_random_int(), extension);
        gchar *candidate = g_build_filename(directory, leaf, NULL);
        g_free(leaf);
        if (write_new_file(candidate, (const guint8 *)text, length, error)) { result = candidate; break; }
        if (!error || !*error || (*error)->code != G_FILE_ERROR_EXIST) { g_free(candidate); break; }
        g_clear_error(error);
        g_free(candidate);
    }
    if (!result && error && !*error) g_set_error_literal(error, G_FILE_ERROR, G_FILE_ERROR_EXIST, "could not allocate a unique snapshot name");
    g_free(stem);
    return result;
}

static gchar *read_stdin_bytes(gsize *length, GError **error) {
    GByteArray *bytes = g_byte_array_new();
    guint8 chunk[16384];
    for (;;) {
        ssize_t n = read(STDIN_FILENO, chunk, sizeof chunk);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) {
            g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno), "cannot read stdin: %s", g_strerror(errno));
            g_byte_array_unref(bytes);
            return NULL;
        }
        if (n == 0) break;
        g_byte_array_append(bytes, chunk, (guint)n);
    }
    *length = bytes->len;
    g_byte_array_append(bytes, (const guint8 *)"\0", 1);
    return (gchar *)g_byte_array_free(bytes, FALSE);
}

static void print_help(void) {
    puts("Usage: promptslip [--stdin | --clipboard] [--output-dir DIR] [--name NAME] [--txt] [--help]\n"
         "  --stdin       Read strict UTF-8 bytes from stdin (headless)\n"
         "  --clipboard   Read text from the desktop clipboard\n"
         "  --output-dir  Choose the attachment directory\n"
         "  --name        Choose the filename stem (default: prompt)\n"
         "  --txt         Write a .txt file (default: .md)\n"
         "  --help        Show this help");
}

static gboolean cli_run(int argc, char **argv, gboolean *did_help) {
    gboolean stdin_mode = FALSE, clipboard_mode = FALSE, txt = FALSE;
    const gchar *name = "prompt", *directory = NULL;
    *did_help = FALSE;
    guint seen = 0;
    for (int i = 1; i < argc; i++) {
        const gchar *options[] = {"--help", "--stdin", "--clipboard", "--txt", "--name", "--output-dir"};
        for (guint k = 0; k < G_N_ELEMENTS(options); k++) {
            if (strcmp(argv[i], options[k]) != 0) continue;
            guint bit = 1u << k;
            if (seen & bit) { fail("duplicate option"); return FALSE; }
            seen |= bit;
        }
        if (strcmp(argv[i], "--help") == 0) { *did_help = TRUE; continue; }
        else if (strcmp(argv[i], "--stdin") == 0) stdin_mode = TRUE;
        else if (strcmp(argv[i], "--clipboard") == 0) clipboard_mode = TRUE;
        else if (strcmp(argv[i], "--txt") == 0) txt = TRUE;
        else if (strcmp(argv[i], "--name") == 0 || strcmp(argv[i], "--output-dir") == 0) {
            gboolean is_name = strcmp(argv[i], "--name") == 0;
            if (++i >= argc || argv[i][0] == '\0' || g_str_has_prefix(argv[i], "--")) { fail("option requires a value"); return FALSE; }
            if (is_name) name = argv[i]; else directory = argv[i];
        } else { fail("unknown option"); return FALSE; }
    }
    if (*did_help) {
        if (stdin_mode || clipboard_mode || txt || directory || strcmp(name, "prompt") != 0 || argc != 2) { fail("--help must be used alone"); return FALSE; }
        print_help(); return TRUE;
    }
    if (stdin_mode == clipboard_mode) { fail("choose exactly one of --stdin or --clipboard"); return FALSE; }
    if (stdin_mode) {
        gsize length = 0;
        GError *error = NULL;
        gchar *bytes = read_stdin_bytes(&length, &error);
        if (!bytes) { fail(error->message); g_error_free(error); return FALSE; }
        gchar *owned_directory = directory ? g_canonicalize_filename(directory, NULL) : files_dir();
        gchar *path = make_snapshot(bytes, length, name, txt ? ".txt" : ".md", owned_directory, &error);
        g_free(bytes); g_free(owned_directory);
        if (!path) { fail(error ? error->message : "could not create attachment"); g_clear_error(&error); return FALSE; }
        puts(path); g_free(path); return TRUE;
    }
    return TRUE; /* Clipboard mode continues after GTK initialization. */
}

static gboolean save_draft(App *app, GError **error) {
    if (!app->dirty) return TRUE;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->editor));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    gchar *text = gtk_text_buffer_get_text(buffer, &start, &end, TRUE);
    gchar *parent = g_path_get_dirname(app->draft);
    if (g_mkdir_with_parents(parent, 0700) != 0) {
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno), "cannot create draft directory: %s", g_strerror(errno));
        g_free(parent); g_free(text); return FALSE;
    }
    gboolean ok = FALSE;
    if (app->recovery_blocked) {
        for (guint attempt = 0; attempt < 64 && !ok; attempt++) {
            gchar *candidate = g_strdup_printf("%s/draft-recovery-%" G_GINT64_FORMAT "-%08x.txt", parent,
                    g_get_real_time() / G_USEC_PER_SEC, g_random_int());
            if (write_new_file(candidate, (const guint8 *)text, strlen(text), error)) {
                g_free(app->draft);
                app->draft = candidate;
                app->recovery_blocked = FALSE;
                ok = TRUE;
            } else if (error && *error && (*error)->code == G_FILE_ERROR_EXIST) {
                g_clear_error(error);
                g_free(candidate);
            } else { g_free(candidate); break; }
        }
        if (!ok && error && !*error) g_set_error_literal(error, G_FILE_ERROR, G_FILE_ERROR_EXIST, "could not allocate a recovery draft name");
    } else {
        gchar *temporary = g_strdup_printf("%s.tmp.%08x", app->draft, g_random_int());
        ok = write_new_file(temporary, (const guint8 *)text, strlen(text), error);
        if (ok && g_rename(temporary, app->draft) != 0) {
            g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno), "cannot replace draft: %s", g_strerror(errno));
            ok = FALSE;
        }
        if (!ok) g_unlink(temporary);
        g_free(temporary);
    }
    if (ok) app->dirty = FALSE;
    g_free(parent); g_free(text);
    return ok;
}

static gboolean save_debounced(gpointer data) {
    App *app = data;
    app->save_source = 0;
    GError *error = NULL;
    if (!save_draft(app, &error)) {
        gchar *message = g_strdup_printf("Draft save failed: %s", error->message);
        gtk_label_set_text(GTK_LABEL(app->status), message);
        g_free(message); g_error_free(error);
    } else gtk_label_set_text(GTK_LABEL(app->status), "Draft saved locally. Drag the card to export a Markdown file.");
    return G_SOURCE_REMOVE;
}

static void on_changed(GtkTextBuffer *buffer, gpointer data) {
    (void)buffer;
    App *app = data;
    app->dirty = TRUE;
    if (app->save_source) g_source_remove(app->save_source);
    app->save_source = g_timeout_add(700, save_debounced, app);
}

static void update_card(App *app) {
    const gchar *typed = gtk_entry_get_text(GTK_ENTRY(app->name));
    gchar *stem = safe_stem(typed);
    const gchar *ext = gtk_combo_box_get_active(GTK_COMBO_BOX(app->format)) == 0 ? ".txt" : ".md";
    gchar *title = g_strdup_printf("%s%s", stem, ext);
    gtk_label_set_text(GTK_LABEL(app->card_title), title);
    g_free(stem); g_free(title);
}

static void on_name_changed(GtkEditable *editable, gpointer data) { (void)editable; update_card(data); }
static void on_format_changed(GtkComboBox *box, gpointer data) { (void)box; update_card(data); }

static void on_paste(GtkButton *button, gpointer data) {
    (void)button;
    App *app = data;
    GtkClipboard *clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    gchar *text = gtk_clipboard_wait_for_text(clipboard);
    if (!text) { gtk_label_set_text(GTK_LABEL(app->status), "Clipboard has no text."); return; }
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->editor));
    gtk_text_buffer_insert_at_cursor(buffer, text, -1);
    g_free(text);
}

static void on_clear(GtkButton *button, gpointer data) {
    (void)button;
    App *app = data;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->editor));
    gtk_text_buffer_set_text(buffer, "", 0);
}

static void on_drag_begin(GtkWidget *widget, GdkDragContext *context, gpointer data) {
    (void)widget; (void)context;
    App *app = data;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->editor));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    gchar *text = gtk_text_buffer_get_text(buffer, &start, &end, TRUE);
    const gchar *typed = gtk_entry_get_text(GTK_ENTRY(app->name));
    const gchar *ext = gtk_combo_box_get_active(GTK_COMBO_BOX(app->format)) == 0 ? ".txt" : ".md";
    GError *error = NULL;
    g_free(app->drag_path);
    app->drag_path = make_snapshot(text, strlen(text), typed, ext, app->root, &error);
    g_free(text);
    if (!app->drag_path) {
        gtk_label_set_text(GTK_LABEL(app->status), error ? error->message : "Unable to create attachment.");
        g_clear_error(&error);
    } else {
        if (app->save_source) { g_source_remove(app->save_source); app->save_source = 0; }
        app->dirty = TRUE;
        if (!save_draft(app, &error)) {
            gchar *message = g_strdup_printf("Attachment created; draft save failed: %s", error->message);
            gtk_label_set_text(GTK_LABEL(app->status), message); g_free(message); g_clear_error(&error);
        } else gtk_label_set_text(GTK_LABEL(app->status), "Snapshot ready. Confirm the website shows the attachment before sending.");
    }
}

static void on_drag_data_get(GtkWidget *widget, GdkDragContext *context, GtkSelectionData *selection,
                             guint info, guint time, gpointer data) {
    (void)widget; (void)context; (void)info; (void)time;
    App *app = data;
    if (!app->drag_path) return;
    gchar *uri = g_filename_to_uri(app->drag_path, NULL, NULL);
    if (uri) { gchar *uris[] = { uri, NULL }; gtk_selection_data_set_uris(selection, uris); g_free(uri); }
}

static gboolean on_delete(GtkWidget *widget, GdkEvent *event, gpointer data) {
    (void)event;
    App *app = data;
    if (app->save_source) { g_source_remove(app->save_source); app->save_source = 0; }
    GError *error = NULL;
    if (save_draft(app, &error)) return FALSE;
    GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(widget), GTK_DIALOG_MODAL, GTK_MESSAGE_WARNING,
            GTK_BUTTONS_NONE, "The draft could not be saved.");
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s\nClose anyway and lose this draft?", error->message);
    gtk_dialog_add_buttons(GTK_DIALOG(dialog), "Keep editing", GTK_RESPONSE_CANCEL, "Close anyway", GTK_RESPONSE_ACCEPT, NULL);
    gboolean close_anyway = gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT;
    gtk_widget_destroy(dialog); g_error_free(error);
    return !close_anyway;
}

static void on_window_destroy(GtkWidget *widget, gpointer data) {
    (void)widget; (void)data;
    gtk_main_quit();
}

static GtkWidget *make_button(const gchar *label, GCallback callback, gpointer data) {
    GtkWidget *button = gtk_button_new_with_label(label);
    if (callback) g_signal_connect(button, "clicked", callback, data);
    return button;
}

static gboolean read_valid_draft(const gchar *path, gchar **contents, gsize *length, GError **error) {
    if (!g_file_get_contents(path, contents, length, error)) return FALSE;
    if (!g_utf8_validate(*contents, (gssize)*length, NULL)) {
        g_free(*contents);
        *contents = NULL;
        g_set_error_literal(error, G_FILE_ERROR, G_FILE_ERROR_INVAL, "draft is not valid UTF-8");
        return FALSE;
    }
    return TRUE;
}

static gboolean copy_legacy_draft(const gchar *path, const gchar *legacy_path, GError **error) {
    if (g_file_test(path, G_FILE_TEST_EXISTS) || !g_file_test(legacy_path, G_FILE_TEST_EXISTS)) return TRUE;
    gchar *contents = NULL;
    gsize length = 0;
    GError *read_error = NULL;
    if (!read_valid_draft(legacy_path, &contents, &length, &read_error)) {
        g_set_error(error, G_FILE_ERROR, read_error ? read_error->code : G_FILE_ERROR_FAILED,
                    "legacy draft at %s could not be read and was left untouched: %s",
                    legacy_path, read_error ? read_error->message : "unknown read error");
        g_clear_error(&read_error);
        return FALSE;
    }
    gchar *parent = g_path_get_dirname(path);
    if (g_mkdir_with_parents(parent, 0700) != 0) {
        g_set_error(error, G_FILE_ERROR, g_file_error_from_errno(errno),
                    "legacy draft at %s was read but could not be copied to %s; the original was left untouched: %s",
                    legacy_path, path, g_strerror(errno));
        g_free(parent);
        g_free(contents);
        return FALSE;
    }
    g_free(parent);
    GError *copy_error = NULL;
    if (!write_new_file(path, (const guint8 *)contents, length, &copy_error)) {
        if (copy_error && copy_error->code == G_FILE_ERROR_EXIST) {
            g_clear_error(&copy_error);
            g_free(contents);
            return TRUE; /* A concurrently created PromptSlip draft wins. */
        }
        g_set_error(error, G_FILE_ERROR, copy_error ? copy_error->code : G_FILE_ERROR_FAILED,
                    "legacy draft at %s could not be copied to %s; the original was left untouched: %s",
                    legacy_path, path, copy_error ? copy_error->message : "unknown write error");
        g_clear_error(&copy_error);
        g_free(contents);
        return FALSE;
    }
    g_free(contents);
    return TRUE;
}

static gchar *latest_recovery_draft(const gchar *base) {
    GError *error = NULL;
    GDir *dir = g_dir_open(base, 0, &error);
    if (!dir) { g_clear_error(&error); return NULL; }
    const gchar *entry;
    gchar *latest = NULL;
    while ((entry = g_dir_read_name(dir))) {
        if (!g_str_has_prefix(entry, "draft-recovery-") || !g_str_has_suffix(entry, ".txt")) continue;
        if (!latest || strcmp(entry, latest) > 0) {
            g_free(latest);
            latest = g_strdup(entry);
        }
    }
    g_dir_close(dir);
    if (!latest) return NULL;
    gchar *path = g_build_filename(base, latest, NULL);
    g_free(latest);
    return path;
}

static void open_gui(const gchar *directory) {
    App app = {0};
    app.root = directory ? g_canonicalize_filename(directory, NULL) : files_dir();
    gchar *base = data_root();
    app.draft = g_build_filename(base, "draft.txt", NULL);
    const gchar *legacy_base = g_get_user_data_dir();
    gchar *legacy_lower = g_build_filename(legacy_base, "pastedrop", "draft.txt", NULL);
    gchar *legacy_upper = g_build_filename(legacy_base, "PasteDrop", "draft.txt", NULL);
    const gchar *legacy_path = g_file_test(legacy_lower, G_FILE_TEST_EXISTS) ? legacy_lower : legacy_upper;
    GError *migration_error = NULL;
    (void)copy_legacy_draft(app.draft, legacy_path, &migration_error);
    g_free(legacy_lower);
    g_free(legacy_upper);
    g_free(base);

    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    g_signal_connect(app.window, "destroy", G_CALLBACK(on_window_destroy), NULL);
    gtk_window_set_title(GTK_WINDOW(app.window), "PromptSlip · Drag text as a file");
    gtk_window_set_default_size(GTK_WINDOW(app.window), 650, 720);
    gtk_window_set_position(GTK_WINDOW(app.window), GTK_WIN_POS_CENTER);
    GtkWidget *outer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(outer), 20);
    gtk_container_add(GTK_CONTAINER(app.window), outer);
    GtkWidget *heading = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(heading), "<b><big>Paste a long text, then drag it out</big></b>\nPaste or type → drag the card → confirm the upload in your browser");
    gtk_label_set_xalign(GTK_LABEL(heading), 0.0);
    gtk_box_pack_start(GTK_BOX(outer), heading, FALSE, FALSE, 0);
    GtkWidget *tools = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_pack_start(GTK_BOX(outer), tools, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(tools), make_button("Paste clipboard", G_CALLBACK(on_paste), &app), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(tools), make_button("Clear", G_CALLBACK(on_clear), &app), FALSE, FALSE, 0);

    GtkWidget *scroller = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroller), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_vexpand(scroller, TRUE);
    gtk_box_pack_start(GTK_BOX(outer), scroller, TRUE, TRUE, 0);
    app.editor = gtk_text_view_new();
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(app.editor), GTK_WRAP_WORD_CHAR);
    gtk_text_view_set_accepts_tab(GTK_TEXT_VIEW(app.editor), TRUE);
    gtk_container_add(GTK_CONTAINER(scroller), app.editor);
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app.editor));
    g_signal_connect(buffer, "changed", G_CALLBACK(on_changed), &app);

    GtkWidget *options = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_pack_start(GTK_BOX(outer), options, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(options), gtk_label_new("Filename"), FALSE, FALSE, 0);
    app.name = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(app.name), "prompt");
    gtk_widget_set_hexpand(app.name, TRUE);
    gtk_box_pack_start(GTK_BOX(options), app.name, TRUE, TRUE, 0);
    app.format = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(app.format), ".txt");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(app.format), ".md");
    gtk_combo_box_set_active(GTK_COMBO_BOX(app.format), 1);
    gtk_box_pack_start(GTK_BOX(options), app.format, FALSE, FALSE, 0);
    g_signal_connect(app.name, "changed", G_CALLBACK(on_name_changed), &app);
    g_signal_connect(app.format, "changed", G_CALLBACK(on_format_changed), &app);

    GtkWidget *card = gtk_event_box_new();
    gtk_widget_set_size_request(card, -1, 94);
    gtk_widget_set_events(card, gtk_widget_get_events(card) | GDK_BUTTON_PRESS_MASK);
    GtkWidget *card_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 18);
    gtk_container_set_border_width(GTK_CONTAINER(card_box), 18);
    gtk_container_add(GTK_CONTAINER(card), card_box);
    GtkWidget *badge = gtk_label_new("FILE");
    gtk_box_pack_start(GTK_BOX(card_box), badge, FALSE, FALSE, 0);
    app.card_title = gtk_label_new("prompt.md");
    gtk_label_set_xalign(GTK_LABEL(app.card_title), 0.0);
    gtk_widget_set_hexpand(app.card_title, TRUE);
    gtk_box_pack_start(GTK_BOX(card_box), app.card_title, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(outer), card, FALSE, TRUE, 0);
    GtkTargetEntry targets[] = { { "text/uri-list", 0, 0 } };
    gtk_drag_source_set(card, GDK_BUTTON1_MASK, targets, G_N_ELEMENTS(targets), GDK_ACTION_COPY);
    g_signal_connect(card, "drag-begin", G_CALLBACK(on_drag_begin), &app);
    g_signal_connect(card, "drag-data-get", G_CALLBACK(on_drag_data_get), &app);

    app.status = gtk_label_new("Local only. Confirm the file appears on the website before sending.");
    gtk_label_set_xalign(GTK_LABEL(app.status), 0.0);
    gtk_box_pack_start(GTK_BOX(outer), app.status, FALSE, FALSE, 0);
    g_signal_connect(app.window, "delete-event", G_CALLBACK(on_delete), &app);
    gchar *saved = NULL;
    gsize saved_length = 0;
    GError *recovery_error = migration_error;
    gboolean has_primary = g_file_test(app.draft, G_FILE_TEST_EXISTS);
    gboolean recovered = has_primary && read_valid_draft(app.draft, &saved, &saved_length, &recovery_error);
    if (!has_primary && !recovery_error) g_clear_error(&recovery_error);
    if (!recovered) {
        gchar *draft_dir = g_path_get_dirname(app.draft);
        gchar *fallback = latest_recovery_draft(draft_dir);
        g_free(draft_dir);
        if (fallback) {
            GError *fallback_error = NULL;
            if (read_valid_draft(fallback, &saved, &saved_length, &fallback_error)) {
                g_free(app.draft);
                app.draft = fallback;
                fallback = NULL;
                if (recovery_error) {
                    gchar *detail = g_strdup(recovery_error->message);
                    g_clear_error(&recovery_error);
                    g_set_error(&recovery_error, G_FILE_ERROR, G_FILE_ERROR_FAILED,
                                "A recovery copy was loaded; the legacy draft issue remains: %s", detail);
                    g_free(detail);
                } else recovery_error = g_error_new_literal(G_FILE_ERROR, G_FILE_ERROR_FAILED, "The original draft could not be read and was preserved; a recovery copy was loaded.");
            } else if (!recovery_error) recovery_error = fallback_error;
            else g_clear_error(&fallback_error);
            g_free(fallback);
        }
    }
    if (saved) {
        g_signal_handlers_block_by_func(buffer, G_CALLBACK(on_changed), &app);
        gtk_text_buffer_set_text(buffer, saved, (gint)saved_length);
        g_signal_handlers_unblock_by_func(buffer, G_CALLBACK(on_changed), &app);
        if (recovery_error) {
            gchar *message = g_strdup_printf("%s", recovery_error->message);
            gtk_label_set_text(GTK_LABEL(app.status), message);
            g_free(message);
        }
    } else if (recovery_error) {
        app.recovery_blocked = TRUE;
        gchar *message = g_strdup_printf("Recovery failed; the existing draft is preserved. New edits will save separately. %s", recovery_error->message);
        gtk_label_set_text(GTK_LABEL(app.status), message);
        g_free(message);
    }
    g_free(saved);
    g_clear_error(&recovery_error);
    update_card(&app);
    gtk_widget_show_all(app.window);
    gtk_main();
    if (app.save_source) g_source_remove(app.save_source);
    g_free(app.drag_path); g_free(app.draft); g_free(app.root);
}

int main(int argc, char **argv) {
    setlocale(LC_ALL, "");
    gboolean help = FALSE;
    /* Parse once before any GTK call so stdin mode remains headless. */
    gboolean wants_clipboard = FALSE;
    for (int i = 1; i < argc; i++) if (strcmp(argv[i], "--clipboard") == 0) wants_clipboard = TRUE;
    if (argc > 1) {
        if (!cli_run(argc, argv, &help)) return 2;
        /* cli_run validates clipboard flags but leaves desktop access to GTK below. */
        if (!wants_clipboard) return 0;
    }
    if (!gtk_init_check(NULL, NULL)) { fail("a desktop display is required for the GUI or --clipboard"); return 2; }
    if (wants_clipboard) {
        /* Reparse now that GTK is initialized; clipboard is an explicit request. */
        gboolean stdin_mode = FALSE, txt = FALSE;
        const gchar *name = "prompt", *directory = NULL;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--stdin")) stdin_mode = TRUE;
            else if (!strcmp(argv[i], "--txt")) txt = TRUE;
            else if ((!strcmp(argv[i], "--name") || !strcmp(argv[i], "--output-dir")) && i + 1 < argc) {
                gboolean is_name = !strcmp(argv[i], "--name");
                if (is_name) name = argv[++i]; else directory = argv[++i];
            } else if (!strcmp(argv[i], "--clipboard")) {}
            else { fail("unknown option"); return 2; }
        }
        if (stdin_mode) { fail("choose exactly one input source"); return 2; }
        GtkClipboard *clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
        gchar *text = gtk_clipboard_wait_for_text(clipboard);
        if (!text || !*text) { g_free(text); fail("clipboard is empty or contains no text"); return 2; }
        gchar *owned = directory ? g_canonicalize_filename(directory, NULL) : files_dir();
        GError *error = NULL;
        gchar *path = make_snapshot(text, strlen(text), name, txt ? ".txt" : ".md", owned, &error);
        g_free(text); g_free(owned);
        if (!path) { fail(error->message); g_error_free(error); return 2; }
        puts(path); g_free(path); return 0;
    }
    if (argc != 1) { fail("unknown option"); return 2; }
    open_gui(NULL);
    return 0;
}
