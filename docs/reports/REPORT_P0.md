# REPORT P0: environment, scaffolding, packaging check (DEV engine)

Date: 2026-11-18. Branch: `dev/v0.1.0` (checked with `git branch --show-current` before any work). Plugin `VersionName` 0.1.0.

## Result in short

| Acceptance item | Status |
|---|---|
| `docs/ENVIRONMENT.md` with both engines | Done |
| Plugin builds on the DEV engine with the script | Done: `tools/build_plugin.ps1`, last run 14:17:19, exit 0 |
| Packaged Blueprint-only project (DEV engine) starts and its log shows the plugin function was called | Done for **Development** (via the console command `LightSequence.PrintVersion`, which calls the Blueprint function; log line below). Shipping: packaged and started (runs, no crash), no log in Shipping. **The Level Blueprint variant is a manual step for the user** (not done yet, see "Open questions") |
| Report lists every command that wrote files; nothing written into protected locations | Listed below. **Not "nothing"**: the DEV engine folder (protected location 3) received files, see incident I-2 (approved by the user as a known exception, rule in `CLAUDE.md` section 0a). TARGET engine, `Scene_A1`, `C:\UE_Backups`: no change found |
| Automation suite `LightSequence.` passes | 1 of 1 passed (`LightSequence.Smoke.PluginVersion`) |

## What changed in the repository

- `Plugins/LightSequence/` (from the first P0 attempt, reviewed and kept): `.uplugin` (0.1.0, Runtime module `LightSequence`, `PlatformAllowList` Win64, `CanContainContent` true, `EngineVersion` 5.6.0; the default field `IsExperimentalVersion: false` removed so that the packaged descriptor equals the stock one), module with `LogLightSequence`, `ULightSequenceLibrary::GetPluginVersion()` (BlueprintPure), smoke test. **New:** console command `LightSequence.PrintVersion` (`FAutoConsoleCommand`, verified in `Engine/Source/Runtime/Core/Public/HAL/IConsoleManager.h` of 5.6), `README.md` (user docs, manual editor steps, packaging note).
- `tools/ue_safety.ps1`, `tools/build_plugin.ps1`, `tools/run_tests.ps1`, `tools/package_bp_project.ps1` (new).
- `docs/ENVIRONMENT.md` (new), `docs/INCIDENTS.md` (I-2), `docs/BACKLOG.md` (R2 result, new R5), `CLAUDE.md` section 0a (I-2 rule; no user-wide UBT config, no registry), `README.md` (status line).
- Git-ignored, not committed: `.uedev/LightSequenceDev/` (re-associated from the old NvRTX GUID `{CB5F2325-...}` to `"5.6"`, the NvRTX flags `/wd4458 /wd4723` removed from `LightSequenceDevEditor.Target.cs`, its old `Binaries/ Intermediate/ Saved/` and `Plugins/LightSequence/Intermediate/` from the first attempt deleted; the old `Saved/UnrealBuildTool/BuildConfiguration.xml` was an empty configuration), `.uedev/LightSequenceBP/` (new), `.uedev/_build`, `.uedev/_out`, `.uedev/_logs`.

## Step 1: environment (read-only)

See `docs/ENVIRONMENT.md`. Key facts: DEV engine `C:\Program Files\Epic Games\UE_5.6` is **5.6.1** (CL 44394996, installed build, `InstalledBuild.txt` present, `UnrealInsights.exe` present), `EngineAssociation` `"5.6"` (HKLM launcher key). Its UBT prefers MSVC 14.38.33130 / SDK 10.0.22621.0 (same as the TARGET pin); every build printed `Using Visual Studio 2022 14.38.33145 toolchain (...\MSVC\14.38.33130) and Windows 10.0.22621.0 SDK`. The user account has Full Control on the DEV engine folder (no OS protection).

## Step 2: build script, and how it differs from the stock `RunUAT BuildPlugin`

The first run used the stock `RunUAT BuildPlugin` and caused incident I-2 (below). `tools/build_plugin.ps1` now does the same work in two steps:

