# CLAUDE.md

Project context for Claude Code. Read this file first, then `spec/PLSQ_SPEC.md`, then `docs/ARCHITECTURE.md`, then the task file `docs/TASKS_UE_PLUGIN.md` (work only on the task you were asked to do).

## 0. Current version and branch

- Working branch: `dev/v0.1.0`
- Plugin version: `VersionName` in `Plugins/LightSequence/LightSequence.uplugin` must be `0.1.0` (once the file exists, task P0).
- Last release: none yet. `master` holds only the initial import (spec copy, docs).
- Before any work run `git branch --show-current`. If it is not the working branch above, stop and ask the user.

## 0a. SAFETY: two engines, protected locations (read before every command)

This section has priority over everything else in this repository, including the task file.

**Incident of 2026-11-17** (`docs/INCIDENTS.md`): building the editor target of a test project against the user's source-built NvRTX engine made UnrealBuildTool start rebuilding the engine itself; 8 engine DLLs were relinked before the build was stopped. The user's engine must stay untouched. The rules below exist so that this never happens again.

**Two engines (decision U10):**

| Role | Engine | Use |
|---|---|---|
| **DEV engine** | Stock **UE 5.6 from the Epic Games Launcher** (an installed build; path recorded in `docs/ENVIRONMENT.md` in P0; the user installs it, you never do) | **All** development, building, testing and packaging in P0..P6 and P8. |
| **TARGET engine** | User's source build **UE 5.6.1 NvRTX Caustics**, `D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6`, GUID `{CB5F2325-467F-DCDB-830C-16B1F05EDBE4}` | **Read-only reference.** Used only in P7, step by step, with the user's approval of each step. |

The plugin code uses only standard engine modules (Core, CoreUObject, Engine, RenderCore, RHI, Json...) and nothing specific to NvRTX, so it is developed on the stock engine. Compiled plugin binaries are tied to the engine build that compiled them (BuildId); the binaries for the TARGET engine are produced only in P7.

