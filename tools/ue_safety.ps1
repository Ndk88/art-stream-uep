# Shared safety helpers for the UE build scripts of art-stream-uep (CLAUDE.md section 0a).
# Dot-source this file: . "$PSScriptRoot\ue_safety.ps1"
# Windows PowerShell 5.1 compatible.

Set-StrictMode -Version Latest

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# DEV engine (stock launcher UE 5.6, decision U10).
$script:DevEngineDir = "C:\Program Files\Epic Games\UE_5.6"

# TARGET engine (NvRTX source build): read-only, used only in P7 with the user's approval.
$script:TargetEngineDir = "D:\NVRTXCAUSTICS\5_6"
$script:TargetEngineGuid = "{394CF319-4D3A-7BC1-DA7B-CC849351994F}"

# Protected locations (CLAUDE.md section 0a). Nothing may be written there.
$script:ProtectedDirs = @(
	"D:\NVRTXCAUSTICS\5_6",
	"C:\UE_Backups",
	"D:\PRECIOSA\PixelStreaming_Project_1\_ue_\Scene_A1",
	"C:\Program Files\Epic Games"
)

# Engine plugins of the launcher UE 5.6 that ship without pre-generated build data (incident I-2). Every project
# built by Claude Code disables them (user's requirement). Measured on 2026-11-18: disabling them does NOT stop
# UnrealBuildTool from writing into their Intermediate folders for an UnrealEditor target (the modules come from
# the installed editor's receipt); that part is handled by the I-2 rule below.
$script:DisabledEnginePlugins = @(
	"MetaHuman",
	"MetaHumanCalibrationProcessing",
	"MetaHumanLiveLink",
	"MetaHumanCoreTech",
	"CaptureManagerCore",
	"CaptureData"
)

