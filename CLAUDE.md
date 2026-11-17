# CLAUDE.md

Project context for Claude Code. Read this file first, then `spec/PLSQ_SPEC.md`, then `docs/ARCHITECTURE.md`, then the task file `docs/TASKS_UE_PLUGIN.md` (work only on the task you were asked to do).

## 0. Current version and branch

- Working branch: `dev/v0.1.0`
- Plugin version: `VersionName` in `Plugins/LightSequence/LightSequence.uplugin` must be `0.1.0` (once the file exists, task P0).
- Last release: none yet. `master` holds only the initial import (spec copy, docs).
- Before any work run `git branch --show-current`. If it is not the working branch above, stop and ask the user.

## 1. What this project is

Light installations are built from thousands of RGBW LED "chips". A designer animates them in Madrix 5 or TouchDesigner, which sends the animation over the network as Art-Net (DMX). Before the real installation is built, the client sees it as a 3D model in Unreal Engine 5.6, streamed to a browser with Pixel Streaming.

Two programs work together:

1. **Recorder** (separate repository `Ndk88/art-stream-rec`, Python, release v1.2.1). It listens to the Art-Net stream, takes 30 or 60 snapshots per second (frames: RGBW bytes of every chip) and saves them to a binary `.plsq` file. **Not part of this repository; do not change it.**
2. **UE plugin** (this repository, C++, UE 5.6, Win64). It reads `.plsq` files at runtime, plays them in real time and colors the chips of the model.

The host UE project is **Blueprint-only**. The plugin is built separately (`RunUAT BuildPlugin`) and delivered with binaries. The host project already has a Remote-Signal mode (live Art-Net through the engine's DMX plugin, in Blueprint) and a selectable light type per chip (point / spot / rect light components or "fake light" ISM spheres with an emissive material). The plugin adds the **Pre Installed** mode: playback from a file.

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
| U1 | The plugin reads `.plsq` only. JSON sequences stay with the existing Blueprint pipeline. |
| U2 | **Real-time playback only** (Pixel Streaming). No Movie Render Queue, no offline render, no editor preview without PIE (`bTickInEditor`). `SetExternalTime(t)` and `bBlockOnUnderrun` exist as cheap primitives for the future; they are **not tested and not tuned** for offline rendering. |
| U3 | Chip count mismatch (file `chips_count` vs model chip count): by default **refuse** with `ChipCountMismatch`, playback does not start, message in the log and in the info JSON. Property `bAllowChipCountMismatch` (default false): when true, play `min(N_file, N_model)` chips, set the extra model chips to black, store the mismatch in `FLightSequenceInfo` and the JSON. `model_chips_tag` is compared separately: **warning only**. |
| U4 | **Chip order is external to the plugin.** Chip `i` of the file = element `i` of the array (lights) or instance `i` (ISM) that Blueprint passes in = row `i` of the designer's DataTable (Row Name = CHIP_ID, spawn order = row order). The plugin never sorts, never uses `GetComponentsByClass`, never guesses an order and does not validate CHIP_IDs. An explicit CHIP_ID -> file index mapping is a possible future feature (risk R1), not implemented. |
| U5 | Sequences folder: default `FPaths::ProjectDir()/LightSequences/` (editor and packaged). Overrides: command line `-LightSequencesDir=<path>`, then the component property (if not empty), then `[LightSequence] SequencesDir=` in the project `.ini`, then the default (first match wins). The resolved path is logged at start and is readable from Blueprint. Never rely on `Saved/`. |
| U6 | Universes are **not used for playback**: the payload is a flat array of RGBW bytes per chip in chip order, a frame is an offset. The port of the recorder's universe count (`count_universes`) is used only for header validation (`InconsistentHeader`) and the info API, never in the frame read path. |
| U7 | Outputs do not know where a frame comes from: they receive "a frame of RGBW bytes" through one interface (`IChipFrameSink`). Today the only source is the file player; a C++ live Art-Net source may be added later (out of scope now). |
| U8 | "A Blueprint-only host project needs no C++ toolchain" is an **unverified hypothesis**. It is checked first, in P0, before any logic is written. |

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
- Reading JSON sequences (U1).
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
- Never touch the user's production UE project. Development uses a separate test project (found or created in P0 and recorded in `docs/ENVIRONMENT.md`).
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
  ENVIRONMENT.md              created in P0 (engine, toolchain, paths)
  reports/                    REPORT_<TaskId>.md
test_data/                    real recordings copied by the user (see test_data/README.md)
  generated/                  git-ignored, synthetic files
tools/                        small helper scripts (Python stdlib or PowerShell)
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
