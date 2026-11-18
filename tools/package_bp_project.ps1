<#
.SYNOPSIS
	Packages the Blueprint-only check project .uedev\LightSequenceBP with RunUAT BuildCookRun and starts the
	packaged exe once (task P0 step 3, decision U8). DEV engine only.

.DESCRIPTION
	Writes to: .uedev\LightSequenceBP\ (Binaries, Intermediate, Saved, DerivedDataCache), the archive folder
	.uedev\_out\LightSequenceBP_<Config>\, .uedev\_logs\package_bp_<stamp>\ (UAT logs via uebp_LogFolder /
	uebp_EngineSavedFolder, packaged-exe log), %TEMP%\UAT (UAT rules assembly of installed engines) and per-user UE
	caches (%LOCALAPPDATA%\UnrealEngine, %LOCALAPPDATA%\UnrealBuildTool).
	The DEV engine folder is snapshotted before and after (I-2 rule); HKCU\Software\Epic Games is compared.

	The packaged exe is started with -ExecCmds="LightSequence.PrintVersion,quit" (Development only: ExecCmds and
	console commands are compiled out of Shipping) and its log is checked for the plugin's log lines.

.EXAMPLE
	powershell -NoProfile -ExecutionPolicy Bypass -File tools\package_bp_project.ps1 -Configuration Development
