$ErrorActionPreference = 'Stop'
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sourceRoot = Join-Path $PSScriptRoot 'source'
& $compilerPath /nologo /codepage:65001 /target:winexe /optimize+ /platform:anycpu ("/out:" + (Join-Path $PSScriptRoot 'PromptSlip.exe')) ("/win32manifest:" + (Join-Path $sourceRoot 'app.manifest')) /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll (Join-Path $sourceRoot 'AssemblyInfo.cs') (Join-Path $sourceRoot 'TextAssetStore.cs') (Join-Path $sourceRoot 'MainForm.cs')
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
Write-Output 'Built PromptSlip.exe'
& $compilerPath /nologo /codepage:65001 /target:exe /optimize+ /platform:anycpu ("/out:" + (Join-Path $PSScriptRoot 'PromptSlip.Cli.exe')) /r:System.dll /r:System.Core.dll /r:System.Windows.Forms.dll (Join-Path $sourceRoot 'AssemblyInfo.cs') (Join-Path $sourceRoot 'TextAssetStore.cs') (Join-Path $sourceRoot 'CliProgram.cs')
if ($LASTEXITCODE -ne 0) { throw 'CLI build failed.' }
Write-Output 'Built PromptSlip.Cli.exe'
