"""Black-box native CLI acceptance. Python is a developer test dependency only.
Usage: python tests/cli_acceptance.py /absolute/path/to/native-cli
"""
import pathlib
import subprocess
import sys
import tempfile


def main():
    binary = str(pathlib.Path(sys.argv[1]).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="promptslip-cli-") as tmp:
        root = pathlib.Path(tmp).resolve()

        def run(flags, data=b""):
            return subprocess.run([binary, *flags, "--output-dir", str(root)], input=data,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)

        def export(flags, data):
            proc = run(flags, data)
            assert proc.returncode == 0, proc.stderr.decode("utf-8", "replace")
            assert proc.stderr == b"", proc.stderr
            path = pathlib.Path(proc.stdout.decode("utf-8").rstrip("\r\n"))
            # macOS may report /var while Python resolves the same directory as /private/var.
            # Compare the actual target directory, retaining absolute-path/file containment checks.
            assert path.is_absolute() and path.resolve(strict=True).parent == root and path.is_file(), path
            assert path.read_bytes() == data, "file changed or truncated"
            return path

        sample = ("长文本 😀 日本語\r\n\t" * 100000 + "END-完整末尾").encode("utf-8")
        first = export(["--stdin"], sample)
        assert first.suffix == ".md"
        second = export(["--stdin"], b"latest edit")
        assert first != second and first.read_bytes() == sample
        print("PASS subprocess stdin >1 MB Unicode/CRLF exact, MD default, immutable snapshots")
        for name in ("CON.md", "../../outside", 'a<>:"/\\|?*', ".", "😀" * 150):
            path = export(["--stdin", "--name", name, "--txt"], b" \r\n\t")
            assert path.suffix == ".txt"
        print("PASS safe names including Unicode and TXT whitespace")
        before = set(root.iterdir())
        for flags, data in ((["--stdin"], b""), (["--stdin"], b"\xc3("),
                            (["--stdin", "--clipboard"], b"sample"),
                            (["--stdin", "--unknown"], b"sample"),
                            (["--name", "no-input-mode"], b"sample")):
            proc = run(flags, data)
            assert proc.returncode != 0 and not proc.stdout and proc.stderr, (flags, proc)
        assert set(root.iterdir()) == before, "failure created files"
        print("PASS invalid UTF8/empty/conflicting/unknown flags reject without file writes")
        for flags in (["--help"], ["--stdin", "--name"], ["--stdin", "--output-dir"]):
            proc = subprocess.run([binary, *flags], input=b"sample", capture_output=True, timeout=30)
            if flags == ["--help"]:
                assert proc.returncode == 0 and b"--stdin" in proc.stdout
            else:
                assert proc.returncode != 0 and not proc.stdout and proc.stderr
        print("PASS help and missing option values")
        for flags in (["--stdin", "--stdin"], ["--stdin", "--txt", "--txt"],
                      ["--stdin", "--name", "one", "--name", "two"]):
            proc = run(flags, b"sample")
            assert proc.returncode != 0 and not proc.stdout and proc.stderr, "duplicate option accepted: " + str(flags)
        assert set(root.iterdir()) == before, "invalid/duplicate flags created files"
        print("PASS duplicate options rejected consistently")
    return 0


if __name__ == "__main__":
    sys.exit(main())
