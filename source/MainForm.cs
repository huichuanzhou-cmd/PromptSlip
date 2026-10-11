using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace PromptSlip {
    public sealed class PlainEditor : RichTextBox {
        public PlainEditor() { MaxLength = Int32.MaxValue; DetectUrls = false; AcceptsTab = true; EnableAutoDragDrop = false; }
        public void PastePlain() {
            if (Clipboard.ContainsText(TextDataFormat.UnicodeText)) SelectedText = Clipboard.GetText(TextDataFormat.UnicodeText);
        }
        protected override void WndProc(ref Message m) {
            if (m.Msg == 0x302) {
                try { PastePlain(); } catch (Exception ex) { MessageBox.Show("无法读取剪贴板：" + ex.Message, "PromptSlip"); }
                return;
            }
            base.WndProc(ref m);
        }
        protected override bool ProcessCmdKey(ref Message msg, Keys keyData) {
            if (keyData == (Keys.Control | Keys.V) || keyData == (Keys.Shift | Keys.Insert)) {
                try { PastePlain(); } catch (Exception ex) { MessageBox.Show("无法读取剪贴板：" + ex.Message, "PromptSlip"); }
                return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }
    }

    public sealed class MainForm : Form {
        private readonly PlainEditor editor = new PlainEditor();
        private readonly TextBox filename = new TextBox();
        private readonly ComboBox extension = new ComboBox();
        private readonly Label count = new Label(), cardTitle = new Label(), cardHint = new Label(), status = new Label();
        private readonly Panel card = new Panel();
        private readonly Timer refresh = new Timer();
        private readonly TextAssetStore store;
        private readonly string draftPath;
        private Point dragOrigin;
        private bool dragging, dirty, draftReadBlocked;
        private readonly Color purple = Color.FromArgb(91, 69, 208);

        public MainForm(string dataRoot) {
            store = new TextAssetStore(Path.Combine(dataRoot, "文件"));
            draftPath = Path.Combine(dataRoot, "数据", "草稿.txt");
            Text = "PromptSlip · 长文本拖成附件";
            Font = new Font("Microsoft YaHei UI", 10F);
            BackColor = Color.FromArgb(246, 247, 251);
            ForeColor = Color.FromArgb(35, 41, 57);
            ClientSize = new Size(650, 770); MinimumSize = new Size(510, 650);
            StartPosition = FormStartPosition.CenterScreen;
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 1, RowCount = 7 };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 43));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 112));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
            Controls.Add(layout);
            var header = new Panel { Dock = DockStyle.Fill };
            header.Controls.Add(new Label { Text = "长文本，轻松拖出去。", Font = new Font(Font.FontFamily, 21F, FontStyle.Bold), AutoSize = true, Location = new Point(0, 0) });
            header.Controls.Add(new Label { Text = "粘贴完整内容 → 拖动文件卡片 → 在网页确认发送", AutoSize = true, ForeColor = Color.DimGray, Location = new Point(2, 46) });
            layout.Controls.Add(header, 0, 0);
            var toolbar = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
            var paste = MakeButton("粘贴剪贴板", delegate { editor.Focus(); editor.PastePlain(); });
            toolbar.Controls.Add(paste);
            toolbar.Controls.Add(MakeButton("清空", delegate {
                if (editor.TextLength > 0 && MessageBox.Show(this, "清空当前草稿？已经拖出的文件会保留。", "清空草稿", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK) editor.Clear();
                editor.Focus();
            }));
            var pin = new CheckBox { Text = "窗口置顶", AutoSize = true, Margin = new Padding(12, 8, 0, 0) };
            pin.CheckedChanged += delegate { TopMost = pin.Checked; };
            toolbar.Controls.Add(pin);
            count.AutoSize = true; count.Margin = new Padding(16, 8, 0, 0); count.ForeColor = Color.DimGray;
            toolbar.Controls.Add(count);
            layout.Controls.Add(toolbar, 0, 1);
            var editorFrame = new Panel { Dock = DockStyle.Fill, BackColor = Color.White, Padding = new Padding(14), Margin = new Padding(0, 0, 0, 5) };
            editor.Dock = DockStyle.Fill; editor.BorderStyle = BorderStyle.None; editor.BackColor = Color.White;
            editor.Font = new Font("Microsoft YaHei UI", 11F); editor.ScrollBars = RichTextBoxScrollBars.Vertical;
            editor.AccessibleName = "完整提示词文本";
            editorFrame.Controls.Add(editor); layout.Controls.Add(editorFrame, 0, 2);
            var options = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, Padding = new Padding(0, 10, 0, 8), Margin = Padding.Empty };
            options.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 68)); options.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); options.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 82));
            options.Controls.Add(new Label { Text = "文件名", AutoSize = true, Margin = new Padding(0, 5, 0, 0) }, 0, 0);
            filename.Text = "提示词"; filename.Dock = DockStyle.Fill; filename.MaxLength = 120; filename.AccessibleName = "附件文件名";
            options.Controls.Add(filename, 1, 0);
            extension.DropDownStyle = ComboBoxStyle.DropDownList; extension.Items.AddRange(new object[]{".txt", ".md"}); extension.SelectedIndex = 1; extension.Dock = DockStyle.Fill;
            options.Controls.Add(extension, 2, 0); layout.Controls.Add(options, 0, 3);
            card.Dock = DockStyle.Fill; card.BackColor = Color.FromArgb(236, 232, 255); card.Cursor = Cursors.Hand; card.Margin = new Padding(0, 3, 0, 6);
            card.AccessibleName = "拖出完整文件";
            var badge = new Label { Text = "MD", TextAlign = ContentAlignment.MiddleCenter, Font = new Font(Font.FontFamily, 13F, FontStyle.Bold), ForeColor = purple, BackColor = Color.White, Location = new Point(17, 20), Size = new Size(58, 58) };
            cardTitle.Text = "提示词.md"; cardTitle.Font = new Font(Font.FontFamily, 13F, FontStyle.Bold); cardTitle.ForeColor = purple; cardTitle.Location = new Point(92, 19); cardTitle.Size = new Size(460, 29); cardTitle.AutoEllipsis = true;
            cardHint.Text = "先粘贴文本，再按住这里拖到网页上传区"; cardHint.Location = new Point(92, 53); cardHint.Size = new Size(460, 30); cardHint.ForeColor = purple;
            card.Controls.Add(badge); card.Controls.Add(cardTitle); card.Controls.Add(cardHint);
            card.Resize += delegate { cardTitle.Width = Math.Max(40, card.Width - 110); cardHint.Width = cardTitle.Width; };
            WireDrag(card); layout.Controls.Add(card, 0, 4);
            var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false, Margin = Padding.Empty };
            actions.Controls.Add(MakeButton("复制文件", delegate {
                string path = PrepareCurrent(); Clipboard.SetDataObject(TextAssetStore.FileData(path), true);
                SetStatus("文件已复制；可在支持文件粘贴的网页按 Ctrl+V。", false);
            }));
            actions.Controls.Add(MakeButton("打开文件位置", delegate {
                string path = PrepareCurrent(); Process.Start("explorer.exe", "/select,\"" + path + "\"");
            }));
            layout.Controls.Add(actions, 0, 5);
            status.Dock = DockStyle.Fill; status.Font = new Font(Font.FontFamily, 9F); status.ForeColor = Color.DimGray;
            status.Text = "本地存储：" + Path.GetFullPath(dataRoot) + "\n拖到网页后，确认附件已出现，再发送。";
            layout.Controls.Add(status, 0, 6);
            refresh.Interval = 650;
            refresh.Tick += delegate { refresh.Stop(); UpdateInfo(); try { SaveDraft(); } catch (Exception ex) { SetStatus("草稿保存失败：" + ex.Message, true); } };
            editor.TextChanged += delegate { dirty = true; refresh.Stop(); refresh.Start(); };
            filename.TextChanged += delegate { UpdateInfo(); };
            extension.SelectedIndexChanged += delegate { badge.Text = extension.SelectedIndex == 0 ? "TXT" : "MD"; UpdateInfo(); };
            try {
                if (File.Exists(draftPath)) {
                    try { editor.Text = new UTF8Encoding(false, true).GetString(File.ReadAllBytes(draftPath)); }
                    catch (DecoderFallbackException) {
                        string backup = draftPath + ".corrupt-" + Guid.NewGuid().ToString("N");
                        File.Move(draftPath, backup);
                        SetStatus("损坏草稿已保留：" + backup + "\n新内容仍会保存为原位置的草稿。", true);
                    }
                }
            }
            catch (Exception ex) { draftReadBlocked = true; SetStatus("草稿读取失败，原文件保留：" + ex.Message, true); }
            UpdateInfo();
            FormClosing += delegate(object sender, FormClosingEventArgs args) {
                refresh.Stop();
                try { SaveDraft(); }
                catch (Exception ex) {
                    args.Cancel = MessageBox.Show(this, "草稿无法保存：" + ex.Message + "\n仍然关闭会丢失本次修改。确定关闭？", "草稿未保存", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes;
                }
            };
            FormClosed += delegate { refresh.Dispose(); };
        }
        private Button MakeButton(string title, Action action) {
            var button = new Button { Text = title, AutoSize = true, Height = 32, FlatStyle = FlatStyle.Flat, BackColor = Color.White, Padding = new Padding(8, 0, 8, 0), Margin = new Padding(0, 0, 8, 0) };
            button.FlatAppearance.BorderColor = Color.FromArgb(218, 221, 231);
            button.Click += delegate { try { action(); } catch (Exception ex) { SetStatus(ex.Message, true); } };
            return button;
        }
        private void SetStatus(string text, bool error) { status.Text = text; status.ForeColor = error ? Color.Firebrick : Color.DimGray; }
        private void UpdateInfo() {
            string text = editor.Text;
            count.Text = text.Length.ToString("N0") + " 字符";
            cardTitle.Text = (String.IsNullOrWhiteSpace(filename.Text) ? "提示词" : filename.Text) + extension.Text;
            long bytes = Encoding.UTF8.GetByteCount(text);
            string size = bytes < 1024 ? bytes + " B" : bytes < 1024 * 1024 ? (bytes / 1024.0).ToString("0.0") + " KB" : (bytes / 1048576.0).ToString("0.00") + " MB";
            cardHint.Text = text.Length == 0 ? "先粘贴文本，再按住这里拖到网页上传区" : size + " · UTF-8 · 按住这里，拖出完整文件 →";
        }
        private void SaveDraft() {
            if (!dirty) return;
            if (draftReadBlocked) throw new IOException("原草稿无法读取，不能覆盖。请检查：" + draftPath);
            Directory.CreateDirectory(Path.GetDirectoryName(draftPath));
            string temp = draftPath + ".tmp-" + Guid.NewGuid().ToString("N");
            bool created = false;
            try {
                byte[] bytes = new UTF8Encoding(false, true).GetBytes(editor.Text);
                using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                    created = true; stream.Write(bytes, 0, bytes.Length); stream.Flush(true);
                }
                if (File.Exists(draftPath)) File.Replace(temp, draftPath, null); else File.Move(temp, draftPath);
                dirty = false;
            } finally { if (created && File.Exists(temp)) File.Delete(temp); }
        }
        private string PrepareCurrent() { refresh.Stop(); UpdateInfo(); string path = store.Prepare(editor.Text, filename.Text, extension.Text); SaveDraft(); return path; }
        private void WireDrag(Control control) {
            control.MouseDown += delegate(object sender, MouseEventArgs e) { if (e.Button == MouseButtons.Left) dragOrigin = Control.MousePosition; };
            control.MouseMove += delegate(object sender, MouseEventArgs e) {
                if (e.Button != MouseButtons.Left || dragging) return;
                Point now = Control.MousePosition;
                if (Math.Abs(now.X - dragOrigin.X) < SystemInformation.DragSize.Width / 2 && Math.Abs(now.Y - dragOrigin.Y) < SystemInformation.DragSize.Height / 2) return;
                dragging = true;
                try {
                    string path = PrepareCurrent();
                    DragDropEffects result = card.DoDragDrop(TextAssetStore.FileData(path), DragDropEffects.Copy);
                    SetStatus(result == DragDropEffects.None ? "文件已保留；未确认目标接收，可重新拖动。" : "拖放已结束；请在网页确认附件是否出现，再发送。", false);
                } catch (Exception ex) { SetStatus("无法拖出文件：" + ex.Message, true); }
                finally { dragging = false; }
            };
            foreach (Control child in control.Controls) WireDrag(child);
        }
    }
    internal static class Program {
        [STAThread] static void Main() {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += delegate(object sender, System.Threading.ThreadExceptionEventArgs e) { MessageBox.Show("操作失败：" + e.Exception.Message, "PromptSlip", MessageBoxButtons.OK, MessageBoxIcon.Error); };
            try { Application.Run(new MainForm(AppDomain.CurrentDomain.BaseDirectory)); }
            catch (Exception ex) { MessageBox.Show("无法启动：" + ex.Message, "PromptSlip", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }
    }
}
