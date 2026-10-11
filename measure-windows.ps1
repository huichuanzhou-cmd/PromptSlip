$ErrorActionPreference = 'Stop'
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$probeDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('PromptSlip-probe-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probeDirectory | Out-Null
$probe = Join-Path $probeDirectory 'FootprintProbe.exe'
& $compilerPath /nologo /codepage:65001 /target:exe /main:FootprintProbe /optimize+ ("/out:" + $probe) /r:System.Windows.Forms.dll /r:System.Drawing.dll (Join-Path $PSScriptRoot 'source\TextAssetStore.cs') (Join-Path $PSScriptRoot 'source\MainForm.cs') (Join-Path $PSScriptRoot 'source\tests\FootprintProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'Probe build failed.' }
$runs = @(1..3 | ForEach-Object { & $probe | ConvertFrom-Json })
if ($LASTEXITCODE -ne 0) { throw 'Probe failed.' }
$files = @('PromptSlip.exe','PromptSlip.Cli.exe') | ForEach-Object {
    $item = Get-Item -LiteralPath (Join-Path $PSScriptRoot $_)
    [ordered]@{ name = $item.Name; bytes = $item.Length; sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
[ordered]@{ platform = 'Windows'; dependency = 'System .NET Framework 4.x; not included in executable bytes'; files = $files; runs = $runs } | ConvertTo-Json -Depth 5
