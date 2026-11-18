<#
.SYNOPSIS
	Builds and packages the LightSequence plugin (task P0, CLAUDE.md section 0a, incident I-2).

.DESCRIPTION
	Equivalent of "RunUAT BuildPlugin -TargetPlatforms=Win64 -HostPlatforms=Win64", done in two steps so that
	the host project is under our control:

	1. A host project is staged in <repo>\.uedev\_build\HostProject\ (a copy of the plugin without Binaries/
	   Intermediate + HostProject.uproject, same folder and file name as the stock BuildPlugin uses, so the
	   UHT-generated identifiers match). Unlike the stock host project it disables the MetaHuman*/Capture*
	   engine plugins (user's requirement after incident I-2; measured: this alone does not stop the writes
	   described below).
	2. UnrealBuildTool of the engine compiles UnrealEditor Win64 Development, UnrealGame Win64 Development and
	   UnrealGame Win64 Shipping with the same arguments BuildPlugin uses (-plugin, -noubtmakefiles, -manifest,
	   -nohotreload). The package is assembled with the rules of BuildPluginCommand.Automation.cs (UE 5.6):
	   descriptor, build products from the UBT manifests, /Source, /Resources, /Content, /Shaders,
	   /Binaries/ThirdParty, /Intermediate/Build/.../Inc, rules of Config/FilterPlugin.ini; the descriptor gets
	   "Installed": true, "EngineVersion": "<major>.<minor>.0" and no "EnabledByDefault".

	Engine: default is the DEV engine (stock launcher UE 5.6). The TARGET engine (D:\NVRTXCAUSTICS\5_6) is
	refused unless -AllowTargetEngine is given (P7 only, with the user's approval); any other engine must be an
	installed build.

	Writes only to: the package folder (default <repo>\.uedev\_out\LightSequence, must be inside the repo),
	<repo>\.uedev\_build\HostProject, <repo>\.uedev\_logs\build_plugin_<stamp>, and per-user UE caches
	(%LOCALAPPDATA%\UnrealEngine, %LOCALAPPDATA%\UnrealBuildTool). Known exception (incident I-2, accepted by
	the user): on the DEV engine, UBT writes build intermediates (.rsp, .rsp.old, .gen.cpp, Module.*.cpp, .h,
	.json, Timestamp) into five Engine\Plugins\...\Intermediate folders. The engine folder is snapshotted before
	and after and every difference is checked by the I-2 rule (tools\ue_safety.ps1, Test-EngineDiff); any
	other difference makes the script fail (exit code 3).

.EXAMPLE
	powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_plugin.ps1
#>
[CmdletBinding()]
param(
	[string]$EngineDir = "C:\Program Files\Epic Games\UE_5.6",
	[string]$OutDir = "",
	[switch]$AllowTargetEngine,
	[switch]$SkipEngineSnapshot
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\ue_safety.ps1"

$Repo = $script:RepoRoot
$PluginName = "LightSequence"
$PluginDir = Join-Path $Repo "Plugins\$PluginName"
$PluginFile = Join-Path $PluginDir "$PluginName.uplugin"
if ([string]::IsNullOrEmpty($OutDir)) { $OutDir = Join-Path $Repo ".uedev\_out\$PluginName" }
$OutDir = Get-NormalizedPath $OutDir
$EngineDir = Get-NormalizedPath $EngineDir
$HostDir = Join-Path $Repo ".uedev\_build\HostProject"

# --- Safety checks (CLAUDE.md section 0a) ---
Assert-SafeEngine $EngineDir -AllowTargetEngine:$AllowTargetEngine
foreach ($P in @($OutDir, $HostDir))
{
	Assert-InsideRepo $P "Output folder"
	Assert-NotProtected $P "Output folder"
	if (Test-PathUnder $P $PluginDir) { throw "Output folder '$P' must not be inside the plugin folder." }
}

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir = Join-Path $Repo ".uedev\_logs\build_plugin_$Stamp"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$DotNet = Get-ChildItem (Join-Path $EngineDir "Engine\Binaries\ThirdParty\DotNet\*\win-x64\dotnet.exe") | Select-Object -First 1 -ExpandProperty FullName
$UbtDll = Join-Path $EngineDir "Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll"
if (-not $DotNet -or -not (Test-Path $UbtDll)) { throw "UnrealBuildTool or its bundled dotnet not found in '$EngineDir'." }

Write-Host "Engine     : $EngineDir"
Write-Host "UBT        : $UbtDll"
Write-Host "Plugin     : $PluginFile"
Write-Host "Host proj. : $HostDir"
Write-Host "Package to : $OutDir"
Write-Host "Logs       : $LogDir"
Write-Host "Writes     : $HostDir, $OutDir, $LogDir, %LOCALAPPDATA%\UnrealEngine, %LOCALAPPDATA%\UnrealBuildTool"

if (-not $SkipEngineSnapshot)
{
	Write-Host "Snapshot of engine files (before)..."
	$N = New-TreeSnapshot $EngineDir (Join-Path $LogDir "engine_before.csv")
	Write-Host "  $N files"
}

# --- 1. Stage the host project ---
if (Test-Path $HostDir) { Remove-Item -Recurse -Force -LiteralPath $HostDir }
$HostPluginDir = Join-Path $HostDir "Plugins\$PluginName"
New-Item -ItemType Directory -Force -Path $HostPluginDir | Out-Null
Get-ChildItem -LiteralPath $PluginDir -Force | Where-Object { $_.Name -notin @("Binaries", "Intermediate", "Saved") } |
	ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $HostPluginDir -Recurse -Force }
$HostProject = Join-Path $HostDir "HostProject.uproject"
$PluginEntries = @("`t`t{ `"Name`": `"$PluginName`", `"Enabled`": true }")
foreach ($Name in $script:DisabledEnginePlugins) { $PluginEntries += "`t`t{ `"Name`": `"$Name`", `"Enabled`": false }" }
$HostJson = "{`r`n`t`"FileVersion`": 3,`r`n`t`"Plugins`": [`r`n" + ($PluginEntries -join ",`r`n") + "`r`n`t]`r`n}`r`n"
[System.IO.File]::WriteAllText($HostProject, $HostJson, (New-Object System.Text.UTF8Encoding($false)))
$HostPluginFile = Join-Path $HostPluginDir "$PluginName.uplugin"

# --- 2. Compile with UnrealBuildTool ---
$Abort = Get-DefaultAbortPatterns @($PluginName)
$Manifests = @()
$Targets = @(
	@{ Name = "UnrealEditor"; Config = "Development" },
	@{ Name = "UnrealGame"; Config = "Development" },
	@{ Name = "UnrealGame"; Config = "Shipping" }
)
foreach ($T in $Targets)
{
	$Manifest = Join-Path $HostDir "Saved\Manifest-$($T.Name)-Win64-$($T.Config).xml"
	$UbtLog = Join-Path $LogDir "UBT-$($T.Name)-Win64-$($T.Config).txt"
	$UbtArgs = "`"$UbtDll`" $($T.Name) Win64 $($T.Config) -Project=`"$HostProject`" -plugin=`"$HostPluginFile`" -noubtmakefiles -manifest=`"$Manifest`" -nohotreload -log=`"$UbtLog`""
	$Code = Invoke-WatchedProcess $DotNet $UbtArgs (Join-Path $LogDir "console-$($T.Name)-$($T.Config).log") $Abort
	Write-Host "UBT $($T.Name) $($T.Config) exit code: $Code"
	if ($Code -ne 0) { throw "UnrealBuildTool failed ($($T.Name) $($T.Config)), exit code $Code." }
	$Manifests += $Manifest
}

# --- 3. Package (rules of BuildPluginCommand.Automation.cs, UE 5.6) ---
$BuildProducts = @{}
foreach ($M in $Manifests)
{
	[xml]$Xml = Get-Content -Raw -LiteralPath $M
	foreach ($Node in $Xml.SelectNodes("//BuildProducts/string")) { $BuildProducts[(Get-NormalizedPath $Node.InnerText).ToLowerInvariant()] = $true }
}

function ConvertTo-FilterRegex([string]$Rule)
{
	# FileFilter syntax: leading "/" = relative to plugin root, "..." = any path, "*" = any chars except "/", "?" = one char.
	$R = $Rule.Trim().Replace('\', '/')
	$Anchored = $R.StartsWith("/")
	$R = $R.TrimStart('/')
	$Rx = [regex]::Escape($R).Replace('\.\.\.', '.*').Replace('\*', '[^/]*').Replace('\?', '[^/]')
	if ($R.EndsWith("/")) { $Rx += ".*" }
	if ($Anchored) { return "^$Rx$" }
	return "(^|/)$Rx$"
}

$Include = @("/Binaries/ThirdParty/...", "/Resources/...", "/Content/...", "/Intermediate/Build/.../Inc/...", "/Shaders/...", "/Source/...") | ForEach-Object { ConvertTo-FilterRegex $_ }
$Exclude = @("/Tests/...") | ForEach-Object { ConvertTo-FilterRegex $_ }
$FilterIni = Join-Path $HostPluginDir "Config\FilterPlugin.ini"
foreach ($Ini in @($FilterIni, (Join-Path $HostPluginDir "Config\FilterPluginWin64.ini")))
{
	if (-not (Test-Path $Ini)) { continue }
	$InSection = $false
	foreach ($Line in Get-Content -LiteralPath $Ini)
	{
		$L = $Line.Trim()
		if ($L.StartsWith("[")) { $InSection = ($L -eq "[FilterPlugin]"); continue }
		if (-not $InSection -or $L.Length -eq 0 -or $L.StartsWith(";")) { continue }
		if ($L.StartsWith("-")) { $Exclude += ConvertTo-FilterRegex $L.Substring(1) } else { $Include += ConvertTo-FilterRegex $L }
	}
}
# Standard exclusion of restricted folders (RestrictedFolder names; none exist in this plugin).
$Restricted = "(^|/)(NotForLicensees|NoRedist|EpicInternal|CarefullyRedist|LimitedAccess)/"

if (Test-Path $OutDir) { Remove-Item -Recurse -Force -LiteralPath $OutDir }
$Root = (Get-NormalizedPath $HostPluginDir)
$Copied = 0
foreach ($F in [System.IO.Directory]::EnumerateFiles($Root, "*", [System.IO.SearchOption]::AllDirectories))
{
	$Rel = $F.Substring($Root.Length + 1).Replace('\', '/')
	$IsProduct = $BuildProducts.ContainsKey($F.ToLowerInvariant())
	$IsDescriptor = ($Rel -eq "$PluginName.uplugin")
	$Inc = $IsProduct -or $IsDescriptor -or [bool]($Include | Where-Object { $Rel -match $_ })
	if ($Inc -and -not $IsProduct -and -not $IsDescriptor -and ($Exclude | Where-Object { $Rel -match $_ })) { $Inc = $false }
	if ($Inc -and ($Rel -match $Restricted)) { $Inc = $false }
	if (-not $Inc) { continue }
	$Dest = Join-Path $OutDir $Rel
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
	Copy-Item -LiteralPath $F -Destination $Dest -Force
	(Get-Item -LiteralPath $Dest).IsReadOnly = $false
	$Copied++
}

# Descriptor: Installed = true, EngineVersion = "<major>.<minor>.0", no EnabledByDefault (as PackagePlugin does).
$Ver = Get-Content -Raw (Join-Path $EngineDir "Engine\Build\Build.version") | ConvertFrom-Json
$EngineVersion = "$($Ver.MajorVersion).$($Ver.MinorVersion).0"
$OutPluginFile = Join-Path $OutDir "$PluginName.uplugin"
$Text = Get-Content -Raw -LiteralPath $OutPluginFile
$Text = [regex]::Replace($Text, '(?m)^\s*"EnabledByDefault"\s*:\s*(true|false)\s*,\s*\r?\n', '')
$Text = [regex]::Replace($Text, '"Installed"\s*:\s*(true|false)', '"Installed": true')
$Text = [regex]::Replace($Text, '"EngineVersion"\s*:\s*"[^"]*"', "`"EngineVersion`": `"$EngineVersion`"")
$Text = [regex]::Replace($Text, "\r?\n", "`r`n")  # the stock PluginDescriptor.Save writes CRLF
[System.IO.File]::WriteAllText($OutPluginFile, $Text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Packaged $Copied files into $OutDir (EngineVersion $EngineVersion)"

# --- 4. Engine snapshot after ---
$Changed = $false
if (-not $SkipEngineSnapshot)
{
	Write-Host "Snapshot of engine files (after)..."
	[void](New-TreeSnapshot $EngineDir (Join-Path $LogDir "engine_after.csv"))
	$Diff = Compare-TreeSnapshot (Join-Path $LogDir "engine_before.csv") (Join-Path $LogDir "engine_after.csv")
	$Diff | Set-Content -Encoding UTF8 (Join-Path $LogDir "engine_diff.txt")
	$Check = Test-EngineDiff $EngineDir $Diff -IsTargetEngine:(Test-PathUnder $EngineDir $script:TargetEngineDir)
	Write-Host "Engine diff: $($Diff.Count) entries, $($Check.Allowed) allowed by the I-2 rule, $($Check.Violations.Count) violations."
	if ($Check.Violations.Count -gt 0)
	{
		$Changed = $true
		$Check.Violations | Set-Content -Encoding UTF8 (Join-Path $LogDir "engine_violations.txt")
		Write-Host "ENGINE FOLDER CHANGED OUTSIDE THE I-2 RULE (see engine_violations.txt). STOP and report." -ForegroundColor Red
		$Check.Violations | Select-Object -First 20 | Write-Host
	}
	else { Write-Host "Engine check passed." }
}
if ($Changed) { exit 3 }
exit 0