#>
[CmdletBinding()]
param(
	[ValidateSet("Development", "Shipping")]
	[string]$Configuration = "Development",
	[string]$EngineDir = "C:\Program Files\Epic Games\UE_5.6",
	[switch]$SkipEngineSnapshot,
	[switch]$SkipRun
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ue_safety.ps1"

$Repo = $script:RepoRoot
$EngineDir = Get-NormalizedPath $EngineDir
$ProjectDir = Join-Path $Repo ".uedev\LightSequenceBP"
$UProject = Join-Path $ProjectDir "LightSequenceBP.uproject"
$ArchiveDir = Join-Path $Repo ".uedev\_out\LightSequenceBP_$Configuration"

# --- Safety checks (CLAUDE.md section 0a, U9) ---
Assert-SafeEngine $EngineDir
$Assoc = Assert-ProjectAssociation $UProject
if ($Assoc -ne "5.6") { throw "EngineAssociation of $UProject is '$Assoc', expected '5.6' (DEV engine)." }
if (Test-Path (Join-Path $ProjectDir "Source")) { throw "$ProjectDir has a Source folder; it must stay Blueprint-only." }
foreach ($P in @($ProjectDir, $ArchiveDir)) { Assert-InsideRepo $P "Folder"; Assert-NotProtected $P "Folder" }

$RunUAT = Join-Path $EngineDir "Engine\Build\BatchFiles\RunUAT.bat"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir = Join-Path $Repo ".uedev\_logs\package_bp_${Configuration}_$Stamp"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$env:uebp_LogFolder = Join-Path $LogDir "uat"
$env:uebp_EngineSavedFolder = Join-Path $LogDir "uat_saved"

Write-Host "Engine  : $EngineDir"
Write-Host "Project : $UProject (EngineAssociation $Assoc)"
Write-Host "Archive : $ArchiveDir"
Write-Host "Logs    : $LogDir"

if (-not $SkipEngineSnapshot)
{
	Write-Host "Snapshot of engine files (before)..."
	$N = New-TreeSnapshot $EngineDir (Join-Path $LogDir "engine_before.csv")
	Write-Host "  $N files"
}
$RegBefore = [string[]](Get-EpicRegistryDump)

$Failed = $null
$EngineChanged = $false
try
{
	if (Test-Path $ArchiveDir) { Remove-Item -Recurse -Force -LiteralPath $ArchiveDir }
	$UatArgs = "BuildCookRun -project=`"$UProject`" -noP4 -platform=Win64 -clientconfig=$Configuration -build -cook -stage -pak -archive -archivedirectory=`"$ArchiveDir`" -unattended -utf8output"
	$Abort = Get-DefaultAbortPatterns @("LightSequence", "LightSequenceBP")
	$Code = Invoke-WatchedProcess "cmd.exe" "/c `"`"$RunUAT`" $UatArgs`"" (Join-Path $LogDir "runuat.log") $Abort
	Write-Host "RunUAT exit code: $Code"
	if ($Code -ne 0) { throw "BuildCookRun failed, exit code $Code." }

	# Evidence for U8: did packaging compile C++?
	Write-Host "--- C++ compile evidence (UAT/UBT output) ---"
	Select-String -LiteralPath (Join-Path $LogDir "runuat.log") -Pattern "Temp target|temporary target|Intermediate\\Source|\] (Compile|Link) |Building \d+ action|Target is up to date|Result: " |
		Select-Object -First 40 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }

	if (-not $SkipRun)
	{
		$Exe = Get-ChildItem -LiteralPath $ArchiveDir -Recurse -Filter "LightSequenceBP*.exe" | Where-Object { $_.DirectoryName -notmatch '\\Binaries\\' } | Select-Object -First 1
		if (-not $Exe) { throw "Packaged exe not found under $ArchiveDir." }
		$GameLog = Join-Path $LogDir "packaged_game.log"
		$GameArgs = "-ExecCmds=`"LightSequence.PrintVersion,quit`" -unattended -nullrhi -nosound -log -abslog=`"$GameLog`""
		Write-Host "Starting packaged exe: $($Exe.FullName) $GameArgs"
		$Proc = Start-Process -FilePath $Exe.FullName -ArgumentList $GameArgs -PassThru -WindowStyle Hidden
		$null = $Proc.Handle
		if ($Configuration -eq "Shipping")
		{
			# Shipping ignores -ExecCmds (no "quit"): it must still be running after 20 s, then it is closed.
			if ($Proc.WaitForExit(20000)) { $Failed = "Shipping exe exited after less than 20 s, exit code $($Proc.ExitCode)" }
			else
			{
				Write-Host "Shipping exe is running after 20 s (PID $($Proc.Id)); closing it."
				& taskkill.exe /T /F /PID $Proc.Id | Out-Host
				$CrashDir = Join-Path $Exe.DirectoryName "LightSequenceBP\Saved\Crashes"
				if (Test-Path $CrashDir) { $Failed = "crash reports found in $CrashDir" }
			}
		}
		elseif (-not $Proc.WaitForExit(180000)) { & taskkill.exe /T /F /PID $Proc.Id | Out-Host; $Failed = "packaged exe did not exit within 180 s (killed)" }
		if ($Proc.HasExited) { Write-Host "Packaged exe exit code: $($Proc.ExitCode)" }
		if (Test-Path $GameLog)
		{
			$Lines = Select-String -LiteralPath $GameLog -Pattern "LogLightSequence|LogPluginManager.*LightSequence|Engine Version|Build Configuration"
			$Lines | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
			if ($Configuration -eq "Development" -and -not ($Lines | Where-Object { $_.Line -match "GetPluginVersion called: 0\.1\.0" })) { $Failed = "plugin function call not found in the packaged exe log" }
		}
		elseif ($Configuration -eq "Development") { $Failed = "no log written by the packaged exe" }
		else { Write-Host "  (Shipping writes no log file by default; only the exit code is checked)" }
	}
}
finally
{
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
	$RegDiff = @(Compare-Object $RegBefore ([string[]](Get-EpicRegistryDump)))
	if ($RegDiff.Count -gt 0)
	{
		$EngineChanged = $true
		Write-Host "REGISTRY HKCU\Software\Epic Games CHANGED:" -ForegroundColor Red
		$RegDiff | ForEach-Object { Write-Host "  $($_.SideIndicator) $($_.InputObject)" }
	}
	else { Write-Host "Registry HKCU\Software\Epic Games unchanged." }
}
if ($EngineChanged) { exit 3 }
if ($Failed) { Write-Host "FAILED: $Failed" -ForegroundColor Red; exit 1 }
exit 0
