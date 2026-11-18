# REPORT P0: environment, scaffolding, packaging check (DEV engine)

Date: 2026-11-18. Branch: `dev/v0.1.0` (checked with `git branch --show-current` before any work). Plugin `VersionName` 0.1.0.

**Status: P0 DONE (2026-11-18).** All acceptance items are met; the manual Level Blueprint step was done by the user and verified in the packaged exe (section "Manual step and README step 12").

## Result in short

| Acceptance item | Status |
|---|---|
| `docs/ENVIRONMENT.md` with both engines | Done |
| Plugin builds on the DEV engine with the script | Done: `tools/build_plugin.ps1`, last run 14:17:19, exit 0 |
| Packaged Blueprint-only project (DEV engine) starts and its log shows the plugin function was called | **Done.** Development: the Level Blueprint of map `P0Check` calls `Get Plugin Version` on BeginPlay; the packaged exe, started with `-ExecCmds="quit"` only (no console command), logs `GetPluginVersion called: 0.1.0` right after `LoadMap: /Game/Maps/P0Check` (run 19:39:06). Earlier also via the console command `LightSequence.PrintVersion` (run 14:10:23). Shipping: packaged and started (runs 20 s, no crash); Shipping writes no log |
| Report lists every command that wrote files; nothing written into protected locations | Listed below. **Not "nothing"**: the DEV engine folder (protected location 3) received files, see incident I-2 (approved by the user as known exceptions, rule in `CLAUDE.md` section 0a). TARGET engine, `Scene_A1`, `C:\UE_Backups`: no change found (rechecked after the last run) |
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

## Manual step and README step 12

The user did steps 1..11 of "P0 check" in `Plugins/LightSequence/README.md` in `.uedev/LightSequenceBP` (map `/Game/Maps/P0Check`, Level Blueprint: Event BeginPlay -> Print String(Get Plugin Version); Game Default Map and Editor Startup Map = `P0Check`; `Config/DefaultEngine.ini` now has `GameDefaultMap=/Game/Maps/P0Check.P0Check`). Findings after the editor session, checked before repackaging:

- The editor changed `EngineAssociation` of `LightSequenceBP.uproject` from `"5.6"` to `{8BBBC3F2-4585-AC67-39DB-EBB1288119CE}`; `HKCU\Software\Epic Games\Unreal Engine\Builds` maps it to `C:/Program Files/Epic Games/UE_5.6` (DEV engine). Decision of the user: accept both values; the scripts now accept a GUID only if it resolves to the DEV engine (`Test-DevEngineAssociation`; self-test: `5.6` True, DEV GUID True, TARGET GUID False, unknown GUID False). `.uproject` not edited.
- Engine snapshot against the last one (14:17): 3 entries, all in `Engine\Programs\LiveCodingConsole\Saved\` (`Logs\LiveCodingConsole.log` changed, `Logs\LiveCodingConsole-backup-2026.11.17-17.10.55.log` added, `Config\CrashReportClient\UECC-Windows-...\CrashReportClient.ini` added), written by LiveCodingConsole during the editor session. Decision of the user: allowed as a third I-2 item (`.log` / `.ini` in that folder). Registry: identical to the session baseline (0 differences).

Step 12: `tools/package_bp_project.ps1 -Configuration Development -GameExecCmds quit` (new parameter; with `quit` only, the log line can come only from the Level Blueprint). Run `package_bp_Development_20261118_193906`, 1 min 33 s: `BUILD SUCCESSFUL` (targets up to date, `Build command time: 6.80 s`), cook `Success - 0 error(s), 0 warning(s)`, packaged exe exit code 0. Packaged log (`packaged_game.log`):

```
LogPluginManager: Mounting Project plugin LightSequence
LogInit: Build Configuration: Development
[2026.11.18-18.40.02:102][  0]LogLightSequence: LightSequence module started, plugin version 0.1.0
[2026.11.18-18.40.02:131][  0]LogLoad: LoadMap: /Game/Maps/P0Check?Name=Player
[2026.11.18-18.40.02:140][  0]LogLightSequence: GetPluginVersion called: 0.1.0
[2026.11.18-18.40.02:140][  0]LogBlueprintUserMessages: [P0Check_C_1] 0.1.0
[2026.11.18-18.40.02:140][  0]LogLoad: Took 0.009241 seconds to LoadMap(/Game/Maps/P0Check)
[2026.11.18-18.40.03:148][  1]LogLightSequence: LightSequence module shut down
```

`LogBlueprintUserMessages: [P0Check_C_1]` is the Print String of the Level Blueprint of `P0Check`. Engine diff of this run: 1 entry (the `StagedBuild_LightSequenceBP.ini` marker), allowed; registry unchanged.

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
| ~19:2x | **user**: editor session in `.uedev/LightSequenceBP` (manual step) | `.uedev/LightSequenceBP` (map, config, `.uproject` association) | 3 (LiveCodingConsole `Saved`), allowed afterwards by the user |
| 19:3x | read-only engine snapshot | `.uedev/_logs/p0_after_manual` | - |
| 19:39:06 | `package_bp_project.ps1 -Configuration Development -GameExecCmds quit` (step 12) | `.uedev/LightSequenceBP`, `.uedev/_out/LightSequenceBP_Development`, `_logs`, `%TEMP%\UAT` | 1 (marker, allowed) |

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

- Shipping: that the plugin function runs (no log, no console commands in Shipping); only start + 20 s run.
- The TARGET engine as a whole (only `Engine\Binaries\Win64`, `Engine\Saved\UnrealBuildTool` and the compiler pin hash were checked; last check after the 19:39 run: 0 files modified since 09:20, pin hash `D383CD2A...` unchanged; `Scene_A1` 0, `C:\UE_Backups` 0).

## Questions and the user's answers (2026-11-18)

1. Manual Level Blueprint step: done by the user; verified (see above).
2. `C:\ProgramData\Epic`: **allowed** for the next tasks, only UE service files (Zen state, crash-reporter marker), on the same terms as `%LOCALAPPDATA%` / `%APPDATA%`. Recorded in `CLAUDE.md` section 0a and `docs/ENVIRONMENT.md`.
3. `DMXProtocol` and `DMXEngine` in `.uedev/LightSequenceBP`: **keep**.
4. P7 notes (`StagedBuild_Scene_A1.ini` in the TARGET engine, editor DLL rebuilt in `Scene_A1\Plugins\LightSequence\Binaries`): **accepted**; already in `docs/BACKLOG.md` (R2, R5); to be covered in P7b.
5. (new) `EngineAssociation` GUID written by the editor: accept `"5.6"` and the DEV GUID (resolved via the registry, read-only).
6. (new) LiveCodingConsole files in the DEV engine: allowed as the third I-2 item.

No open questions remain for P0.
