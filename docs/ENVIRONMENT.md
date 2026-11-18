# Environment (verified in P0, 2026-11-18)

Every value below was read on the development PC in task P0 with read-only commands (see `docs/reports/REPORT_P0.md`). The user's own survey is `docs/CURRENT_PC_ENV.md`.

## Engines (decision U10)

| | DEV engine | TARGET engine |
|---|---|---|
| Use | All development, builds, tests, packaging in P0..P6, P8 | Read-only reference; used only in P7, step by step with the user's approval |
| Kind | Stock UE from the Epic Games Launcher (installed build) | Source build, NVIDIA fork NvRTX Caustics |
| Path | `C:\Program Files\Epic Games\UE_5.6` | `D:\NVRTXCAUSTICS\5_6` |
| `Engine/Build/Build.version` | 5.6.1, Changelist 44394996, CompatibleChangelist 43139311, `IsPromotedBuild` 1, Branch `++UE5+Release-5.6` | 5.6.1, Changelist 0, CompatibleChangelist 43139311, `IsPromotedBuild` 0, Branch `UE5` |
| `Engine/Build/InstalledBuild.txt` | present (installed build: UBT never compiles engine modules) | absent (source build) |
| Registration | `HKLM\SOFTWARE\EpicGames\Unreal Engine\5.6` -> `InstalledDirectory`; also `HKCU\Software\Epic Games\Unreal Engine\Builds\{8BBBC3F2-4585-AC67-39DB-EBB1288119CE}` | `HKCU\Software\Epic Games\Unreal Engine\Builds\{394CF319-4D3A-7BC1-DA7B-CC849351994F}` |
| `EngineAssociation` for projects | `"5.6"` (used by `.uedev/LightSequenceDev` and `.uedev/LightSequenceBP`) | `"{394CF319-4D3A-7BC1-DA7B-CC849351994F}"` (used by `Scene_A1`) |
| `UnrealEditor.exe` / `UnrealEditor-Cmd.exe` | present / present | (not checked in P0) |
| `UnrealInsights.exe` | present (`Engine\Binaries\Win64\UnrealInsights.exe`) | not built (see `CURRENT_PC_ENV.md`) |
| `RunUAT.bat` | `C:\Program Files\Epic Games\UE_5.6\Engine\Build\BatchFiles\RunUAT.bat` (installed build: runs precompiled UAT, no compile) | `D:\NVRTXCAUSTICS\5_6\Engine\Build\BatchFiles\RunUAT.bat` (not run) |
| Compiler selection | No `BuildConfiguration.xml` in the engine. `Engine/Config/Windows/Windows_SDK.json`: preferred MSVC `14.38.33130-14.38.99999`, minimum `14.38.33130`, banned 14.39.x / 14.40.x; Windows SDK main `10.0.22621.0`, min `10.0.19041.0`. Every build in P0 printed `Using Visual Studio 2022 14.38.33145 toolchain (...\MSVC\14.38.33130) and Windows 10.0.22621.0 SDK` | Pinned in `Engine\Saved\UnrealBuildTool\BuildConfiguration.xml`: `VisualStudio2022`, `14.38.33130`, SDK `10.0.22621.0` (SHA-256 `D383CD2A...4FCE7`, unchanged during P0) |
| NTFS rights | The user account has **Full Control** on `Engine\Binaries\Win64`: Windows does not block writes into the DEV engine; protection relies on the rules of `CLAUDE.md` section 0a and on engine snapshots | (not checked) |

The DEV engine and the TARGET engine prefer the same MSVC / SDK versions; compiled plugin binaries are still tied to the engine build that compiled them (BuildId), so TARGET binaries are produced only in P7.

**Known DEV-engine behavior (incident I-2):** building an `UnrealEditor` target writes build intermediates into five `Engine\Plugins\...\Intermediate` folders (MetaHuman*, Capture*), and `RunUAT BuildCookRun -stage` writes an empty `Engine\Intermediate\Build\BuildCookRun\StagedBuild_<Project>.ini`. Tolerated only under the rule in `CLAUDE.md` section 0a; checked automatically by the scripts.

