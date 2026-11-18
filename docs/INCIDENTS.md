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