function Get-NormalizedPath([string]$Path)
{
	return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-PathUnder([string]$Path, [string]$Root)
{
	$P = (Get-NormalizedPath $Path) + "\"
	$R = (Get-NormalizedPath $Root) + "\"
	return $P.StartsWith($R, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-NotProtected([string]$Path, [string]$What)
{
	foreach ($Dir in $script:ProtectedDirs)
	{
		if (Test-PathUnder $Path $Dir)
		{
			throw "$What '$Path' is inside the protected location '$Dir' (CLAUDE.md section 0a). Refusing."
		}
	}
}

function Assert-InsideRepo([string]$Path, [string]$What)
{
	if (-not (Test-PathUnder $Path $script:RepoRoot))
	{
		throw "$What '$Path' is outside the repository '$($script:RepoRoot)'. Refusing."
	}
}

# Checks the engine used by a command. Without -AllowTargetEngine only an installed (launcher) build is accepted:
# UnrealBuildTool never rebuilds the modules of an installed build, so it cannot write into it.
function Assert-SafeEngine([string]$EngineDir, [switch]$AllowTargetEngine)
{
	if (-not (Test-Path (Join-Path $EngineDir "Engine\Build\Build.version")))
	{
		throw "'$EngineDir' is not an Unreal Engine root (Engine\Build\Build.version not found)."
	}
	$IsTarget = Test-PathUnder $EngineDir $script:TargetEngineDir
	if ($IsTarget -and -not $AllowTargetEngine)
	{
		throw "Engine '$EngineDir' is the TARGET engine (NvRTX). It is used only in P7 with -AllowTargetEngine and the user's approval. Refusing."
	}
	if (-not $IsTarget -and -not (Test-Path (Join-Path $EngineDir "Engine\Build\InstalledBuild.txt")))
	{
		throw "Engine '$EngineDir' is not an installed build (no Engine\Build\InstalledBuild.txt): UnrealBuildTool could rebuild it. Refusing."
	}
}

# Reads EngineAssociation of a .uproject and refuses projects associated with the TARGET engine (unless allowed).
function Assert-ProjectAssociation([string]$UProject, [switch]$AllowTargetEngine)
{
	$Json = Get-Content -Raw -LiteralPath $UProject | ConvertFrom-Json
	$Assoc = [string]$Json.EngineAssociation
	if (($Assoc -eq $script:TargetEngineGuid -or $Assoc -match "NVRTX") -and -not $AllowTargetEngine)
	{
		throw "Project '$UProject' is associated with the TARGET engine ($Assoc). Refusing."
	}
	return $Assoc
}

# Writes a CSV snapshot (relative path, size, last write time UTC ticks) of every file under Root.
function New-TreeSnapshot([string]$Root, [string]$OutCsv)
{
	$RootFull = Get-NormalizedPath $Root
	$Sb = New-Object System.Text.StringBuilder
	[void]$Sb.AppendLine("Path,Length,LastWriteUtcTicks")
	$Count = 0
	foreach ($F in [System.IO.Directory]::EnumerateFiles($RootFull, "*", [System.IO.SearchOption]::AllDirectories))
	{
		$Info = New-Object System.IO.FileInfo($F)
		$Rel = $F.Substring($RootFull.Length + 1).Replace('"', '""')
		[void]$Sb.Append('"').Append($Rel).Append('",').Append($Info.Length).Append(',').AppendLine($Info.LastWriteTimeUtc.Ticks)
		$Count++
	}
	$Dir = Split-Path -Parent $OutCsv
	if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
	[System.IO.File]::WriteAllText($OutCsv, $Sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
	return $Count
}

# Compares two snapshots; returns a list of "ADDED/REMOVED/CHANGED <path>" lines (empty when identical).
function Compare-TreeSnapshot([string]$BeforeCsv, [string]$AfterCsv)
{
	$Before = @{}
	foreach ($Row in (Import-Csv -LiteralPath $BeforeCsv)) { $Before[$Row.Path] = "$($Row.Length)|$($Row.LastWriteUtcTicks)" }
	$Diff = New-Object System.Collections.Generic.List[string]
	$Seen = @{}
	foreach ($Row in (Import-Csv -LiteralPath $AfterCsv))
	{
		$Seen[$Row.Path] = $true
		if (-not $Before.ContainsKey($Row.Path)) { $Diff.Add("ADDED   $($Row.Path)") }
		elseif ($Before[$Row.Path] -ne "$($Row.Length)|$($Row.LastWriteUtcTicks)") { $Diff.Add("CHANGED $($Row.Path)") }
	}
	foreach ($Key in $Before.Keys) { if (-not $Seen.ContainsKey($Key)) { $Diff.Add("REMOVED $Key") } }
	return ,$Diff
}

# --- Known DEV-engine exception (incident I-2, rule approved by the user on 2026-11-18) ---
# Building an UnrealEditor target on the launcher UE 5.6 makes UnrealBuildTool write build intermediates into
# five engine plugin Intermediate folders. This is allowed ONLY for the DEV engine and ONLY when every entry of the
# before/after diff satisfies all of:
#   - ADDED or CHANGED (any REMOVED file is a violation);
#   - inside one of the five folders below;
#   - file type .rsp, .rsp.old, .gen.cpp, Module.*.cpp (UBT unity file), .h, .json or a file named Timestamp;
#   - a CHANGED file must have been created on/after 2026-11-18 (files of the engine installation that existed
#     before that day must never change);
#   - every absolute path inside the file is under <repo>\.uedev\, the DEV engine folder,
#     C:\Program Files\Microsoft Visual Studio\2022\ or C:\Program Files (x86)\Windows Kits\10\.
# Second allowed item: the empty (0 bytes) marker Engine\Intermediate\Build\BuildCookRun\StagedBuild_<P>.ini that
# RunUAT BuildCookRun -stage writes, for P = LightSequenceBP or LightSequenceDev (approved 2026-11-18).
# Anything else stops the work (CLAUDE.md section 0a). Never applied to the TARGET engine.
$script:DevEngineAllowedDirs = @(
	"Engine\Plugins\MetaHuman\MetaHumanAnimator\Intermediate\",
	"Engine\Plugins\MetaHuman\MetaHumanCoreTechLib\Intermediate\",
	"Engine\Plugins\MetaHuman\MetaHumanCalibrationProcessing\Intermediate\",
	"Engine\Plugins\VirtualProduction\CaptureManager\CaptureManagerCore\Intermediate\",
	"Engine\Plugins\VirtualProduction\CaptureData\Intermediate\"
)
$script:DevEngineExceptionSince = [datetime]"2026-11-18"

function Test-AllowedIntermediateName([string]$Name)
{
	if ($Name -eq "Timestamp") { return $true }
	if ($Name -match '^Module\.[\w]+(\.\d+)?\.cpp$') { return $true }
	foreach ($Suffix in @(".rsp", ".rsp.old", ".gen.cpp", ".h", ".json"))
	{
		if ($Name.EndsWith($Suffix, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
	}
	return $false
}

# Returns the absolute paths found in a text file that are outside the allowed roots.
function Get-ForeignAbsolutePaths([string]$File, [string]$EngineDir)
{
	# Note: in PowerShell the comma binds tighter than "+", so each root is built separately.
	$RepoUedev = (Join-Path $script:RepoRoot ".uedev") + "\"
	$EngineRoot = (Get-NormalizedPath $EngineDir) + "\"
	$Roots = @($RepoUedev, $EngineRoot, "C:\Program Files\Microsoft Visual Studio\2022\", "C:\Program Files (x86)\Windows Kits\10\")
	$Foreign = New-Object System.Collections.Generic.List[string]
	$Text = [System.IO.File]::ReadAllText($File)
	foreach ($M in [regex]::Matches($Text, '(?i)(?<![A-Za-z])[A-Z]:[\\/][^"\r\n;,]*'))
	{
		$P = $M.Value.Replace('/', '\')
		$Ok = $false
		foreach ($R in $Roots) { if ($P.StartsWith($R, [System.StringComparison]::OrdinalIgnoreCase)) { $Ok = $true; break } }
		if (-not $Ok) { $Foreign.Add($P) }
	}
	return ,$Foreign
}

# Evaluates a before/after engine diff. Returns an object with Allowed (count) and Violations (list of strings).
function Test-EngineDiff([string]$EngineDir, [System.Collections.Generic.List[string]]$Diff, [switch]$IsTargetEngine)
{
	$Violations = New-Object System.Collections.Generic.List[string]
	$Allowed = 0
	foreach ($Line in $Diff)
	{
		$Kind, $Rel = $Line -split '\s+', 2
		if ($IsTargetEngine) { $Violations.Add("$Line (TARGET engine: no exceptions)"); continue }
		if ($Kind -eq "REMOVED") { $Violations.Add("$Line (deletion)"); continue }
		# RunUAT BuildCookRun -stage always writes an empty marker Engine\Intermediate\Build\BuildCookRun\
		# StagedBuild_<Project>.ini (CopyBuildToStagingDirectory.Automation.cs); allowed for the .uedev projects, 0 bytes only.
		if ($Rel -match '^Engine\\Intermediate\\Build\\BuildCookRun\\StagedBuild_(LightSequenceBP|LightSequenceDev)\.ini$')
		{
			if ((Get-Item -LiteralPath (Join-Path $EngineDir $Rel)).Length -eq 0) { $Allowed++ }
			else { $Violations.Add("$Line (StagedBuild marker is not empty)") }
			continue
		}
		$InDir = $false
		foreach ($D in $script:DevEngineAllowedDirs) { if ($Rel.StartsWith($D, [System.StringComparison]::OrdinalIgnoreCase)) { $InDir = $true; break } }
		if (-not $InDir) { $Violations.Add("$Line (outside the five allowed folders)"); continue }
		$Full = Join-Path $EngineDir $Rel
		if (-not (Test-AllowedIntermediateName ([System.IO.Path]::GetFileName($Rel)))) { $Violations.Add("$Line (file type not allowed)"); continue }
		if ($Kind -eq "CHANGED" -and (Get-Item -LiteralPath $Full).CreationTime -lt $script:DevEngineExceptionSince) { $Violations.Add("$Line (engine file older than 2026-11-18 changed)"); continue }
		$Foreign = Get-ForeignAbsolutePaths $Full $EngineDir
		if ($Foreign.Count -gt 0) { $Violations.Add("$Line (foreign absolute path: $($Foreign[0]))"); continue }
		$Allowed++
	}
	return [pscustomobject]@{ Allowed = $Allowed; Violations = $Violations }
}

# Text dump of HKCU\Software\Epic Games (values only), for before/after comparison. Read-only.
function Get-EpicRegistryDump()
{
	$Lines = New-Object System.Collections.Generic.List[string]
	$Root = "HKCU:\Software\Epic Games"
	if (-not (Test-Path $Root)) { return ,$Lines }
	$Keys = @(Get-Item $Root) + @(Get-ChildItem $Root -Recurse -ErrorAction SilentlyContinue)
	foreach ($K in $Keys)
	{
		foreach ($Name in $K.GetValueNames())
		{
			$Lines.Add("$($K.Name)\$Name = $($K.GetValue($Name))")
		}
		if ($K.ValueCount -eq 0) { $Lines.Add("$($K.Name)\") }
	}
	return ,$Lines
}

# Runs a native command, mirrors its output to the console and a log file, and kills the process tree
# as soon as a line matches one of the abort patterns (CLAUDE.md section 0a: stop the build immediately).
function Invoke-WatchedProcess([string]$Exe, [string]$Arguments, [string]$LogFile, [string[]]$AbortPatterns)
{
	$Dir = Split-Path -Parent $LogFile
	if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
	$ErrFile = "$LogFile.stderr.txt"
	Write-Host "RUN: `"$Exe`" $Arguments"
	Write-Host "LOG: $LogFile"
	$Proc = Start-Process -FilePath $Exe -ArgumentList $Arguments -NoNewWindow -PassThru `
		-RedirectStandardOutput $LogFile -RedirectStandardError $ErrFile
	# Windows PowerShell 5.1 loses ExitCode of Start-Process -PassThru unless the handle is read once.
	$null = $Proc.Handle
	$Pos = 0
	$Aborted = $null
	while ($true)
	{
		$Exited = $Proc.HasExited
		$Fs = [System.IO.File]::Open($LogFile, 'Open', 'Read', 'ReadWrite')
		try
		{
			[void]$Fs.Seek($Pos, 'Begin')
			$Reader = New-Object System.IO.StreamReader($Fs)
			$Chunk = $Reader.ReadToEnd()
			$Pos = $Fs.Position
		}
		finally { $Fs.Dispose() }
		if ($Chunk.Length -gt 0)
		{
			foreach ($Line in ($Chunk -split "`r?`n"))
			{
				if ($Line.Length -eq 0) { continue }
				Write-Host $Line
				foreach ($Pat in $AbortPatterns)
				{
					if ($Line -match $Pat) { $Aborted = "pattern '$Pat' matched: $Line"; break }
				}
				if ($Aborted) { break }
			}
		}
		if ($Aborted)
		{
			Write-Host "ABORT: $Aborted" -ForegroundColor Red
			& taskkill.exe /T /F /PID $Proc.Id | Out-Host
			throw "Build aborted by the safety watch: $Aborted"
		}
		if ($Exited) { break }
		Start-Sleep -Milliseconds 300
	}
	$Proc.WaitForExit()
	if ((Test-Path $ErrFile) -and (Get-Item $ErrFile).Length -gt 0) { Get-Content $ErrFile | Write-Host }
	return $Proc.ExitCode
}

# Abort patterns shared by the build scripts: any protected path in the output, or a compile/link action
# of a module that is not in the allow list (an engine module would mean UBT is rebuilding the engine).
function Get-DefaultAbortPatterns([string[]]$AllowedModules)
{
	$Patterns = @()
	foreach ($Dir in @($script:TargetEngineDir, "C:\UE_Backups", "D:\PRECIOSA\PixelStreaming_Project_1\_ue_\Scene_A1"))
	{
		$Patterns += [regex]::Escape($Dir)
		$Patterns += [regex]::Escape($Dir.Replace('\', '/'))
	}
	# UHT reporting that it rewrote a generated file inside an engine installation.
	$Patterns += "Changed:True Path:'C:\\Program Files\\Epic Games"
	$Allowed = ($AllowedModules | ForEach-Object { [regex]::Escape($_) }) -join "|"
	# UBT action lines look like "[3/12] Compile [x64] Module.LightSequence.cpp" or "[12/12] Link [x64] UnrealEditor-LightSequence.dll".
	$Patterns += "\]\s+Compile\s+\[\w+\]\s+Module\.(?!($Allowed)\b)[\w]+(\.\d+)?\.cpp"
	$Patterns += "\]\s+Link\s+\[\w+\]\s+UnrealEditor-(?!($Allowed)\b)[\w]+\.(dll|lib)"
	return $Patterns
}