## Toolchain and tools

| Item | Value |
|---|---|
| OS | Windows 11 Home Single Language, build 26300 (from `CURRENT_PC_ENV.md`; not re-read) |
| Visual Studio | Community 2022, `installationVersion` 17.14.37314.3 (`vswhere -all -products *`) |
| MSVC toolsets | `14.38.33130`, `14.44.35207` (`VC\Tools\MSVC`); the DEV engine selects 14.38.33130 (toolset 14.38.33145) |
| Windows SDKs | 10.0.19041.0, 10.0.22000.0, 10.0.22621.0, 10.0.26100.0 |
| .NET SDK (system) | 9.0.314; UAT/UBT of the DEV engine use the bundled .NET 8.0.300 (`Engine\Binaries\ThirdParty\DotNet\8.0.300`) |
| Python | 3.13.5 (for `tools/`) |
| Git | 2.50.1.windows.1 |
| PowerShell for scripts | Windows PowerShell 5.1 (`powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1`) |
| User-wide UBT config | `%APPDATA%\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml` exists (only `bWarningsAsErrors=false`, dated 2025-12-09, SHA-256 `55E8B034...AEF79`); it applies to **every** engine and must not be changed. `Documents\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml` does not exist |

## Repository folders for builds (all git-ignored, inside `.uedev/`)

| Folder | Content |
|---|---|
| `.uedev/LightSequenceDev/` | C++ development project (U9). `EngineAssociation` `"5.6"`. References the plugin of this repository through **`AdditionalPluginDirectories`: `["../../Plugins"]`** (no junction). Disables the MetaHuman*/Capture* plugins (I-2) |
| `.uedev/LightSequenceBP/` | Blueprint-only check project (U9): no `Source/`, `EngineAssociation` `"5.6"`, packaged plugin copied into `Plugins/LightSequence/`. Enables `DMXProtocol` and `DMXEngine` like the host project (see the U8 result in `REPORT_P0.md`) |
| `.uedev/_build/HostProject/` | Temporary host project of `tools/build_plugin.ps1` |
| `.uedev/_out/LightSequence/` | Packaged plugin (output of `tools/build_plugin.ps1`) |
| `.uedev/_out/LightSequenceBP_<Config>/` | Packaged Blueprint-only project (output of `tools/package_bp_project.ps1`) |
| `.uedev/_logs/` | Logs of every script run, engine snapshots (`engine_before.csv`, `engine_after.csv`, `engine_diff.txt`) |

## Writes outside the repository (approved for P0 by the user on 2026-11-18)

UE writes per-user caches and logs; the scripts redirect what can be redirected (UAT logs via `uebp_LogFolder` / `uebp_EngineSavedFolder`, UBT logs via `-log=`). Observed in P0: `%LOCALAPPDATA%\UnrealEngine` (Zen DDC, `5.6\Saved`, `Common\UnrealTrace`, `Common\Analytics`, editor json settings), `%LOCALAPPDATA%\CrashReportClient\Saved\Logs`, `%TEMP%\UAT` (UAT rules assembly of installed engines), `C:\ProgramData\Epic` (Zen state file, crash-reporter marker). Details per run: `docs/reports/REPORT_P0.md`.

## Scripts

| Script | Purpose |
|---|---|
| `tools/ue_safety.ps1` | Shared checks: protected locations, engine/project association, engine snapshots, the I-2 rule (`Test-EngineDiff`), registry dump, watched process with abort patterns |
| `tools/build_plugin.ps1` | Build + package the plugin (equivalent of `RunUAT BuildPlugin`, own host project). Default engine: DEV; refuses the TARGET engine without `-AllowTargetEngine` (P7 only) |
| `tools/run_tests.ps1` | Build `.uedev/LightSequenceDev` (editor) and run the automation tests `LightSequence.` headless |
| `tools/package_bp_project.ps1` | `RunUAT BuildCookRun` of `.uedev/LightSequenceBP` (Development / Shipping) and a start of the packaged exe |