1. Stages a host project in `.uedev/_build/HostProject/HostProject.uproject` (same folder/file name as the stock one, so UHT-generated identifiers match) with a copy of the plugin without `Binaries/Intermediate`. Difference: it also disables the MetaHuman*/Capture* engine plugins (user's requirement; measured: this does not stop the I-2 writes).
2. Runs UBT of the engine for `UnrealEditor Win64 Development`, `UnrealGame Win64 Development`, `UnrealGame Win64 Shipping` with BuildPlugin's arguments (`-plugin -noubtmakefiles -manifest -nohotreload`), then packages with the rules of `BuildPluginCommand.Automation.cs` (5.6): descriptor, build products from the UBT manifests, `/Source`, `/Resources`, `/Content`, `/Shaders`, `/Binaries/ThirdParty`, `/Intermediate/Build/.../Inc`, `Config/FilterPlugin.ini` rules; descriptor gets `Installed: true`, `EngineVersion: 5.6.0`, no `EnabledByDefault`, CRLF.

Extra safety in the script: refuses the TARGET engine without `-AllowTargetEngine`, refuses non-installed engines, refuses output folders outside the repository or in protected locations (both refusals tested: `-EngineDir D:\NVRTXCAUSTICS\5_6` and `-OutDir ...\Scene_A1\Plugins` exit 1 before writing anything); aborts on compile/link of a foreign module or a protected path in the output; snapshot of the whole engine folder (~218,000 files) before and after, checked by the I-2 rule.

**Package comparison with the stock BuildPlugin output** (kept in `.uedev/_out/LightSequence_reference_stock_buildplugin`, measured on the 09:59:46 run): same 32 file paths; 18 files byte-identical (sources, descriptor content, UHT `.gen.cpp` / `.generated.h`, `.precompiled`); 14 differ only because of absolute paths of the temporary folder (UHT `Timestamp`, `.obj`, `.lib`, `.dll`, `.pdb`) and the descriptor's line endings (fixed afterwards: CRLF). Final package: 33 files (+ `README.md`).

Note on the user's wish "package without Intermediate": the **stock** BuildPlugin package contains `Intermediate/Build/.../Inc` (UHT headers) and, for game targets, `.obj` + `.precompiled` files; they are what lets a project without plugin sources link the plugin. Our package keeps them to stay equal to the stock one.

## Step 3: packaging check (U8, DEV engine)

`.uedev/LightSequenceBP/`: no `Source/`, `EngineAssociation` `"5.6"`, packaged plugin in `Plugins/LightSequence/`, default map `/Engine/Maps/Entry`.

| Run (log folder in `.uedev/_logs/`) | Result |
|---|---|
| `package_bp_Development_20261118_140544` (project enables only LightSequence) | `BUILD SUCCESSFUL`, **no C++ compiled** (0 compile lines), staged the engine's precompiled game exe. Packaged exe: `LogPluginManager: Error: Plugin 'LightSequence' failed to load because module 'LightSequence' could not be found.` Cause in UE source: `UnrealBuildTool/System/Plugins.cs:129` (a project plugin without `EnabledByDefault` is enabled by default) + `NativeProjects.cs` `RequiresTempTargetForCodePlugin` (temp target only if the project's code plugins differ from the default set) |
| `package_bp_Development_20261118_140818` (project also enables `DMXProtocol`, `DMXEngine`, as `Scene_A1` does) | UAT: `LightSequenceBP.uproject is has no code, but is being treated as a code-based project ... because: DMXProtocol plugin is enabled. Creating temporary .Target.cs files.` **C++ compiled**: `Compile [x64] Module.LightSequence.cpp`, `LightSequenceLibrary.cpp`, `LightSequenceModule.cpp`, `LightSequenceBP.cpp`, `Link [x64] LightSequenceBP.exe`. Then failed: `Could not find file ...\LightSequenceBPEditor.target` (my flag `-nocompileeditor`; a code-based project needs its editor target for the cook) |
| `package_bp_Development_20261118_141023` (without `-nocompileeditor`) | Editor target of the project built (`UnrealEditor-LightSequenceBP.dll`, **and the plugin's editor DLL rebuilt in `.uedev/LightSequenceBP/Plugins/LightSequence/Binaries/Win64/` from its `Source/`**), cook, stage, pak, archive: `BUILD SUCCESSFUL`. Packaged exe run with `-ExecCmds="LightSequence.PrintVersion,quit" -nullrhi`: exit code 0, log lines below |
| `package_bp_Shipping_20261118_141243` | C++ compiled (`Link [x64] LightSequenceBP-Win64-Shipping.exe`), `BUILD SUCCESSFUL`. Exe still running after 20 s, then closed by the script (taskkill); no crash folder. No log (Shipping) |

Packaged Development exe log (`package_bp_Development_20261118_141023/packaged_game.log`):

```
LogPluginManager: Mounting Project plugin LightSequence
LogInit: Engine Version: 5.6.1-44394996+++UE5+Release-5.6
LogInit: Build Configuration: Development
[2026.11.18-13.11.44:329][  0]LogLightSequence: LightSequence module started, plugin version 0.1.0
[2026.11.18-13.11.44:393][  0]LogLightSequence: GetPluginVersion called: 0.1.0
[2026.11.18-13.11.45:372][  1]LogLightSequence: LightSequence module shut down
```

**U8 answer (DEV engine):** packaging a Blueprint-only project with this code plugin compiles C++ (a temporary game target in `Intermediate/Source/`, the project stays without `Source/`) **only if** the project's code-plugin set differs from the default one; the plugin alone does not trigger it and then the packaged game silently lacks the module. `Scene_A1` enables engine code plugins, so it is in the working case. The temporary target makes the cook require the project's editor target, which also rebuilds the plugin's editor DLL inside the project's `Plugins/` folder.

## Automation tests

`tools/run_tests.ps1` (builds `LightSequenceDevEditor`, then `UnrealEditor-Cmd.exe <uproject> -ExecCmds="Automation RunTests LightSequence; Quit" -unattended -nullrhi -nop4 ...`). Last run `run_tests_20261118_100720` (after the last code change): `Success LightSequence.Smoke.PluginVersion`, `Tests: 1 of 1 passed`, `**** TEST COMPLETE. EXIT CODE: 0 ****`. The dev project uses `AdditionalPluginDirectories: ["../../Plugins"]` (no junction).

## Every command that wrote files

All runs used the **DEV engine** (`C:\Program Files\Epic Games\UE_5.6`); every `.uproject` involved had `EngineAssociation` `"5.6"` (checked by the scripts). Engine snapshot results are per run.

| Time | Command | Wrote to | Engine folder diff |
|---|---|---|---|
| 09:2x | delete leftovers of the first attempt | `.uedev/LightSequenceDev/{Binaries,Intermediate,Saved}`, `Plugins/LightSequence/Intermediate` (repo) | - |
| 09:26:49 | `build_plugin.ps1` v1 = `RunUAT BuildPlugin` | `.uedev/_out`, `.uedev/_logs` | **1,074 added** (I-2), stop |
| 09:3x | delete those 1,074 files after per-file check (user's approval) | DEV engine | snapshot after: **0 differences** to before (216,541 files) |
| 09:36:43 | `build_plugin.ps1` v2 (own host project) | `.uedev/_build`, `_out`, `_logs` | 1,074 added again (same set), stop |
| 09:45:12 | `build_plugin.ps1` (hash allow list) | same | 27 changed (UHT `Timestamp` line order), stop |
| 09:50:19 | `build_plugin.ps1` (sorted-line hashes) | same | 27 changed, 0 violations |
| 09:52:51 | `build_plugin.ps1` (host folder renamed to `HostProject`) | same | 1,537 (755 new `.rsp.old`), stop |
| 09:59:46 | `build_plugin.ps1` (rule-based check) | same | 27, all allowed |
| 10:02:33 | `run_tests.ps1` | `.uedev/LightSequenceDev`, `Plugins/LightSequence/{Binaries,Intermediate}`, `_logs` | 0 |
| 10:05:32 | `build_plugin.ps1` (after adding the console command) | `_build`, `_out`, `_logs` | 27, all allowed |
| 10:07:20 | `run_tests.ps1` | as above | 0 |
| 10:09:41 | `package_bp_project.ps1 -Configuration Development` | `.uedev/LightSequenceBP`, `_logs` | **interrupted by my mistake** (a `Select-Object -First 90` in my output filter stopped the pipeline and killed the run during the cook; no UE process remained). Manual snapshot: 1 added: `Engine\Intermediate\Build\BuildCookRun\StagedBuild_LightSequenceBP.ini` (0 bytes), stop |
| 14:05:44 | `package_bp_project.ps1 -Configuration Development` | `.uedev/LightSequenceBP`, `.uedev/_out/LightSequenceBP_Development`, `_logs`, `%TEMP%\UAT` | 1 (marker, allowed) |
| 14:08:18 | same, with DMX plugins enabled | same | 0 |
| 14:10:23 | same, without `-nocompileeditor` | same | 1 (marker, allowed) |
| 14:12:43 | `package_bp_project.ps1 -Configuration Shipping` | same + `_out/LightSequenceBP_Shipping` | 1 (marker, allowed) |
| 14:17:19 | `build_plugin.ps1` (final package with README) | `_build`, `_out`, `_logs` | 27, all allowed |

Files currently in the DEV engine because of P0 (rollback: delete files created on/after 2026-11-18 in the five folders and the marker, or Launcher "Verify"): build intermediates in the five `Engine\Plugins\...\Intermediate` folders (I-2), `Engine\Intermediate\Build\BuildCookRun\StagedBuild_LightSequenceBP.ini` (0 bytes). The empty folders left by the 09:3x deletion were not removed (the user allowed deleting files only); they were filled again by the following builds.

### Outside the repository (approved for P0: UE caches and logs)

Files with a write time after 09:20 (counted at about 14:15): `%LOCALAPPDATA%\UnrealEngine` 118 (100 `Common\Zen`, 12 `Common\UnrealTrace`, 1 `Common\Analytics`, 1 `5.6\Saved`, 4 `Editor\*.json`), `%LOCALAPPDATA%\CrashReportClient\Saved\Logs` 6 (logs of the crash reporter that every editor/cook run starts; no crash), `%TEMP%\UAT` 3 (UAT rules assembly), **`C:\ProgramData\Epic`** 2 (`Zen\States\0a25bb50...` 191 bytes, written by the Zen server; `NotAllowedUnattendedBugReports` 0 bytes, created 09:19:52, i.e. before the first build of this session, last written 14:14:05). `%LOCALAPPDATA%\UnrealBuildTool` 0 and `%APPDATA%\Unreal Engine` 0 (logs redirected by the scripts). `%LOCALAPPDATA%\Microsoft\VisualStudio\Packages\_Instances\d7322f7f\state.json` was written at 12:37, when no command of this session ran (not attributed to P0).

### Verified unchanged

- TARGET engine: 0 files in `D:\NVRTXCAUSTICS\5_6\Engine\Binaries\Win64` and `Engine\Saved\UnrealBuildTool` with a write time after 09:20; its `BuildConfiguration.xml` SHA-256 `D383CD2A...4FCE7` unchanged. (The whole TARGET engine tree was not snapshotted.)
- `Scene_A1`: 0 files with a write time after 09:20. `C:\UE_Backups`: 0.
- `%APPDATA%\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml` SHA-256 `55E8B034...AEF79` unchanged; `Documents\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml` still absent.
- `HKCU\Software\Epic Games`: 28 value lines, identical to the dump taken before the first build. Note: the in-script registry check of `run_tests.ps1` (10:02, 10:07) compared two list objects and could not detect a change (bug found at 14:0x and fixed; the comparison against the session baseline above was done with the fixed code).

## Measured numbers

- Engine snapshot size: 216,541 files before the first build; 218,370 after the I-2 files were accepted.
- `build_plugin.ps1`: 1 min 50 s .. 3 min 06 s per run (including two engine snapshots). `run_tests.ps1`: 2 min 18 s. `package_bp_project.ps1`: Development 2 min 00 s, Shipping 2 min 16 s.
- Packaged plugin (14:17 build): 33 files; `UnrealEditor-LightSequence.dll` 100,352 bytes (with the console command; 78,848 bytes before it was added).
- Hardware: not relevant for P0; not measured.

## Not verified

- Calling `Get Plugin Version` from a **Level Blueprint** in the editor and in the packaged exe (needs the editor; manual steps in `Plugins/LightSequence/README.md`, section "P0 check").
- Shipping: that the plugin function runs (no log, no console commands in Shipping); only start + 20 s run.
- The TARGET engine as a whole (only the folders listed above were checked).

## Open questions for the user

1. Manual step: please do the Level Blueprint check in `.uedev/LightSequenceBP` (README, 12 steps) and tell me; I then repackage and check the packaged log for the BeginPlay call.
2. `C:\ProgramData\Epic` (Zen state file, crash-reporter marker) is outside the folders you approved (`%LOCALAPPDATA%`, `%APPDATA%`). Allow it for the next tasks, or should I look for a way to avoid it?
3. `.uedev/LightSequenceBP` now enables `DMXProtocol` and `DMXEngine` (like `Scene_A1`) so that packaging compiles the plugin. Keep it so?
4. For P7 (to be covered by the plan): packaging `Scene_A1` writes `StagedBuild_Scene_A1.ini` into the TARGET engine folder (already happens in your own packaging), and rebuilds the plugin's editor DLL inside `Scene_A1\Plugins\LightSequence\Binaries`.
