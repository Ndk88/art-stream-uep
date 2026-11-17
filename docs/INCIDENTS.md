# Incidents

## I-1. TARGET engine partly rebuilt during the first P0 attempt (2026-11-17)

**Status: OPEN** (recovery of the engine files is decided and done by the user).

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
