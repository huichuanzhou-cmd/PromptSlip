using System;
using System.IO;
using System.Text;
using System.Windows.Forms;
using System.Collections.Specialized;
using System.Text.RegularExpressions;

namespace PromptSlip {
    public sealed class TextAssetStore {
        private readonly string root;
        private string previousName, previousPath;
        public TextAssetStore(string root) { this.root = Path.GetFullPath(root); }
        public string Prepare(string text, string name, string extension) {
            if (String.IsNullOrEmpty(text)) throw new ArgumentException("请先粘贴或输入文本。");
            if (extension != ".txt" && extension != ".md") throw new ArgumentException("只支持 TXT 或 Markdown。");
            string safe = SafeName(name);
            string key = safe + extension;
            byte[] bytes = new UTF8Encoding(false, true).GetBytes(text);
            if (key == previousName && File.Exists(previousPath) && SameBytes(previousPath, bytes)) return previousPath;
            Directory.CreateDirectory(root);
            string path = Path.Combine(root, safe + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + "_" + Guid.NewGuid().ToString("N").Substring(0, 8) + extension);
            using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.Read)) {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
            }
            previousName = key; previousPath = path;
            return path;
        }
        private static bool SameBytes(string path, byte[] expected) {
            using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                if (file.Length != expected.Length) return false;
                byte[] chunk = new byte[8192];
                int offset = 0, read;
                while ((read = file.Read(chunk, 0, chunk.Length)) > 0) {
                    for (int i = 0; i < read; i++) if (chunk[i] != expected[offset + i]) return false;
                    offset += read;
                }
                return offset == expected.Length;
            }
        }
        private static string SafeName(string name) {
            string safe = String.IsNullOrWhiteSpace(name) ? "提示词" : name.Trim();
            if (safe.EndsWith(".txt", StringComparison.OrdinalIgnoreCase) || safe.EndsWith(".md", StringComparison.OrdinalIgnoreCase)) safe = Path.GetFileNameWithoutExtension(safe);
            foreach (char c in Path.GetInvalidFileNameChars()) safe = safe.Replace(c, '_');
            safe = safe.Trim(' ', '.');
            if (safe.Length > 64) safe = safe.Substring(0, 64);
            if (safe.Length > 0 && Char.IsHighSurrogate(safe[safe.Length - 1])) safe = safe.Substring(0, safe.Length - 1);
            if (safe.Length == 0) safe = "提示词";
            if (Regex.IsMatch(safe.Split('.')[0], @"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$", RegexOptions.IgnoreCase)) safe = "_" + safe;
            return safe;
        }
        public static DataObject FileData(string path) {
            string full = Path.GetFullPath(path);
            if (!File.Exists(full)) throw new FileNotFoundException("附件文件不存在，请重新拖动。", full);
            var paths = new StringCollection(); paths.Add(full);
            var data = new DataObject(); data.SetFileDropList(paths);
            return data;
        }
    }
}
