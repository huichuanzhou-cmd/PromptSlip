$ErrorActionPreference = 'Stop'
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PromptSlip-suite-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
& $compilerPath /nologo /codepage:65001 /target:exe ("/out:" + (Join-Path $testRoot 'CoreTests.exe')) /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'source\TextAssetStore.cs') (Join-Path $PSScriptRoot 'source\tests\CoreTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'Core tests build failed.' }
& (Join-Path $testRoot 'CoreTests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PromptSlip.exe') -Destination (Join-Path $testRoot 'PromptSlip.exe')
& $compilerPath /nologo /codepage:65001 /target:exe ("/out:" + (Join-Path $testRoot 'GuiTests.exe')) /r:System.Windows.Forms.dll /r:System.Drawing.dll ("/r:" + (Join-Path $PSScriptRoot 'PromptSlip.exe')) (Join-Path $PSScriptRoot 'source\tests\GuiTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'GUI tests build failed.' }
Push-Location $testRoot
try {
    & (Join-Path $testRoot 'GuiTests.exe')
    if ($LASTEXITCODE -ne 0) { throw 'GUI tests failed.' }
} finally { Pop-Location }
& $compilerPath /nologo /codepage:65001 /target:exe /main:CliTests ("/out:" + (Join-Path $testRoot 'CliTests.exe')) /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'source\TextAssetStore.cs') (Join-Path $PSScriptRoot 'source\CliProgram.cs') (Join-Path $PSScriptRoot 'source\tests\CliTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'CLI tests build failed.' }
& (Join-Path $testRoot 'CliTests.exe')
if ($LASTEXITCODE -ne 0) { throw 'CLI tests failed.' }
Write-Output 'All 8 core, 4 GUI integration and 7 CLI checks passed.'
