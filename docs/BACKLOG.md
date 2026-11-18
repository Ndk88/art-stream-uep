# Backlog and risks

Items that are known but not scheduled. Nothing here is implemented without the user's request.

## Risks

**R1. Chip order mismatch (U4).** The plugin assumes chip `i` of the file = row `i` of the designer's DataTable. If Madrix/TouchDesigner is patched in a different order than the DataTable, the light will look scrambled. Detection: visual. Possible remedy (future feature): an explicit CHIP_ID -> file index mapping (for example a DataTable column with the file index), applied once when outputs are bound.

**R2. Packaging of a Blueprint-only host project (U8).** A code plugin may force a C++ build at packaging time. Checked in P0 on the DEV engine and in P7 on the TARGET engine; the consequence is decided by the user. P0 result (DEV engine, `docs/reports/REPORT_P0.md`): the LightSequence project plugin **alone does not** trigger the temporary C++ target (project plugins without `EnabledByDefault` count as default plugins), and the packaged game then fails to load the plugin; with an engine code plugin enabled (as in `Scene_A1`: DMX, PixelStreaming2...) packaging compiles a temporary game target that includes the plugin, and the packaged exe loads it. If the host project ever stops enabling such plugins, the plugin would silently not load in the packaged build. Also: packaging rebuilds the plugin's editor DLL inside the project's `Plugins/LightSequence/Binaries` (relevant for the P7 plan).

**R5. The TARGET engine folder gets a file on every packaging.** `RunUAT BuildCookRun -stage` always writes an empty `Engine\Intermediate\Build\BuildCookRun\StagedBuild_<Project>.ini` into the engine folder (hard-coded in UE 5.6 `CopyBuildToStagingDirectory.Automation.cs`). The user's own packaging of `Scene_A1` already does this on the TARGET engine; the P7 plan must state it.

**R4. Building for the TARGET engine (NvRTX source build).** On 2026-11-17 a build against it started rebuilding the engine (`docs/INCIDENTS.md`). The plugin is developed on the stock launcher engine (U10); the TARGET build is planned read-only in P7b and run only after the user approves the plan. The TARGET engine was rebuilt on 2026-11-18 with a pinned compiler (MSVC 14.38.33130 / SDK 10.0.22621.0), which removes the most likely cause.

**R3. 64,000 real light components (D7).** CPU cost of color updates is measured in P8; GPU cost of so many dynamic lights may be the real limit regardless of the plugin. No clusters (out of scope). MegaLights status in 5.6 is a note in the P8 report only.

## Deferred features

**F1. Live Art-Net source in C++ (U7).** At 64,000 chips the Blueprint Remote-Signal path (one event per fixture patch) is likely too slow. The outputs already take frames through `IChipFrameSink`, so a C++ source reading the engine's DMX input ports could feed the same texture / lights. Facts from the recorder's M2 check: no ArtSync from TouchDesigner, all universes every frame, independent sequence numbers per universe, about 60 sets/s at a 30 fps setting.

**F2. Offline render / Movie Render Queue (U2).** Not needed now. Primitives `SetExternalTime` and `bBlockOnUnderrun` exist but are untested.

**F3. CHIP_ID mapping** (see R1).

## External (recorder repository)

**X1. `tools/make_error_vectors.py`** in `art-stream-rec`: error vectors, frame-stamp files, `expected.json` (see `docs/TASKS_UE_PLUGIN.md`). The branch in the recorder repository is the user's decision (`dev/v1.2.1` is frozen, `dev/v1.3.0` is paused; for example a new `dev/v1.2.2` from `master`).
