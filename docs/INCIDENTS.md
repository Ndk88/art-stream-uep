# Incidents

## I-1. TARGET engine partly rebuilt during the first P0 attempt (2026-11-17)

**Status: CLOSED (2026-11-18).** The affected engine was replaced: the user rebuilt NvRTX Caustics 5.6 from scratch in a new folder and deleted the old one. See "Resolution" at the end.

**What happened.** In the first P0 session Claude Code built the editor target of the test project `.uedev/LightSequenceDev` (associated with the user's source-built engine UE 5.6.1 NvRTX Caustics, `D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6`) with `Build.bat LightSequenceDevEditor Win64 Development`. UnrealBuildTool considered the engine's shared editor binaries out of date and started rebuilding the engine itself (3,253 actions, MSVC 14.38.33130). Claude Code noticed it at about action 200 and stopped the build.

**What changed in the engine** (as reported by Claude Code; the exact list is to be confirmed by a read-only listing of files modified on 2026-11-17):
- 8 DLLs in `Engine/Binaries/Win64` relinked, with their `.pdb`: `UnrealEditor-ApplicationCore`, `-DesktopPlatform`, `-DeveloperSettings`, `-InputCore`, `-Json`, `-Projects`, `-ToolMenus`, `-TraceLog`;
- about 591 files in `Engine/Intermediate/.../UnrealEditor/Development`.

No engine source file was changed. The host project `Scene_A1` was only read. No backup of the old DLLs was made.

**Cause (process).** The documentation required building with the user's engine and did not mark the engine as a protected, read-only location; there was no rule to check, before a build, whether it can write into the engine. The technical reason why UBT considered the engine out of date is not established yet (candidates: a newer MSVC toolset than the one used for the original build in 2025-12; partial rebuilds in 2026-07).

**Measures taken.**
- `CLAUDE.md` section 0a: two engines (U10); the NvRTX engine and `Scene_A1` are read-only; checks before every command that can write; stop a build at once if it touches engine modules.
- Development moved to the stock launcher UE 5.6 (DEV engine) for P0..P6 and P8.
- `docs/TASKS_UE_PLUGIN.md`: P0 uses only the DEV engine; P7 split into a read-only build plan for the NvRTX engine (P7b) that the user approves before any build.

**Recovery options (user).**
1. Restore the changed files from a copy made before 2026-11-17 (original engine archive or copy, Windows "Previous versions" of `Engine\Binaries\Win64`, a disk backup).
2. If no copy exists: decide later whether to rebuild the engine fully from the same sources (functionally the same, but new files). Not done by Claude Code without an explicit decision.

Until recovery: if the TARGET editor asks to rebuild modules when opening a project, answer **No**.

**Resolution (2026-11-17/18, done by the user step by step with Claude in chat).**
- Old engine `D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6` (GUID `{CB5F2325-...}`): **deleted** by the user.
- New TARGET engine: `D:\NVRTXCAUSTICS\5_6`, `git clone` of `NvRTX/UnrealEngine` branch `NvRTX_Caustics-5.6`, commit `89f34311628dbee093d99497cb74a3570164c10d` (2026-08-21), UE 5.6.1, GUID `{394CF319-4D3A-7BC1-DA7B-CC849351994F}`.
- Compiler pinned **before** the first build in the engine-local `Engine\Saved\UnrealBuildTool\BuildConfiguration.xml`: MSVC 14.38.33130 (toolset 14.38.33145), Windows SDK 10.0.22621.0. Added VS component "C++ ATL 14.38 (x86 & x64)". Build output confirmed: `Using Visual Studio 2022 14.38.33145 toolchain ... Windows 10.0.22621.0 SDK`.
- Built: UnrealEditor Win64 Development (7,999 actions) and ShaderCompileWorker. Editor starts.
- Manual change in engine sources: `<NuGetAudit>false</NuGetAudit>` in `Engine/Source/Programs/AutomationTool/Gauntlet/Gauntlet.Automation.csproj` and `.../AutomationUtils/AutomationUtils.Automation.csproj` (NuGet audit errors NU1901-NU1903 for Magick.NET 14.10.0 blocked UAT; `RunUAT -List` succeeds after the change). Originals kept as `*.csproj.bak`.
- Binaries backup (without `.pdb`): `C:\UE_Backups\NvRTX_Caustics_5_6_binaries_2026-11-18`.
- Host project `Scene_A1`: full backup in `C:\UE_Backups\Scene_A1_before_new_engine_2026-11-18`, `.uproject` re-associated to `{394CF319-...}` (old file kept as `Scene_A1.uproject.bak_old_engine`), opened in the new editor: map `LV_Main` loads, Map Check 0 errors / 0 warnings.
- Lesson kept in `CLAUDE.md` section 0a: the TARGET engine is read-only for Claude Code; plugin development uses the DEV engine.

## I-2. DEV engine: build intermediates written into engine plugin folders during P0 (2026-11-18)

**Status: CLOSED (2026-11-18): accepted by the user as known UE behavior, with a strict rule (see "Investigation and resolution").**

**What happened.** `tools/build_plugin.ps1` ran `RunUAT BuildPlugin` of the DEV engine (`C:\Program Files\Epic Games\UE_5.6`, installed build). The build itself was correct: UBT ran 9 + 4 + 4 actions, all of them for the `LightSequence` module (toolchain MSVC 14.38.33145 / SDK 10.0.22621.0), no engine module was compiled or linked. But the before/after snapshot of the engine folder (216,541 files) found **1,074 added files, 0 changed, 0 removed**, all inside `Intermediate\Build\Win64\...` of five engine plugins:

| Count | Folder (under `Engine\Plugins\`) |
|---|---|
| 627 | `MetaHuman\MetaHumanAnimator\Intermediate` |
| 268 | `MetaHuman\MetaHumanCoreTechLib\Intermediate` |
| 117 | `MetaHuman\MetaHumanCalibrationProcessing\Intermediate` |
| 44 | `VirtualProduction\CaptureManager\CaptureManagerCore\Intermediate` |
| 18 | `VirtualProduction\CaptureData\Intermediate` |

File types: 791 `.rsp`, 184 `.cpp` (UHT `.gen.cpp`, unity `Module.*.cpp`), 36 `.h`, 36 `.json`, 27 `Timestamp`. **No `.obj`, `.lib`, `.dll`, `.pdb` or `.exe`; no existing engine file changed.** Full list: `.uedev/_logs/build_plugin_20261118_092649/engine_diff.txt` (git-ignored).

**Cause (technical, partly established).** BuildPlugin creates its own `HostProject.uproject` that enables only `LightSequence`; the editor target therefore includes every engine plugin that is enabled by default. The UBT log shows these MetaHuman/Capture modules as "Not under compatible directories" while UBT still generated their UHT output and action response files inside the engine plugin folders (they ship without pre-generated `Intermediate` data, unlike the other engine plugins). The NTFS ACL of the engine folder grants the user Full Control, so Windows did not block the writes.

**Cause (process).** The safety watch of the script looked only for compile/link actions of foreign modules and for TARGET/host paths; UHT/makefile writes into the DEV engine were not anticipated. They were detected only by the after-build snapshot.

**Not affected (checked after the build):** TARGET engine `D:\NVRTXCAUSTICS\5_6` (0 files in `Engine\Binaries\Win64` modified; its `BuildConfiguration.xml` hash unchanged), `Scene_A1` (0 files modified), `%APPDATA%\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml` (hash unchanged), `HKCU\Software\Epic Games` (identical dump).

**Measures.** Work stopped after the build; no further build was started until the user decided.

**Investigation and resolution (2026-11-18, each step approved by the user).**
1. The 1,074 added files were deleted after a per-file check (in the diff list, inside the five folders, created 09:28:14..09:28:29 during the build); a new snapshot showed 0 differences to the snapshot taken before the build (216,541 files).
2. `tools/build_plugin.ps1` was rewritten to compile with its own host project (`.uedev/_build/HostProject`) that disables the MetaHuman*/Capture* plugins. Measured: the same 1,074 files were written again (UBT log: `Ignoring plugin 'MetaHuman'`, but `Compile module: MetaHumanBatchProcessor`, i.e. the modules come from the installed editor's receipt `Engine/Binaries/Win64/UnrealEditor.target` / `bBuildAllModules`, not from the project's plugin list). No engine module was compiled or linked (actions only planned; their outputs are up to date).
3. Findings while defining the exception: 755 `.rsp` files contain the absolute path of the project being built (its shared PCH); UHT `Timestamp` files list header paths in random order; when the project path changes, UBT keeps the previous `.rsp` as `.rsp.old`; UBT also writes unity files `Module.<Name>.cpp`. Absolute paths inside the files point only to `<repo>\.uedev\`, the DEV engine, Visual Studio 2022 and Windows Kits 10.
4. The user approved a rule (recorded in `CLAUDE.md` section 0a, implemented in `tools/ue_safety.ps1`, `Test-EngineDiff`): new or changed files only inside the five folders, only types `.rsp`, `.rsp.old`, `.gen.cpp`, `Module.*.cpp`, `.h`, `.json`, `Timestamp`, no change to engine files created before 2026-11-18, no deletion, absolute paths only under the four roots above. Any other difference stops the work. The rule applies only to the DEV engine, never to the TARGET engine.
5. Packaging the Blueprint-only check project with `RunUAT BuildCookRun -stage` wrote one more file into the DEV engine: the empty marker `Engine\Intermediate\Build\BuildCookRun\StagedBuild_LightSequenceBP.ini` (hard-coded in `CopyBuildToStagingDirectory.Automation.cs`: written to `<EngineRoot>\Intermediate\Build\BuildCookRun\` and staged as `Engine/Config/StagedBuild_<Project>.ini`; the path is not configurable). The user approved it as a second tolerated item: only `StagedBuild_LightSequenceBP.ini` / `StagedBuild_LightSequenceDev.ini`, only 0 bytes. Note for P7: packaging `Scene_A1` with the TARGET engine writes the same kind of marker into the TARGET engine folder; the P7 plan must cover it.
6. During the user's manual editor session in `.uedev/LightSequenceBP` (2026-11-18 evening), LiveCodingConsole wrote 3 files into the DEV engine: `Engine\Programs\LiveCodingConsole\Saved\Logs\LiveCodingConsole.log` (changed), `...\Logs\LiveCodingConsole-backup-2026.11.17-17.10.55.log` (new), `...\Saved\Config\CrashReportClient\UECC-Windows-...\CrashReportClient.ini` (new). The user approved a third tolerated item: `.log` / `.ini` files inside `Engine\Programs\LiveCodingConsole\Saved\`.
7. The files written by the builds of 2026-11-18 stay in the DEV engine. Rollback at any time: delete the files created on/after 2026-11-18 in the five folders, or "Verify" UE 5.6 in the Epic Games Launcher.
