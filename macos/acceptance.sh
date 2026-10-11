#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BIN=${1:-"$ROOT/build/promptslip"}
if [ ! -x "$BIN" ]; then
  echo "Usage: $0 /path/to/promptslip (build first with build.sh)" >&2
  exit 2
fi
python3 - "$BIN" <<'PY'
import pathlib
import subprocess
import sys
import tempfile

binary = sys.argv[1]
payload = ("标题 🙂\r\nline two\r\n" + "大" * 600000 + "\r\nend").encode("utf-8")
with tempfile.TemporaryDirectory(prefix="promptslip-acceptance-") as tmp:
    out = pathlib.Path(tmp)
    first = subprocess.run([binary, "--stdin", "--name", "提示词.md", "--output-dir", tmp], input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert first.returncode == 0, first.stderr.decode("utf-8", "replace")
    path1 = pathlib.Path(first.stdout.decode("utf-8").strip())
    assert path1.is_absolute() and path1.parent == out and path1.suffix == ".md"
    assert path1.read_bytes() == payload, "UTF-8/CRLF or >1 MiB payload changed"

    second = subprocess.run([binary, "--stdin", "--name", "提示词", "--output-dir", tmp], input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert second.returncode == 0, second.stderr.decode("utf-8", "replace")
    path2 = pathlib.Path(second.stdout.decode("utf-8").strip())
    assert path2 != path1 and path1.exists() and path2.exists(), "snapshot overwrote an earlier file"

    txt = subprocess.run([binary, "--stdin", "--txt", "--name", "plain", "--output-dir", tmp], input=b"ok\r\n", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert txt.returncode == 0 and pathlib.Path(txt.stdout.decode().strip()).suffix == ".txt"

    reserved = subprocess.run([binary, "--stdin", "--name", "CON.any", "--output-dir", tmp], input=b"reserved", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert reserved.returncode == 0 and pathlib.Path(reserved.stdout.decode().strip()).name.startswith("_CON.any_")
    bad_chars = subprocess.run([binary, "--stdin", "--name", "bad/name:one", "--output-dir", tmp], input=b"safe", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert bad_chars.returncode == 0 and pathlib.Path(bad_chars.stdout.decode().strip()).name.startswith("bad_name_one_")
    long_name = "🙂" * 80
    bounded = subprocess.run([binary, "--stdin", "--name", long_name, "--output-dir", tmp], input=b"bounded", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    bounded_path = pathlib.Path(bounded.stdout.decode().strip())
    assert bounded.returncode == 0 and len(bounded_path.name.encode("utf-8")) <= 255

    before = set(out.iterdir())
    for args, data in [(["--stdin"], b""), (["--stdin"], b"\xff"), (["--stdin", "--unknown"], b"x"), (["--stdin", "--clipboard"], b"x"), (["--stdin", "--name", ""], b"x"), (["--stdin", "--name", "--txt"], b"x"), (["--stdin", "--output-dir"], b"x"), (["--stdin", "--stdin"], b"x"), (["--stdin", "--txt", "--txt"], b"x"), (["--stdin", "--name", "one", "--name", "two"], b"x"), (["--stdin", "--output-dir", tmp, "--output-dir", tmp], b"x"), (["--help", "--stdin"], b"x")]:
        failed = subprocess.run([binary, *args, "--output-dir", tmp], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert failed.returncode != 0 and not failed.stdout, (args, failed.returncode, failed.stdout)
        assert set(out.iterdir()) == before, "invalid input created an attachment"
    help_result = subprocess.run([binary, "--help"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert help_result.returncode == 0 and b"--stdin" in help_result.stdout
print("PASS: CLI UTF-8/CRLF/>1 MiB exactness, unique snapshots, .txt option, empty/invalid/unknown/conflicting input, and --help")
PY
