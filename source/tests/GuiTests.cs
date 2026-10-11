using System;
using System.IO;
using System.Text;
using System.Reflection;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Windows.Forms;
using PromptSlip;
class GuiTests {
    static T Field<T>(object o, string name) { return (T)o.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic).GetValue(o); }
    static object Invoke(object o, string name) { return o.GetType().GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic).Invoke(o, null); }
    static void Check(bool ok, string message) { if (!ok) throw new Exception(message); }
    [STAThread] static int Main() {
        try {
            Application.EnableVisualStyles();
            string root = Path.GetFullPath(Path.Combine("work", "tests", "gui-" + Guid.NewGuid().ToString("N")));
            string sample = new StringBuilder().Insert(0, "长中文 😀\n下一行\t完整文本\n", 70000).ToString() + "【最终结束标记】";
            using (var form = new MainForm(root)) {
                var editor = Field<PlainEditor>(form, "editor");
                var format = Field<ComboBox>(form, "extension");
                Check(format.Text == ".md", "Default attachment format must be Markdown");
                editor.Text = sample;
                Check(editor.Text == sample, "RichTextBox changed/truncated text");
                string first = (string)Invoke(form, "PrepareCurrent");
                Check(Path.GetExtension(first) == ".md", "Default export must have .md extension");
                Check(File.ReadAllText(first, Encoding.UTF8) == sample, "GUI export truncated");
                editor.AppendText("\n最新修改");
                string second = (string)Invoke(form, "PrepareCurrent");
                Check(File.ReadAllText(second).EndsWith("最新修改"), "last edit omitted");
                Check(File.ReadAllText(first) == sample, "previous export overwritten");
                format.SelectedItem = ".txt";
                string txt = (string)Invoke(form, "PrepareCurrent");
                Check(Path.GetExtension(txt) == ".txt" && File.ReadAllText(txt) == editor.Text, "Manual TXT fallback failed");
                Console.WriteLine("PASS default Markdown, manual TXT, GUI >1M Unicode chars, latest edit, immutable snapshot");
                Invoke(form, "SaveDraft");
            }
            using (var restored = new MainForm(root)) {
                var editor = Field<PlainEditor>(restored, "editor");
                Check(editor.Text == sample + "\n最新修改", "draft restoration failed");
                Console.WriteLine("PASS draft restored exactly in a new form");
            }
            string damagedRoot = root + "-damaged";
            string damagedPath = Path.Combine(damagedRoot, "数据", "草稿.txt");
            Directory.CreateDirectory(Path.GetDirectoryName(damagedPath));
            byte[] damaged = new byte[]{0xff, 0xfe, 0x80, 0x00, 0x81};
            File.WriteAllBytes(damagedPath, damaged);
            using (var form = new MainForm(damagedRoot)) {
                var damagedEditor = Field<PlainEditor>(form, "editor");
                IntPtr damagedHandle = damagedEditor.Handle;
                damagedEditor.Text = "new draft 日本語 😀\nEND";
                Check(Field<bool>(form, "dirty"), "Native editor must notify draft changes");
                Invoke(form, "SaveDraft");
                string[] backups = Directory.GetFiles(Path.GetDirectoryName(damagedPath), "草稿.txt.corrupt-*");
                Check(backups.Length == 1 && Convert.ToBase64String(File.ReadAllBytes(backups[0])) == Convert.ToBase64String(damaged), "Damaged draft was not preserved byte-for-byte");
                Check(Field<Label>(form, "status").Text.Contains(Path.GetFullPath(damagedRoot)), "Storage location must be visible");
            }
            using (var restored = new MainForm(damagedRoot))
                Check(Field<PlainEditor>(restored, "editor").Text == "new draft 日本語 😀\nEND", "New draft did not recover after corrupt original");
            Console.WriteLine("PASS corrupt draft preserved; new edits recover after restart; storage location visible");

            string aclRoot = root + "-permissions";
            string aclDir = Path.Combine(aclRoot, "数据");
            Directory.CreateDirectory(aclDir);
            string aclDraft = Path.Combine(aclDir, "草稿.txt");
            File.WriteAllText(aclDraft, "previous draft", new UTF8Encoding(false));
            byte[] originalAcl = Directory.GetAccessControl(aclDir).GetSecurityDescriptorBinaryForm();
            using (var form = new MainForm(aclRoot)) {
                var aclEditor = Field<PlainEditor>(form, "editor");
                IntPtr aclHandle = aclEditor.Handle;
                aclEditor.Text = "unsaved edit";
                var deniedAcl = Directory.GetAccessControl(aclDir);
                deniedAcl.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User,
                    FileSystemRights.Write, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                    PropagationFlags.None, AccessControlType.Deny));
                bool rejected = false;
                try {
                    Directory.SetAccessControl(aclDir, deniedAcl);
                    try { Invoke(form, "SaveDraft"); }
                    catch (TargetInvocationException ex) { rejected = ex.InnerException is UnauthorizedAccessException; }
                    Check(rejected && File.ReadAllText(aclDraft) == "previous draft", "Read-only folder must fail without losing existing draft");
                } finally {
                    var restoredAcl = new DirectorySecurity();
                    restoredAcl.SetSecurityDescriptorBinaryForm(originalAcl, AccessControlSections.Access);
                    Directory.SetAccessControl(aclDir, restoredAcl);
                }
                Invoke(form, "SaveDraft");
                Check(File.ReadAllText(aclDraft) == "unsaved edit", "Failed save must stay dirty and be retryable");
            }
            Console.WriteLine("PASS actual Windows ACL write denial preserves previous draft and allows retry");
            return 0;
        } catch (Exception e) { Console.WriteLine("FAIL " + e); return 1; }
    }
}