**Protected locations (READ-ONLY, no exceptions without the user's explicit approval in the current session):**

1. `D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6\` and everything inside it (TARGET engine).
2. `D:\PRECIOSA\PixelStreaming_Project_1\_ue_\Scene_A1\` and everything inside it (host project, Blueprint-only, must stay Blueprint-only).
3. The DEV engine installation folder (never modify an installed engine).
4. Anything outside this repository, except the temp folder and the packaging output folder named in `docs/ENVIRONMENT.md`.

Reading these locations (source, logs, config) is allowed.

**Before running any command that can write files** (UnrealBuildTool, `Build.bat`, `RunUAT` / `BuildPlugin` / `BuildCookRun`, `GenerateProjectFiles`, MSBuild, the editor, installers, scripts that copy or delete):

- Check which engine it uses: the full path of the tool **and** the `EngineAssociation` of every `.uproject` involved. Until P7 it must be the DEV engine. If a project is associated with the TARGET engine GUID, stop.
- State in one line what the command writes and where. If anything could be written into a protected location, **do not run it: stop and ask the user.**
- While a build runs, watch its output. If UBT starts compiling or linking engine modules, or any path of a protected location appears in its actions, **stop the build immediately** and report.
- Never terminate processes or delete files outside this repository without the user's approval.

**Never** copy NvRTX-specific settings (for example the extra warning flags `/wd4458 /wd4723` found in its `UnrealEditor.Target.cs`) into projects that use the DEV engine.

## 1. What this project is

Light installations are built from thousands of RGBW LED "chips". A designer animates them in Madrix 5 or TouchDesigner, which sends the animation over the network as Art-Net (DMX). Before the real installation is built, the client sees it as a 3D model in Unreal Engine 5.6, streamed to a browser with Pixel Streaming.

Two programs work together:

1. **Recorder** (separate repository `Ndk88/art-stream-rec`, Python, release v1.2.1). It listens to the Art-Net stream, takes 30 or 60 snapshots per second (frames: RGBW bytes of every chip) and saves them to a binary `.plsq` file. **Not part of this repository; do not change it.**
2. **UE plugin** (this repository, C++, UE 5.6, Win64). It reads `.plsq` files at runtime, plays them in real time and colors the chips of the model.

The host UE project (`Scene_A1`) is **Blueprint-only and must stay so**; its packaged exe runs on a remote server (Pixel Streaming).

Engines: the host project runs on the user's **source build of UE 5.6.1, NVIDIA fork NvRTX Caustics** (TARGET engine, read-only). Development uses the **stock UE 5.6 from the Epic Games Launcher** (DEV engine). See section 0a. Details: `docs/CURRENT_PC_ENV.md` (user's survey) and `docs/ENVIRONMENT.md` (verified in P0).

The plugin is built separately (`RunUAT BuildPlugin`) and delivered with binaries. The host project already has a Remote-Signal mode (live Art-Net through the engine's DMX plugin, in Blueprint) and a selectable light type per chip (point / spot / rect light components or "fake light" ISM spheres with an emissive material). The plugin adds the **Pre Installed** mode for `.plsq` files: playback from a file. Small sequences recorded as JSON are already played by an existing, tested Blueprint parser in the host project, which stays unchanged (U1).

A plain-language description of the whole pipeline is in `docs/ARCHITECTURE.md`.

## 2. Locked decisions

Do not change these without asking the user. D-numbers are shared with the recorder repository; U-numbers belong to this plugin.

| # | Decision |
|---|---|
| D1 | Always 4 channels per chip: RGBW, in DMX order as received (R, G, B, W). No other layouts. |
| D2 | Format: PLSQ v1 as defined in `spec/PLSQ_SPEC.md` (a read-only copy, see `spec/SPEC_SOURCE.md`). Compression is reserved, not implemented. |
| D4 | Design range: 1 universe (up to 128 chips) to **64,000 chips**. Every design choice is checked against the top of the range. The 104-chip test stand is inside it. |
| D6 | The plugin streams `.plsq` in chunks. It **never loads the whole payload** into memory and never does file I/O on the game thread. (A file whose chunks all fit into the read-ahead ring may stay resident; that is still chunked streaming.) |
| D7 | Outputs: (a) "fake light": instanced static meshes with an emissive material that reads a runtime texture; (b) real lights: **one light component per chip** (Point / Spot / Rect). **No clusters.** |
| D8 | Every meta field of the file (everything except the frame bytes) is readable from Blueprint as a struct and as one JSON string (forwarded over Pixel Streaming to a React frontend). Unknown keys are passed through. |
| D10 | Playback is time-based: frame = floor(time x fps). Normalization: byte / 255 is a **linear** value (as Make Linear Color in the existing pipeline). |
| U1 | The plugin reads **`.plsq` only**. The recorder also writes JSON sequences (only for layouts of 1 or 2 universes, recorder decision D3). The host UE project **already has a Blueprint JSON parser for them; it is implemented, tested successfully (including files with the optional keys `short_packets` / `first_frame_partial`, recorder manual check M3) and stays as is.** The plugin does not read, replace, wrap or change the JSON pipeline, and no task touches it. All plugin work is about the `.plsq` format. |
| U2 | **Real-time playback only** (Pixel Streaming). No Movie Render Queue, no offline render, no editor preview without PIE (`bTickInEditor`). `SetExternalTime(t)` and `bBlockOnUnderrun` exist as cheap primitives for the future; they are **not tested and not tuned** for offline rendering. |
| U3 | Chip count mismatch (file `chips_count` vs model chip count): by default **refuse** with `ChipCountMismatch`, playback does not start, message in the log and in the info JSON. Property `bAllowChipCountMismatch` (default false): when true, play `min(N_file, N_model)` chips, set the extra model chips to black, store the mismatch in `FLightSequenceInfo` and the JSON. `model_chips_tag` is compared separately: **warning only**. |
| U4 | **Chip order is external to the plugin.** Chip `i` of the file = element `i` of the array (lights) or instance `i` (ISM) that Blueprint passes in = row `i` of the designer's DataTable (Row Name = CHIP_ID, spawn order = row order). The plugin never sorts, never uses `GetComponentsByClass`, never guesses an order and does not validate CHIP_IDs. An explicit CHIP_ID -> file index mapping is a possible future feature (risk R1), not implemented. |
| U5 | Sequences folder: default `FPaths::ProjectDir()/DmxChipsManagerPlsqFiles/` (editor and packaged; the same convention as the host project's existing JSON parser: Get Project Directory + a fixed folder name). In the host project this is `Scene_A1/DmxChipsManagerPlsqFiles/`; in a packaged build it is expected at `<exe folder>/<ProjectName>/DmxChipsManagerPlsqFiles/` (verify in P6). Overrides: command line `-LightSequencesDir=<path>`, then the component property (if not empty), then `[LightSequence] SequencesDir=` in the project `.ini`, then the default (first match wins). The resolved path is logged at start and is readable from Blueprint. Never rely on `Saved/`. |
| U6 | Universes are **not used for playback**: the payload is a flat array of RGBW bytes per chip in chip order, a frame is an offset. The port of the recorder's universe count (`count_universes`) is used only for header validation (`InconsistentHeader`) and the info API, never in the frame read path. |
| U7 | Outputs do not know where a frame comes from: they receive "a frame of RGBW bytes" through one interface (`IChipFrameSink`). Today the only source is the file player; a C++ live Art-Net source may be added later (out of scope now). |
| U8 | Packaging a Blueprint-only project that uses a code plugin: checked in P0 **on the DEV engine** (does packaging compile C++, does the packaged exe load the plugin). For the TARGET engine it is checked again in P7. Known fact: the host project `Scene_A1` already compiles a temporary C++ game target when it is packaged (its `Intermediate/Source/Scene_A1.Target.cs`, because it enables code plugins such as DMX, PixelStreaming2, DLSS). The packaged exe runs on a remote server where only the packaged build is installed. |
| U9 | Test projects live in `.uedev/` inside this repository and are **git-ignored**: `.uedev/LightSequenceDev/` (C++ project: the plugin is developed, compiled and auto-tested here; it references `Plugins/LightSequence/` of this repository through `AdditionalPluginDirectories` or a junction, record which) and `.uedev/LightSequenceBP/` (Blueprint-only, no `Source/`, a miniature of the host project: only the **packaged** plugin binaries are copied into its `Plugins/`; proves that the plugin works in a Blueprint-only project and in its packaged exe). Both use the **DEV engine** (U10) until P7. |
| U10 | **Two engines.** Development on the stock launcher UE 5.6 (DEV engine); the user's NvRTX source build (TARGET engine) is read-only and used only in P7, with the user's approval of each step. See section 0a. |

## 3. Scale reference (RGBW, 4 bytes per chip)

| Chips | Universes (128/universe) | Bytes per frame | MB/s at 60 fps | 1 hour at 60 fps |
|---|---|---|---|---|
| 104 (test stand) | 1 | 416 | 0.02 | 90 MB |
| 1,680 (real TD test) | 14 | 6,720 | 0.40 | 1.5 GB |
| 10,000 | 79 | 40,000 | 2.4 | 8.6 GB |
| 64,000 | 500 | 256,000 | 15.4 | 55 GB |

Use `uint64` / `int64` for every file offset and size.

## 4. Out of scope (do not implement unless the user asks)

- Light clusters / proxies (D7).
- Reading JSON sequences, or any change to the existing Blueprint JSON parser of the host project (U1).
- Live Art-Net / DMX input in C++ (U7: only keep the interface open).
- Movie Render Queue, offline rendering, editor preview without PIE (U2).
- CHIP_ID mapping, sorting of lights, DataTable validation (U4).
- Interpolation between frames; PLSQ compression; any change to the `.plsq` format.
- Changes to the recorder repository (requests for it go to the user, see task X1).

## 5. Facts about real sources (from recorder manual check M2, for information)

Recording from TouchDesigner, 1,680 chips, 14 universes: no ArtSync is sent; every universe is sent in every frame; Art-Net sequence numbers are independent per universe; the source sends about 60 sets per second when set to 30 fps. This matters for a future live source (U7), not for file playback.

## 6. Working agreements

- **Verify every engine API against the UE 5.6 source or documentation before using it.** Names in the task file are intentions, not guarantees. If an API is deprecated or differs in 5.6, say so in the report and use the supported alternative.
- You cannot create or edit Blueprint, material or DataTable assets. Steps that need the editor are written for the user ("Manual editor steps" in the task file and in `Plugins/LightSequence/README.md`).
- If a requirement is ambiguous or conflicts with the spec, ask the user. Never edit `spec/`.
- Never touch the user's production UE project `D:\PRECIOSA\PixelStreaming_Project_1\_ue_\Scene_A1` (Blueprint-only, **must stay Blueprint-only: never add a `Source/` folder or C++ code to it**). The plugin is installed there only at the end (P7), by the user or on the user's explicit command.
- Development uses two test projects inside the git-ignored folder `.uedev/` of this repository (U9). Do not create test projects anywhere else.
- Windows 11 / Win64 only. Paths may contain spaces and Cyrillic characters; test with them.
- C++: Epic coding standard (`F`/`U`/`A`/`E`/`I` prefixes, `bBool`, tabs as in engine code). No per-frame heap allocations in the playback path. No exceptions; errors go through the error path and `OnError`, never a crash or `check()` on bad input files.
- Logging: category `LogLightSequence`. Code, comments, log text and docs in English. Replies to the user in Russian.
- Tests: UE automation tests (`IMPLEMENT_SIMPLE_AUTOMATION_TEST` or the spec-style framework) under the filter `LightSequence.`, runnable headless, for example:
  `UnrealEditor-Cmd.exe "<TestProject>.uproject" -ExecCmds="Automation RunTests LightSequence; Quit" -unattended -nullrhi -nop4 -log`
  Run them before finishing a task. Heavy load tests are separate (P8) and not part of the quick suite.
- Large generated files (synthetic sequences of hundreds of MB) are never committed. They are generated into a git-ignored folder (`test_data/generated/`).
- Never delete user data silently (sequences, test files, `.part` files).
- Update `Plugins/LightSequence/README.md` for every user-visible change.
- **Report** at the end of each task in `docs/reports/REPORT_<TaskId>.md`: what changed, how it was verified (commands and their output, measured numbers), what could not be verified, open questions. Every number in a report comes from a command run in this task; anything else is marked "not measured".

## 7. Repository layout

```
CLAUDE.md                     this file
README.md                     short overview for humans
spec/                         READ-ONLY copy of the format (see spec/SPEC_SOURCE.md)
  PLSQ_SPEC.md
  SPEC_SOURCE.md
  golden/conformance_v1.plsq
  golden/errors/              filled later from the recorder repo (task X1)
docs/
  ARCHITECTURE.md             approved architecture, plain-language pipeline
  TASKS_UE_PLUGIN.md          task list P0..P8 (+ X1 external)
  BACKLOG.md                  risks and deferred items
  ENVIRONMENT.md              created in P0 (both engines, toolchain, paths)
  CURRENT_PC_ENV.md           the user's own survey of the PC (input for P0)
  INCIDENTS.md                incidents and their status
  reports/                    REPORT_<TaskId>.md
test_data/                    real recordings copied by the user (see test_data/README.md)
  generated/                  git-ignored, synthetic files
tools/                        small helper scripts (Python stdlib or PowerShell)
.uedev/                       git-ignored test projects (U9)
  LightSequenceDev/           C++ development project
  LightSequenceBP/            Blueprint-only check project
Plugins/LightSequence/        created in P0
  LightSequence.uplugin
  Source/LightSequence/...
  README.md                   user-facing plugin docs incl. manual editor steps
```

## 8. Git workflow

- `master`: releases only, tagged `vX.Y.Z` (annotated). Never commit to it.
- One working branch at a time: `dev/vX.Y.Z` from `master` (section 0). The branch version equals `VersionName` in the `.uplugin`. If a different version is needed, tell the user instead of continuing under a mismatched name.
- One commit per task (or per fix inside a task). The message starts with the task id ("P1: ..."), English, imperative. Code, tests, README and the report of one change go into the same commit.
- Never rewrite history: no rebase, no amend of pushed commits, no force push.
- **Do not, without an explicit request in the current session:** push, merge, tag, create / rename / delete branches, open pull requests.
- At the end of a session everything is committed on the working branch. The final message gives the branch, the last commit hash and states that nothing was pushed.
- Never commit `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, packaged builds or generated test files (see `.gitignore`).

Release (done by the user, for information): `git checkout master && git merge --ff-only dev/vX.Y.Z`, `git tag -a vX.Y.Z -m "Release X.Y.Z"`, `git push origin master vX.Y.Z`, then a new `dev/vA.B.C` and an update of section 0.

## 9. Definition of done (every task)

- The acceptance criteria of the task are met and demonstrated (test output or measurement).
- The automation suite `LightSequence.` passes.
- Existing behavior that the task does not intentionally change still works.
- Plugin README and docs are updated; the report is written (section 6).
- Work is committed on the working branch (section 8).
