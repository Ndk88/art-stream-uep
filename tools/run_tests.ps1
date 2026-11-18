<#
.SYNOPSIS
	Builds the C++ development project .uedev\LightSequenceDev (editor target) and runs the automation tests
	"LightSequence." headless (CLAUDE.md sections 0a, 6 and 9).

.DESCRIPTION
	DEV engine only (stock launcher UE 5.6). Refuses the TARGET engine and projects associated with it.
	Writes to: .uedev\LightSequenceDev\ (Binaries, Intermediate, Saved, DerivedDataCache),
	Plugins\LightSequence\Binaries and \Intermediate (git-ignored), .uedev\_logs\run_tests_<stamp>\,
	per-user UE caches (%LOCALAPPDATA%\UnrealEngine, %LOCALAPPDATA%\UnrealBuildTool).
	The DEV engine folder is snapshotted before and after; differences are checked by the I-2 rule
	(tools\ue_safety.ps1, Test-EngineDiff). HKCU\Software\Epic Games is compared before and after.

.EXAMPLE
	powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_tests.ps1
#>
[CmdletBinding()]
param(
	[string]$EngineDir = "C:\Program Files\Epic Games\UE_5.6",
	[string]$Filter = "LightSequence",
	[switch]$SkipBuild,
	[switch]$SkipEngineSnapshot
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ue_safety.ps1"

$Repo = $script:RepoRoot
$EngineDir = Get-NormalizedPath $EngineDir
$ProjectDir = Join-Path $Repo ".uedev\LightSequenceDev"
$UProject = Join-Path $ProjectDir "LightSequenceDev.uproject"

# --- Safety checks (CLAUDE.md section 0a) ---
Assert-SafeEngine $EngineDir
$Assoc = Assert-ProjectAssociation $UProject
if (-not (Test-DevEngineAssociation $Assoc)) { throw "EngineAssociation of $UProject is '$Assoc', which does not resolve to the DEV engine." }
Assert-InsideRepo $ProjectDir "Project"

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir = Join-Path $Repo ".uedev\_logs\run_tests_$Stamp"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Write-Host "Engine  : $EngineDir"
Write-Host "Project : $UProject (EngineAssociation $Assoc)"
Write-Host "Logs    : $LogDir"

if (-not $SkipEngineSnapshot)
{
	Write-Host "Snapshot of engine files (before)..."
	$N = New-TreeSnapshot $EngineDir (Join-Path $LogDir "engine_before.csv")
	Write-Host "  $N files"
}
$RegBefore = [string[]](Get-EpicRegistryDump)

$Failed = $null
try
{
	if (-not $SkipBuild)
	{
		$DotNet = Get-ChildItem (Join-Path $EngineDir "Engine\Binaries\ThirdParty\DotNet\*\win-x64\dotnet.exe") | Select-Object -First 1 -ExpandProperty FullName
		$UbtDll = Join-Path $EngineDir "Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll"
		$UbtArgs = "`"$UbtDll`" LightSequenceDevEditor Win64 Development -Project=`"$UProject`" -WaitMutex -log=`"$(Join-Path $LogDir 'UBT-LightSequenceDevEditor.txt')`""
		$Abort = Get-DefaultAbortPatterns @("LightSequence", "LightSequenceDev")
		$Code = Invoke-WatchedProcess $DotNet $UbtArgs (Join-Path $LogDir "console-build.log") $Abort
		Write-Host "UBT exit code: $Code"
		if ($Code -ne 0) { throw "Build failed, exit code $Code." }
	}

	$EditorCmd = Join-Path $EngineDir "Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
	$EditorLog = Join-Path $LogDir "editor.log"
	$Report = Join-Path $LogDir "report"
	$EdArgs = "`"$UProject`" -ExecCmds=`"Automation RunTests $Filter; Quit`" -unattended -nullrhi -nop4 -nosplash -nosound -log -abslog=`"$EditorLog`" -ReportExportPath=`"$Report`""
	$Abort = @([regex]::Escape($script:TargetEngineDir), "Scene_A1")
	$Code = Invoke-WatchedProcess $EditorCmd $EdArgs (Join-Path $LogDir "console-editor.log") $Abort
	Write-Host "Editor exit code: $Code"

	$Results = Select-String -LiteralPath $EditorLog -Pattern "Test Completed\. Result=\{(\w+)\}\s+Name=\{([^}]*)\}\s+Path=\{([^}]*)\}" | ForEach-Object { [pscustomobject]@{ Result = $_.Matches[0].Groups[1].Value; Path = $_.Matches[0].Groups[3].Value } }
	$Results | ForEach-Object { Write-Host ("  {0,-8} {1}" -f $_.Result, $_.Path) }
	$Total = @($Results).Count
	$Passed = @($Results | Where-Object { $_.Result -eq "Success" }).Count
	Write-Host "Tests: $Passed of $Total passed (filter '$Filter')."
	Select-String -LiteralPath $EditorLog -Pattern "TEST COMPLETE\. EXIT CODE" | ForEach-Object { Write-Host $_.Line.Trim() }
	if ($Total -eq 0) { $Failed = "no tests were run" }
	elseif ($Passed -ne $Total) { $Failed = "$($Total - $Passed) test(s) failed" }
}
finally
{
	$EngineChanged = $false
	if (-not $SkipEngineSnapshot)
	{
		Write-Host "Snapshot of engine files (after)..."
		[void](New-TreeSnapshot $EngineDir (Join-Path $LogDir "engine_after.csv"))
		$Diff = Compare-TreeSnapshot (Join-Path $LogDir "engine_before.csv") (Join-Path $LogDir "engine_after.csv")
		$Diff | Set-Content -Encoding UTF8 (Join-Path $LogDir "engine_diff.txt")
		$Check = Test-EngineDiff $EngineDir $Diff
		Write-Host "Engine diff: $($Diff.Count) entries, $($Check.Allowed) allowed by the I-2 rule, $($Check.Violations.Count) violations."
		if ($Check.Violations.Count -gt 0)
		{
			$EngineChanged = $true
			$Check.Violations | Set-Content -Encoding UTF8 (Join-Path $LogDir "engine_violations.txt")
			Write-Host "ENGINE FOLDER CHANGED OUTSIDE THE I-2 RULE (see engine_violations.txt). STOP and report." -ForegroundColor Red
			$Check.Violations | Select-Object -First 20 | Write-Host
		}
		else { Write-Host "Engine check passed." }
	}
	$RegAfter = [string[]](Get-EpicRegistryDump)
	$RegDiff = @(Compare-Object $RegBefore $RegAfter)
	if ($RegDiff.Count -gt 0)
	{
		Write-Host "REGISTRY HKCU\Software\Epic Games CHANGED:" -ForegroundColor Red
		$RegDiff | ForEach-Object { Write-Host "  $($_.SideIndicator) $($_.InputObject)" }
		$EngineChanged = $true
	}
	else { Write-Host "Registry HKCU\Software\Epic Games unchanged." }
}
if ($EngineChanged) { exit 3 }
if ($Failed) { Write-Host "FAILED: $Failed" -ForegroundColor Red; exit 1 }
exit 0
