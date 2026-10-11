#import <Cocoa/Cocoa.h>
#import <errno.h>
#import <fcntl.h>
#import <stdint.h>
#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import "DraftStorage.h"

static NSString * const PDAppName = @"PromptSlip";

static void PDDiagnostic(NSString *message) {
    NSData *data = [[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (data) (void)write(STDERR_FILENO, data.bytes, data.length);
}

static NSString *PDSanitizeStem(NSString *candidate) {
    NSString *stem = candidate ?: @"prompt";
    if ([stem.lowercaseString hasSuffix:@".md"]) stem = [stem substringToIndex:stem.length - 3];
    else if ([stem.lowercaseString hasSuffix:@".txt"]) stem = [stem substringToIndex:stem.length - 4];

    NSMutableString *clean = [NSMutableString string];
    NSString *forbidden = @"<>:\"/\\|?*";
    NSMutableCharacterSet *replacementSet = [[NSCharacterSet characterSetWithCharactersInString:forbidden] mutableCopy];
    [replacementSet formUnionWithCharacterSet:NSCharacterSet.controlCharacterSet];
    for (NSUInteger i = 0; i < stem.length; ) {
        NSRange range = [stem rangeOfComposedCharacterSequenceAtIndex:i];
        NSString *part = [stem substringWithRange:range];
        NSString *replacement = [part rangeOfCharacterFromSet:replacementSet].location == NSNotFound ? part : @"_";
        if (clean.length + replacement.length > 64) break;
        [clean appendString:replacement];
        i = NSMaxRange(range);
    }
    NSString *trimmed = [clean stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". "]];
    if (!trimmed.length) trimmed = @"prompt";
    NSString *firstComponent = [[trimmed componentsSeparatedByString:@"."] firstObject];
    NSString *upper = [[firstComponent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] uppercaseString];
    NSSet *reserved = [NSSet setWithArray:@[@"CON", @"PRN", @"AUX", @"NUL", @"COM1", @"COM2", @"COM3", @"COM4", @"COM5", @"COM6", @"COM7", @"COM8", @"COM9", @"LPT1", @"LPT2", @"LPT3", @"LPT4", @"LPT5", @"LPT6", @"LPT7", @"LPT8", @"LPT9"]];
    if ([reserved containsObject:upper]) trimmed = [@"_" stringByAppendingString:trimmed];
    return trimmed;
}

static NSString *PDAbsoluteDirectory(NSString *path) {
    NSString *expanded = [path stringByExpandingTildeInPath];
    if (![expanded isAbsolutePath]) expanded = [[[NSFileManager.defaultManager currentDirectoryPath] stringByAppendingPathComponent:expanded] stringByStandardizingPath];
    return [expanded stringByStandardizingPath];
}

static NSString *PDDefaultOutputDirectory(void) {
    NSArray<NSURL *> *urls = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSString *base = urls.firstObject.path ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    return [[base stringByAppendingPathComponent:@"PromptSlip"] stringByAppendingPathComponent:@"files"];
}

static NSString *PDWriteSnapshot(NSString *text, NSString *name, NSString *extension, NSString *directory, NSError **errorOut) {
    if (text.length == 0) {
        if (errorOut) *errorOut = [NSError errorWithDomain:PDAppName code:3 userInfo:@{NSLocalizedDescriptionKey: @"Text is empty."}];
        return nil;
    }
    NSString *absoluteDirectory = PDAbsoluteDirectory(directory ?: PDDefaultOutputDirectory());
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:absoluteDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
        if (errorOut) *errorOut = error;
        return nil;
    }
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (errorOut) *errorOut = [NSError errorWithDomain:PDAppName code:1 userInfo:@{NSLocalizedDescriptionKey: @"Text could not be encoded as UTF-8."}];
        return nil;
    }

    NSString *stem = PDSanitizeStem(name);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *stamp = [formatter stringFromDate:NSDate.date];
    for (NSUInteger attempt = 0; attempt < 64; attempt++) {
        NSString *token = [NSUUID.UUID.UUIDString.lowercaseString substringToIndex:8];
        NSString *filename = [NSString stringWithFormat:@"%@_%@_%@.%@", stem, stamp, token, extension];
        NSString *path = [absoluteDirectory stringByAppendingPathComponent:filename];
        int fd = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (fd < 0) {
            if (errno == EEXIST) continue;
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            if (errorOut) *errorOut = error;
            return nil;
        }
        const uint8_t *bytes = data.bytes;
        NSUInteger remaining = data.length;
        BOOL ok = YES;
        while (remaining) {
            ssize_t count = write(fd, bytes, remaining);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { if (count == 0) errno = EIO; ok = NO; break; }
            bytes += count;
            remaining -= (NSUInteger)count;
        }
        int writeErrno = errno;
        if (close(fd) != 0) { ok = NO; writeErrno = errno; }
        if (!ok) {
            (void)unlink(path.fileSystemRepresentation);
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:writeErrno userInfo:nil];
            if (errorOut) *errorOut = error;
            return nil;
        }
        return path;
    }
    if (errorOut) *errorOut = [NSError errorWithDomain:PDAppName code:2 userInfo:@{NSLocalizedDescriptionKey: @"Could not allocate a unique snapshot filename."}];
    return nil;
}

