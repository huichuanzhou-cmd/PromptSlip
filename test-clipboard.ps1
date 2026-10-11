$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Run this test in an STA PowerShell process.' }
if (-not [Windows.Forms.Clipboard]::ContainsText([Windows.Forms.TextDataFormat]::UnicodeText)) {
    Write-Output 'SKIP: desktop clipboard has no text. Clipboard was not changed.'
    exit 77
}
$taskExpected = [Windows.Forms.Clipboard]::GetText([Windows.Forms.TextDataFormat]::UnicodeText)
$taskPrivateRoot = Join-Path ([IO.Path]::GetTempPath()) ('PromptSlip-clipboard-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskPrivateRoot | Out-Null
$taskCreated = $null
try {
    $taskOutput = & (Join-Path $PSScriptRoot 'PromptSlip.Cli.exe') --clipboard --output-dir $taskPrivateRoot --name clipboard-check
    if ($LASTEXITCODE -ne 0) { throw 'Actual clipboard CLI failed.' }
    $taskPath = [IO.Path]::GetFullPath([string]$taskOutput)
    if ([IO.Path]::GetDirectoryName($taskPath) -ne $taskPrivateRoot) { throw 'CLI returned a path outside the isolated test directory.' }
    $taskCreated = $taskPath
    if ([Windows.Forms.Clipboard]::GetText([Windows.Forms.TextDataFormat]::UnicodeText) -ne $taskExpected) { throw 'Clipboard changed during test; result inconclusive.' }
    $taskActual = [IO.File]::ReadAllBytes($taskPath)
    $taskExpectedBytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($taskExpected)
    if ([Convert]::ToBase64String($taskActual) -ne [Convert]::ToBase64String($taskExpectedBytes)) { throw 'Actual clipboard bytes differ from expected UTF-8.' }
    Write-Output 'PASS: actual desktop text clipboard to native CLI exact UTF-8; clipboard not changed; private test attachment removed.'
} finally {
    if ($taskCreated -and [IO.File]::Exists($taskCreated)) { [IO.File]::Delete($taskCreated) }
    if ([IO.Directory]::GetFileSystemEntries($taskPrivateRoot).Count -eq 0) { [IO.Directory]::Delete($taskPrivateRoot) }
}
