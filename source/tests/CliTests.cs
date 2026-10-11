using System;
using System.IO;
using System.Text;
using PromptSlip;

class CliTests {
    static int failures;
    static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
    static readonly string Root = Path.Combine(Path.GetTempPath(), "PromptSlip-cli-tests-" + Guid.NewGuid().ToString("N"));
    static void Check(bool ok, string message) { if (!ok) throw new Exception(message); }
    static void Test(string name, Action action) {
        try { action(); Console.WriteLine("PASS " + name); }
        catch (Exception ex) { failures++; Console.WriteLine("FAIL " + name + ": " + ex.Message); }
    }
    static int Run(string[] args, byte[] bytes, out string output, out string error, Func<string> clipboard) {
        var stdout = new StringWriter(); var stderr = new StringWriter();
        int result = CliRunner.Run(args, new MemoryStream(bytes), stdout, stderr, clipboard);
        output = stdout.ToString(); error = stderr.ToString(); return result;
    }
    static string Export(string[] flags, string text) {
        var args = new System.Collections.Generic.List<string>(flags);
        args.Add("--output-dir"); args.Add(Root);
        string output, error;
        int code = Run(args.ToArray(), Utf8.GetBytes(text), out output, out error, delegate { return text; });
        Check(code == 0 && error == "", "Export failed: " + error);
        string path = output.TrimEnd('\r', '\n');
        Check(Path.IsPathRooted(path) && File.Exists(path), "stdout must be an existing absolute file path");
        Check(Path.GetDirectoryName(path) == Root, "export escaped target directory");
        return path;
    }
    [STAThread] static int Main() {
        Test("stdin >1 MB Unicode and CRLF roundtrip, MD default", delegate {
            string text = new StringBuilder().Insert(0, "长提示词😀\r\n日本語\t", 100000).ToString() + "END-完整末尾";
            string path = Export(new[]{"--stdin"}, text);
            Check(Path.GetExtension(path) == ".md", "Default is not Markdown");
            Check(Convert.ToBase64String(File.ReadAllBytes(path)) == Convert.ToBase64String(Utf8.GetBytes(text)), "bytes changed/truncated");
        });
        Test("separate calls never overwrite snapshots", delegate {
            string a = Export(new[]{"--stdin", "--name", "same"}, "old");
            string b = Export(new[]{"--stdin", "--name", "same"}, "new");
            Check(a != b && File.ReadAllText(a) == "old" && File.ReadAllText(b) == "new", "overwrote an existing file");
        });
        Test("TXT option and Unicode unsafe filename stay inside output folder", delegate {
            string path = Export(new[]{"--stdin", "--txt", "--name", "../../CON😀.md"}, " \r\n\t");
            Check(Path.GetExtension(path) == ".txt" && File.ReadAllText(path) == " \r\n\t", "TXT/whitespace changed");
        });
        Test("explicit clipboard uses provider without reading stdin", delegate {
            string path = Export(new[]{"--clipboard", "--name", "clip"}, "clipboard 中文😀");
            Check(File.ReadAllText(path) == "clipboard 中文😀", "clipboard export changed");
        });
        Test("invalid options, empty input and invalid UTF8 fail before file creation", delegate {
            int before = Directory.GetFiles(Root).Length;
            foreach (var args in new[]{new[]{"--stdin", "--clipboard"}, new[]{"--stdin", "--unknown"}, new[]{"--stdin", "--name"}, new[]{"--stdin", "--output-dir"}, new[]{"--name", "missing-mode"}}) {
                string output, error;
                int code = Run(args, Utf8.GetBytes("sample"), out output, out error, delegate { return "sample"; });
                Check(code != 0 && output == "" && error.Length > 0, "bad flags accepted");
            }
            foreach (byte[] bytes in new[]{new byte[0], new byte[]{0xc3, 0x28}}) {
                string output, error;
                int code = Run(new[]{"--stdin", "--output-dir", Root}, bytes, out output, out error, delegate { return ""; });
                Check(code != 0 && output == "" && error.Length > 0, "bad input accepted");
            }
            Check(Directory.GetFiles(Root).Length == before, "failure created attachment");
        });
        Test("unwritable output reports failure", delegate {
            string blocker = Path.Combine(Root, "file-not-directory"); File.WriteAllText(blocker, "keep");
            string output, error;
            int code = Run(new[]{"--stdin", "--output-dir", blocker}, Utf8.GetBytes("sample"), out output, out error, delegate { return ""; });
            Check(code != 0 && output == "" && error.Length > 0 && File.ReadAllText(blocker) == "keep", "IO failure hidden");
        });
        Test("help and no arguments are side effect free", delegate {
            foreach (var args in new[]{new string[0], new[]{"--help"}}) {
                string output, error;
                Check(Run(args, new byte[0], out output, out error, delegate { throw new Exception("clipboard accessed"); }) == 0, "help failed");
                Check(output.Contains("--stdin") && error == "", "help absent");
            }
        });
        Console.WriteLine("CLI failures: " + failures); return failures == 0 ? 0 : 1;
    }
}