static void PDPrintHelp(void) {
    puts("PromptSlip — save UTF-8 text as a Markdown or text snapshot\n"
         "Usage: promptslip (--stdin | --clipboard) [--output-dir DIR] [--name NAME] [--txt]\n"
         "       promptslip --help\n\n"
         "Without arguments, open the native editor.\n"
         "--stdin       Read strict UTF-8 bytes from stdin without newline conversion.\n"
         "--clipboard   Read the current macOS text clipboard explicitly.\n"
         "--output-dir  Write snapshots under DIR (default: Application Support/PromptSlip/files).\n"
         "--name        Set the filename stem (default: prompt).\n"
         "--txt         Write .txt; default output is .md.");
}

static int PDRunCLI(int argc, const char *argv[]) {
    BOOL useStdin = NO, useClipboard = NO, useTXT = NO;
    BOOL sawName = NO, sawOutputDirectory = NO;
    NSString *outputDirectory = nil, *name = @"prompt";
    if (argc == 2 && strcmp(argv[1], "--help") == 0) { PDPrintHelp(); return 0; }
    for (int i = 1; i < argc; i++) {
        NSString *arg = [NSString stringWithUTF8String:argv[i]];
        if ([arg isEqualToString:@"--help"]) { PDDiagnostic(@"--help must be used by itself."); return 2; }
        else if ([arg isEqualToString:@"--stdin"]) {
            if (useStdin) { PDDiagnostic(@"--stdin may only be specified once."); return 2; }
            useStdin = YES;
        }
        else if ([arg isEqualToString:@"--clipboard"]) {
            if (useClipboard) { PDDiagnostic(@"--clipboard may only be specified once."); return 2; }
            useClipboard = YES;
        }
        else if ([arg isEqualToString:@"--txt"]) {
            if (useTXT) { PDDiagnostic(@"--txt may only be specified once."); return 2; }
            useTXT = YES;
        }
        else if ([arg isEqualToString:@"--name"] || [arg isEqualToString:@"--output-dir"]) {
            BOOL *seen = [arg isEqualToString:@"--name"] ? &sawName : &sawOutputDirectory;
            if (*seen) { PDDiagnostic([NSString stringWithFormat:@"%@ may only be specified once.", arg]); return 2; }
            if (i + 1 >= argc || (argv[i + 1][0] == '-' && argv[i + 1][1] == '-')) { PDDiagnostic([NSString stringWithFormat:@"Missing value for %@.", arg]); return 2; }
            NSString *value = [NSString stringWithUTF8String:argv[++i]];
            if (!value || value.length == 0) { PDDiagnostic([NSString stringWithFormat:@"%@ requires a non-empty UTF-8 value.", arg]); return 2; }
            *seen = YES;
            if ([arg isEqualToString:@"--name"]) name = value;
            else outputDirectory = value;
        } else {
            PDDiagnostic([NSString stringWithFormat:@"Unknown argument: %@", arg ?: @"(invalid UTF-8)"]);
            return 2;
        }
    }
    if (useStdin == useClipboard) { PDDiagnostic(@"Choose exactly one of --stdin or --clipboard."); return 2; }

    NSString *text = nil;
    if (useStdin) {
        NSMutableData *input = [NSMutableData data];
        uint8_t buffer[65536];
        for (;;) {
            ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
            if (count < 0 && errno == EINTR) continue;
            if (count < 0) { PDDiagnostic(@"Could not read stdin."); return 2; }
            if (count == 0) break;
            [input appendBytes:buffer length:(NSUInteger)count];
        }
        text = [[NSString alloc] initWithData:input encoding:NSUTF8StringEncoding];
        if (!text) { PDDiagnostic(@"stdin is not valid UTF-8."); return 2; }
    } else {
        NSString *clipboard = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
        text = clipboard;
        if (!text) { PDDiagnostic(@"The clipboard does not contain text."); return 2; }
    }
    if (text.length == 0) { PDDiagnostic(@"Input is empty."); return 2; }

    NSError *error = nil;
    NSString *path = PDWriteSnapshot(text, name, useTXT ? @"txt" : @"md", outputDirectory, &error);
    if (!path) { PDDiagnostic([NSString stringWithFormat:@"Could not save snapshot: %@", error.localizedDescription ?: @"unknown error"]); return 1; }
    NSData *result = [[path stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (write(STDOUT_FILENO, result.bytes, result.length) != (ssize_t)result.length) {
        PDDiagnostic(@"Snapshot was saved, but its path could not be written to stdout.");
        return 1;
    }
    return 0;
}

@class PDFileCard;

@interface PDAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextView *editor;
@property(nonatomic, strong) NSTextField *filenameField;
@property(nonatomic, strong) NSPopUpButton *formatButton;
@property(nonatomic, strong) PDFileCard *fileCard;
@property(nonatomic, strong) NSString *draftPath;
@property(nonatomic) BOOL draftSaveFailed;
@property(nonatomic) BOOL draftRecoveryBlocked;
@property(nonatomic) BOOL closeDecisionMade;
@property(nonatomic, strong) NSTimer *draftSaveTimer;
@property(nonatomic, strong) NSString *draftRecoveryMessage;
- (NSString *)snapshotPathForCurrentText:(NSError **)error;
- (BOOL)saveDraftOrAsk;
@end

@interface PDFileCard : NSView <NSDraggingSource>
@property(nonatomic, weak) PDAppDelegate *delegate;
@property(nonatomic, strong) NSEvent *mouseDownEvent;
@property(nonatomic) NSPoint mouseDownPoint;
@property(nonatomic) BOOL dragStarted;
@end

@implementation PDFileCard
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedRed:0.92 green:0.95 blue:0.99 alpha:1] setFill];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1, 1) xRadius:12 yRadius:12];
    [path fill];
    [[NSColor colorWithCalibratedRed:0.25 green:0.39 blue:0.58 alpha:1] setStroke];
    path.lineWidth = 1;
    [path stroke];
    NSString *label = @"Drag this file card into your destination";
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium], NSForegroundColorAttributeName: NSColor.labelColor};
    NSSize size = [label sizeWithAttributes:attrs];
    [label drawAtPoint:NSMakePoint((NSWidth(self.bounds) - size.width) / 2, (NSHeight(self.bounds) - size.height) / 2) withAttributes:attrs];
}
- (void)mouseDown:(NSEvent *)event {
    self.mouseDownEvent = event;
    self.mouseDownPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.dragStarted = NO;
}
- (void)mouseDragged:(NSEvent *)event {
    if (self.dragStarted) return;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat dx = point.x - self.mouseDownPoint.x;
    CGFloat dy = point.y - self.mouseDownPoint.y;
    if ((dx * dx + dy * dy) < 16.0) return;
    self.dragStarted = YES;
    NSError *error = nil;
    NSString *path = [self.delegate snapshotPathForCurrentText:&error];
    if (!path) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Could not create the attachment";
        alert.informativeText = error.localizedDescription ?: @"Unknown file error.";
        [alert runModal];
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:fileURL];
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [item setDraggingFrame:NSMakeRect(0, 0, 48, 48) contents:icon];
    [self beginDraggingSessionWithItems:@[item] event:self.mouseDownEvent source:self];
}
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context { return NSDragOperationCopy; }
- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session { return YES; }
@end

