using System;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace PromptSlip {
    internal static class CliRunner {
        private const string Help = "PromptSlip CLI\nUsage: PromptSlip.Cli.exe (--stdin | --clipboard) [--output-dir DIR] [--name NAME] [--txt]\nReads UTF-8 text and prints the absolute path of a new Markdown file.\n--stdin       Read stdin without changing line endings\n--clipboard   Read the desktop text clipboard once\n--output-dir  Destination folder (default: Documents/PromptSlip/files)\n--name        File stem (default: prompt)\n--txt         Export .txt instead of .md\n--help        Show this help\n";
        internal static int Run(string[] args, Stream input, TextWriter output, TextWriter error, Func<string> clipboard) {
            try {
                if (args.Length == 0 || (args.Length == 1 && args[0] == "--help")) { output.Write(Help); return 0; }
                string mode = null, directory = null, name = "prompt", extension = ".md";
                var seen = new System.Collections.Generic.HashSet<string>(StringComparer.Ordinal);
                for (int i = 0; i < args.Length; i++) {
                    string arg = args[i];
                    if (!seen.Add(arg)) throw new ArgumentException("Duplicate option: " + arg + ".");
                    if (arg == "--stdin" || arg == "--clipboard") {
                        if (mode != null) throw new ArgumentException("Choose exactly one input: --stdin or --clipboard.");
                        mode = arg;
                    } else if (arg == "--txt") extension = ".txt";
                    else if (arg == "--output-dir" || arg == "--name") {
                        if (++i >= args.Length || args[i].StartsWith("--") || args[i].Length == 0) throw new ArgumentException("Missing value for " + arg + ".");
                        if (arg == "--name") name = args[i]; else directory = args[i];
                    } else throw new ArgumentException("Unknown option: " + arg + ". Use --help.");
                }
                if (mode == null) throw new ArgumentException("Choose --stdin or --clipboard. Use --help.");
                string text;
                if (mode == "--stdin") {
                    using (var bytes = new MemoryStream()) {
                        input.CopyTo(bytes);
                        text = new UTF8Encoding(false, true).GetString(bytes.GetBuffer(), 0, checked((int)bytes.Length));
                    }
                } else text = clipboard();
                if (String.IsNullOrEmpty(text)) throw new ArgumentException("No text to export.");
                if (directory == null) {
                    string documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
                    if (documents.Length == 0) throw new IOException("Documents folder unavailable; specify --output-dir.");
                    directory = Path.Combine(documents, "PromptSlip", "files");
                }
                string path = new TextAssetStore(directory).Prepare(text, name, extension);
                output.WriteLine(path);
                return 0;
            } catch (Exception ex) { error.WriteLine("PromptSlip: " + ex.Message); return 1; }
        }
    }
    internal static class CliProgram {
        [STAThread] static int Main(string[] args) {
            Console.OutputEncoding = new UTF8Encoding(false);
            return CliRunner.Run(args, Console.OpenStandardInput(), Console.Out, Console.Error, delegate {
                if (!Clipboard.ContainsText(TextDataFormat.UnicodeText)) throw new InvalidOperationException("Clipboard has no text.");
                return Clipboard.GetText(TextDataFormat.UnicodeText);
            });
        }
    }
}
