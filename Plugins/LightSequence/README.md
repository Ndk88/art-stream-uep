# LightSequence plugin (v0.1.0)

Plays baked LED light sequences (`.plsq` files) on 3D models of LED-chip installations in real time (Unreal Engine 5.6, Win64). The `.plsq` format is described in `spec/PLSQ_SPEC.md` of the repository `art-stream-uep`.

**Status (P0):** scaffolding only. The plugin loads, logs under the category `LogLightSequence` and offers one Blueprint function and one console command. Playback is added in later tasks (P1..P6).

## What is in v0.1.0

| Item | Where | What it does |
|---|---|---|
| `Get Plugin Version` | Blueprint, category **LightSequence** (`ULightSequenceLibrary::GetPluginVersion`, pure) | Returns `VersionName` of the plugin (`"0.1.0"`) and writes `LogLightSequence: GetPluginVersion called: 0.1.0` to the log |
| `LightSequence.PrintVersion` | Console command | Calls the same function. Works in the editor and in Development / DebugGame builds; Shipping builds have no console commands from the command line (`-ExecCmds` is compiled out of Shipping) |
| Log lines | `LogLightSequence` | `LightSequence module started, plugin version 0.1.0` on load, `LightSequence module shut down` on exit |

## Installing the packaged plugin into a Blueprint-only project

1. Copy the packaged plugin folder (`LightSequence/` with `LightSequence.uplugin`, `Binaries/`, `Intermediate/`, `Source/`) to `<Project>/Plugins/LightSequence/`.
2. Enable it in the project (Edit > Plugins > search "LightSequence" > Enabled, or add `{ "Name": "LightSequence", "Enabled": true }` to the `.uproject`).
3. Open the project with the same engine build that compiled the plugin (binaries are tied to the engine build).

**Packaging note (measured in P0 on stock UE 5.6.1).** A plugin inside the project's `Plugins/` folder alone does **not** make Unreal's packaging compile C++: the plugin counts as "enabled by default" for project plugins, so `RunUAT BuildCookRun` uses the engine's precompiled game exe and the packaged game then fails with `Plugin 'LightSequence' failed to load because module 'LightSequence' could not be found`. Packaging compiles a temporary C++ game target (and includes the plugin) only when the project's set of code plugins differs from the default one, for example because the project enables engine code plugins such as `DMXProtocol` / `DMXEngine` / `PixelStreaming2` (the host project does). A temporary target lives in `<Project>/Intermediate/Source/`; the project stays Blueprint-only (no `Source/` folder). During such a packaging run UnrealBuildTool also rebuilds the plugin's editor DLL in `<Project>/Plugins/LightSequence/Binaries/Win64/` from the plugin's `Source/`.

## Manual editor steps

### P0 check: call the plugin from a Level Blueprint (test project `.uedev/LightSequenceBP`, DEV engine)

Open the project only with the stock **UE 5.6 from the Epic Games Launcher** (never with the NvRTX engine).

1. Double-click `.uedev/LightSequenceBP/LightSequenceBP.uproject` (or Epic Games Launcher > Unreal Engine > Library > 5.6 > Launch, then Browse to the file). If a dialog asks to rebuild modules, answer **No** and report it.
2. File > **New Level** > **Basic** > Create.
3. File > **Save Current Level As** > folder `Content/Maps` (create it) > name `P0Check` > Save.
4. Toolbar: the **Blueprint** button (icon with a script page) > **Open Level Blueprint**.
5. In the Event Graph there is `Event BeginPlay` (if not: right-click > type `BeginPlay` > select **Event BeginPlay**).
6. Drag from the white execution pin of `Event BeginPlay` > type `Print String` > select **Print String**.
7. Right-click on an empty spot > type `Get Plugin Version` > select **Get Plugin Version** (category LightSequence).
8. Connect the pink **Return Value** of `Get Plugin Version` to the **In String** pin of `Print String`.
9. **Compile** (toolbar), then **Save** (toolbar), close the Blueprint editor.
10. Edit > **Project Settings** > Project > **Maps & Modes**: set **Editor Startup Map** and **Game Default Map** to `P0Check`.
11. Press **Play** (Alt+P). Expected: `0.1.0` in the top-left corner of the viewport; Window > Output Log shows `LogLightSequence: GetPluginVersion called: 0.1.0`. Stop the game (Esc).
12. File > Save All, close the editor. Tell Claude Code; it packages the project again with `tools/package_bp_project.ps1` and checks the packaged log for the same line (now written at BeginPlay, without the console command).

### Later tasks (copied from `docs/TASKS_UE_PLUGIN.md`, valid once the features exist)

1. **Material for fake lights.** `PerInstanceCustomData[0]` = chip index `i`. With texture width `W`, height `H`: `u = (fmod(i, W) + 0.5) / W`, `v = (floor(i / W) + 0.5) / H`. Sample the chip texture at mip 0 (Nearest), RGB to Emissive (alpha is the white channel; combine as needed). Texture parameter set from `GetChipTexture()`. Emissive lights the surroundings only through Lumen.
2. **Blueprint wiring.** Add `ULightSequencePlayer` to the model actor; build the light array / ISM instances **in DataTable row order** at BeginPlay (do not use `Get Components By Class` order, do not reuse cached references from the editor); call `SetChipLights` or `AssignChipIndices` + texture; call `OpenFile` with a path from `ListSequences`; on `OnLoaded` send `GetSequenceInfoAsJson` over Pixel Streaming; call `Play`.
3. **Chip order.** The designer patches the sequence in Madrix/TouchDesigner in the same CHIP_ID order as the DataTable rows (U4).

## Building (developers)

See `docs/ENVIRONMENT.md` and `CLAUDE.md` section 0a of the repository. Short form (DEV engine only):

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_plugin.ps1        # package -> .uedev\_out\LightSequence
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_tests.ps1           # automation tests "LightSequence."
powershell -NoProfile -ExecutionPolicy Bypass -File tools\package_bp_project.ps1 -Configuration Development
```