@implementation PDAppDelegate
- (void)installMainMenu {
    NSMenu *mainMenu = [NSMenu new];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:PDAppName];
    NSMenuItem *quit = [appMenu addItemWithTitle:@"Quit PromptSlip" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    appMenuItem.submenu = appMenu;

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editMenuItem.submenu = editMenu;
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSApp.mainMenu = mainMenu;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self installMainMenu];
    self.draftPath = [[PDDefaultOutputDirectory() stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"draft.txt"];
    NSString *initialText = @"";
    NSString *corruptBackupPath = nil;
    NSString *supportDirectory = [[self.draftPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSArray<NSString *> *legacyDraftPaths = @[
        [[supportDirectory stringByAppendingPathComponent:@"PasteDrop"] stringByAppendingPathComponent:@"draft.txt"],
        [[supportDirectory stringByAppendingPathComponent:@"pastedrop"] stringByAppendingPathComponent:@"draft.txt"]
    ];
    NSError *readError = nil;
    if (!PDResolveDraft(self.draftPath, legacyDraftPaths, &initialText, &corruptBackupPath, &readError)) {
        self.draftRecoveryBlocked = YES;
        self.draftRecoveryMessage = readError.localizedDescription ?: @"The existing draft could not be read or preserved.";
    } else if (corruptBackupPath) {
        self.draftRecoveryMessage = [NSString stringWithFormat:@"The invalid UTF-8 draft was preserved at:\n%@\n\nThis session can now save a new draft.", corruptBackupPath];
    }

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 540)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"PromptSlip";
    self.window.minSize = NSMakeSize(520, 420);
    self.window.delegate = self;
    NSView *content = self.window.contentView;

    self.filenameField = [NSTextField textFieldWithString:@"prompt"];
    self.filenameField.placeholderString = @"File name";
    self.formatButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.formatButton addItemsWithTitles:@[@".md", @".txt"]];
    NSStackView *nameRow = [NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Filename"], self.filenameField, self.formatButton]];
    nameRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    nameRow.alignment = NSLayoutAttributeCenterY;
    nameRow.spacing = 10;
    nameRow.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:nameRow];
    [self.filenameField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.editor = [NSTextView new];
    self.editor.frame = NSMakeRect(0, 0, 640, 360);
    self.editor.delegate = self;
    self.editor.font = [NSFont systemFontOfSize:14];
    self.editor.string = initialText;
    self.editor.usesFindBar = YES;
    self.editor.allowsUndo = YES;
    self.editor.richText = NO;
    self.editor.importsGraphics = NO;
    self.editor.automaticQuoteSubstitutionEnabled = NO;
    self.editor.automaticDashSubstitutionEnabled = NO;
    self.editor.automaticTextReplacementEnabled = NO;
    self.editor.automaticSpellingCorrectionEnabled = NO;
    self.editor.minSize = NSMakeSize(0, 0);
    self.editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = NO;
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.textContainer.widthTracksTextView = YES;
    NSScrollView *scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = NO;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = self.editor;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:scroll];

    self.fileCard = [[PDFileCard alloc] initWithFrame:NSZeroRect];
    self.fileCard.delegate = self;
    self.fileCard.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.fileCard];
    NSTextField *hint = [NSTextField labelWithString:@"Text stays on this Mac. Each drag creates a new snapshot file."];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [nameRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [nameRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [nameRow.topAnchor constraintEqualToAnchor:content.topAnchor constant:18],
        [self.filenameField.widthAnchor constraintGreaterThanOrEqualToConstant:180],
        [self.formatButton.widthAnchor constraintEqualToConstant:76],
        [scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [scroll.topAnchor constraintEqualToAnchor:nameRow.bottomAnchor constant:14],
        [scroll.bottomAnchor constraintEqualToAnchor:self.fileCard.topAnchor constant:-14],
        [self.fileCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [self.fileCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [self.fileCard.heightAnchor constraintEqualToConstant:64],
        [self.fileCard.bottomAnchor constraintEqualToAnchor:hint.topAnchor constant:-7],
        [hint.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [hint.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-13]
    ]];
    self.window.initialFirstResponder = self.editor;
    [self.window makeFirstResponder:self.editor];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (self.draftRecoveryBlocked || corruptBackupPath) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = self.draftRecoveryBlocked ? @"The saved draft could not be recovered" : @"Invalid draft preserved";
        alert.informativeText = self.draftRecoveryMessage;
        [alert addButtonWithTitle:@"Continue Without Recovery"];
        if (self.draftRecoveryBlocked) [alert addButtonWithTitle:@"Quit"];
        NSModalResponse response = [alert runModal];
        if (self.draftRecoveryBlocked && response == NSAlertSecondButtonReturn) {
            self.closeDecisionMade = YES;
            [NSApp terminate:nil];
        }
    }
}
- (NSString *)snapshotPathForCurrentText:(NSError **)error {
    NSString *extension = self.formatButton.indexOfSelectedItem == 1 ? @"txt" : @"md";
    return PDWriteSnapshot(self.editor.string ?: @"", self.filenameField.stringValue, extension, PDDefaultOutputDirectory(), error);
}
- (void)textDidChange:(NSNotification *)notification {
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    if (self.draftRecoveryBlocked) return;
    self.draftSaveTimer = [NSTimer scheduledTimerWithTimeInterval:0.65 target:self selector:@selector(saveDraftTimerFired:) userInfo:nil repeats:NO];
}
- (BOOL)writeDraft:(NSError **)errorOut {
    if (self.draftRecoveryBlocked) {
        if (errorOut) *errorOut = [NSError errorWithDomain:PDAppName code:4 userInfo:@{NSLocalizedDescriptionKey: @"The unreadable existing draft is being preserved."}];
        return NO;
    }
    NSError *error = nil;
    BOOL saved = PDWriteDraft(self.editor.string ?: @"", self.draftPath, &error);
    self.draftSaveFailed = !saved;
    if (!saved && errorOut) *errorOut = error;
    return saved;
}
- (void)saveDraftTimerFired:(NSTimer *)timer {
    NSError *error = nil;
    [self writeDraft:&error];
}
- (BOOL)saveDraftOrAsk {
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    NSError *error = nil;
    if ([self writeDraft:&error]) {
        self.closeDecisionMade = YES;
        return YES;
    }
    NSAlert *alert = [NSAlert new];
    alert.messageText = self.draftRecoveryBlocked ? @"Existing draft was preserved" : @"Draft could not be saved";
    alert.informativeText = error.localizedDescription ?: @"PromptSlip could not write the local recovery draft.";
    [alert addButtonWithTitle:@"Keep Editing"];
    [alert addButtonWithTitle:@"Close Without Saving"];
    BOOL close = [alert runModal] == NSAlertSecondButtonReturn;
    if (close) self.closeDecisionMade = YES;
    return close;
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
    return [self saveDraftOrAsk];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (self.closeDecisionMade) {
        self.closeDecisionMade = NO;
        return NSTerminateNow;
    }
    return [self saveDraftOrAsk] ? NSTerminateNow : NSTerminateCancel;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1) return PDRunCLI(argc, argv);
        NSApplication *app = NSApplication.sharedApplication;
        PDAppDelegate *delegate = [PDAppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
