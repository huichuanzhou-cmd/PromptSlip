"""Developer-only clean preview packaging; Python is not a product dependency."""
import argparse
import hashlib
import json
import stat
import zipfile
import re
import posixpath
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VERSION = "0.2.0-preview"
SOURCE = [
    ".gitattributes", ".gitignore", ".github/workflows/native.yml", "LICENSE",
    "README.md", "build.ps1", "test.ps1", "measure-windows.ps1", "package.py",
    "verification.json", "source/MainForm.cs", "source/TextAssetStore.cs",
    "source/CliProgram.cs", "source/app.manifest", "source/tests/CoreTests.cs",
    "source/tests/GuiTests.cs", "source/tests/CliTests.cs", "source/tests/FootprintProbe.cs",
    "tests/cli_acceptance.py", "linux/promptslip.c", "linux/build.sh",
    "linux/test-cli.sh", "linux/smoke-gui.sh", "linux/smoke-receiver.c",
    "linux/install-user.sh", "linux/README.md", "macos/PromptSlip.m",
    "macos/build.sh", "macos/acceptance.sh", "macos/README.md",
    "source/AssemblyInfo.cs", "test-clipboard.ps1", "README.zh-CN.md",
    "CHANGELOG.md", "RELEASE_NOTES.md", "docs/DOWNLOADS.md", "docs/PUBLISHING.md",
    "docs/NAMING.md", "docs/VALIDATION.md", "docs/windows/README.md", "docs/windows/README.zh-CN.md",
    "macos/DraftStorage.h", "macos/draft-tests.m", "macos/test-draft.sh",
]
WINDOWS = [(n, n) for n in ("PromptSlip.exe", "PromptSlip.Cli.exe", "LICENSE", "verification.json")]
WINDOWS += [("docs/windows/README.md", "README.md"), ("docs/windows/README.zh-CN.md", "README.zh-CN.md")]


def contents(name, archive_name):
    data = (ROOT / name).read_bytes()
    if name.endswith('.sh'):
        data = data.replace(b'\r\n', b'\n')
    if name.startswith('docs/windows/') and archive_name.startswith('README'):
        data = data.replace(b'../../LICENSE', b'LICENSE').replace(b'../../verification.json', b'verification.json')
    return data


def check_links(files):
    for name, data in files.items():
        if not name.endswith('.md'):
            continue
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', data.decode('utf-8')):
            target = target.strip('<>').split('#', 1)[0]
            if not target or re.match(r'^[a-z]+:', target):
                continue
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
            if resolved not in files:
                raise ValueError('Broken archive link: ' + name + ' -> ' + target)


def check_privacy():
    patterns = [r'gh[pousr]_[A-Za-z0-9]{20,}', r'github_pat_[A-Za-z0-9_]{20,}',
                r'sk-[A-Za-z0-9_-]{20,}', r'AKIA[A-Z0-9]{16}',
                r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
                r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
                r'(?:[A-Za-z]:[/\\]Users[/\\]|/Users/|/home/)[A-Za-z0-9_\u4e00-\u9fff.-]+[/\\]']
    for name in SOURCE:
        text = (ROOT / name).read_text(encoding='utf-8-sig')
        if any(re.search(p, text) for p in patterns):
            raise ValueError('Review potential secret/email/private path before packaging: ' + name)


def make_zip(destination, names, prefix=""):
    # Only explicit source/product paths can enter a package. Never traverse runtime data.
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for entry in names:
            name, archive_name = (entry, entry) if isinstance(entry, str) else entry
            path = ROOT / name
            data = contents(name, archive_name)
            info = zipfile.ZipInfo(prefix + archive_name)
            info.create_system = 3
            mode = 0o755 if path.suffix == ".sh" else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(destination) as archive:
        expected_names = [prefix + (n if isinstance(n, str) else n[1]) for n in names]
        if archive.testzip() is not None or archive.namelist() != expected_names:
            raise ValueError('Archive corruption or allowlist mismatch')
        files = {}
        for entry in names:
            name, archive_name = (entry, entry) if isinstance(entry, str) else entry
            actual = archive.read(prefix + archive_name)
            expected = contents(name, archive_name)
            if name.endswith(".sh"):
                if not (archive.getinfo(prefix + archive_name).external_attr >> 16) & 0o111 or b'\r\n' in actual:
                    raise ValueError('Shell script permissions/line endings incorrect: ' + name)
            if actual != expected:
                raise ValueError('Archive byte mismatch: ' + name)
            files[prefix + archive_name] = actual
        check_links(files)
    return {"file": destination.name, "bytes": destination.stat().st_size,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(), "entries": len(names)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    for name in set(SOURCE + [n[0] for n in WINDOWS]):
        if not (ROOT / name).is_file():
            raise SystemExit("Missing required package input: " + name)
    check_privacy()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = [make_zip(args.output_dir / f"PromptSlip-v{VERSION}-Windows.zip", WINDOWS),
              make_zip(args.output_dir / f"PromptSlip-v{VERSION}-source.zip", SOURCE, "PromptSlip/")]
    index = args.output_dir / "PromptSlip-native-package-check.json"
    index.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / 'SHA256SUMS.txt').write_text(''.join(x['sha256']+'  '+x['file']+'\n' for x in result), encoding='ascii')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
