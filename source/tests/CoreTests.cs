using System;
using System.IO;
using System.Text;
using System.Windows.Forms;
using PromptSlip;

class CoreTests {
    static int failures;
    [System.Runtime.CompilerServices.MethodImpl(System.Runtime.CompilerServices.MethodImplOptions.NoInlining)]
    static WeakReference ExportTransientText(TextAssetStore store) {
        string text = new string('中', 700000);
        var reference = new WeakReference(text);
        store.Prepare(text, "memory", ".md");
        return reference;
    }
    static void Check(bool ok, string message) { if (!ok) throw new Exception(message); }
    static void Run(string name, Action action) {
        try { action(); Console.WriteLine("PASS " + name); }
        catch (Exception ex) { failures++; Console.WriteLine("FAIL " + name + ": " + ex.Message); }
    }
    [STAThread] static int Main() {
        string root = Path.Combine(Path.GetTempPath(), "PromptSlip-tests-" + Guid.NewGuid().ToString("N"));
        var store = new TextAssetStore(root);
        string sample = new StringBuilder().Insert(0, "完整中文提示词 / 日本語 / emoji 😀 / tab\t\r\n", 60000).ToString() + "[最后一行完整结束]";
        string first = null;
        Run("long Unicode UTF-8 roundtrip (>2M chars)", delegate {
            first = store.Prepare(sample, "长提示词", ".txt");
            Check(File.ReadAllText(first, Encoding.UTF8) == sample, "Text was changed or truncated");
            byte[] bytes = File.ReadAllBytes(first);
            Check(bytes.Length == new UTF8Encoding(false, true).GetByteCount(sample), "UTF8 byte count/BOM mismatch");
            Check(Path.GetFullPath(first).StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar), "outside storage root");
        });
        Run("immutable snapshots and no overwrites", delegate {
            string a = store.Prepare("old", "same", ".txt");
            string b = store.Prepare("new", "same", ".txt");
            Check(a != b && File.ReadAllText(a) == "old" && File.ReadAllText(b) == "new", "Snapshot overwritten");
        });
        Run("externally edited export cannot become the next attachment", delegate {
            string original = store.Prepare("current editor content", "external", ".txt");
            File.WriteAllText(original, "externally changed", Encoding.UTF8);
            string fresh = store.Prepare("current editor content", "external", ".txt");
            Check(File.ReadAllText(fresh, Encoding.UTF8) == "current editor content", "stale modified attachment reused");
            Check(fresh != original && File.ReadAllText(original) == "externally changed", "external edit overwritten");
        });
        Run("reserved names, path traversal and custom extension", delegate {
            foreach (string name in new string[]{"CON", "LPT1", "nul.txt", "../../outside", "a<>:\"/\\|?*", ".", new string('长', 200)}) {
                string p = store.Prepare("safe", name, ".md");
                Check(File.Exists(p) && Path.GetDirectoryName(p) == Path.GetFullPath(root), "invalid/escaped name");
                Check(Path.GetExtension(p) == ".md", "extension");
            }
        });
        Run("empty text rejected but whitespace retained", delegate {
            bool rejected = false;
            try { store.Prepare("", "empty", ".txt"); } catch (ArgumentException) { rejected = true; }
            Check(rejected, "empty file allowed");
            Check(File.ReadAllText(store.Prepare(" \t\n", "spaces", ".txt")) == " \t\n", "trimmed user data");
        });
        Run("standard FileDrop contains existing absolute file", delegate {
            string p = store.Prepare("attachment", "drag", ".txt");
            DataObject data = TextAssetStore.FileData(p);
            Check(data.GetDataPresent(DataFormats.FileDrop), "FileDrop missing");
            string[] paths = (string[])data.GetData(DataFormats.FileDrop);
            Check(paths.Length == 1 && paths[0] == Path.GetFullPath(p) && File.Exists(paths[0]), "FileDrop path");
        });
        Run("missing FileDrop file rejected", delegate {
            bool rejected = false;
            try { TextAssetStore.FileData(Path.Combine(root, "missing.txt")); } catch (FileNotFoundException) { rejected = true; }
            Check(rejected, "nonexistent attachment allowed");
        });
        Run("export cache does not retain the previous large input string", delegate {
            var memoryStore = new TextAssetStore(Path.Combine(root, "memory"));
            WeakReference reference = ExportTransientText(memoryStore);
            GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
            Check(!reference.IsAlive, "Completed export retains the full input string");
            GC.KeepAlive(memoryStore);
        });
        Console.WriteLine("Failures: " + failures);
        return failures == 0 ? 0 : 1;
    }
}
