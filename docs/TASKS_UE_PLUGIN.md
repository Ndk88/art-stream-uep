# UE plugin tasks (C++, Unreal Engine 5.6, Win64)

Context: `CLAUDE.md` (decisions D*, U*), `spec/PLSQ_SPEC.md`, `docs/ARCHITECTURE.md`.

How to work: **one task per session** unless the user says otherwise. Each task has a goal, required changes and acceptance criteria. Stop after the task, write the report (`docs/reports/REPORT_<TaskId>.md`, see `CLAUDE.md` section 6) and wait for the user.

**Verify every engine API against the UE 5.6 source or documentation before using it.** Names and signatures below are intentions, not guarantees.

Origin: this file continues `docs/TASKS_UE_PLUGIN.md` of `art-stream-rec` (commit `badf6c8`), updated with the decisions of 2026-11-17.

## Order

`P0 -> P1 -> P2 -> P3 -> P5 -> P4 -> P6 -> P7 -> P8`

**Engines:** P0..P6 and P8 use only the DEV engine (stock launcher UE 5.6). The TARGET engine (NvRTX) is used only in P7, step by step with the user's approval. See `CLAUDE.md` section 0a.

External task **X1** (in the recorder repository, done by the user) must be finished before the error-vector part of P1 acceptance and before P2 acceptance. It does not block P0.

---

## P0. Environment, scaffolding, packaging check (DEV engine only)

**Read `CLAUDE.md` section 0a before starting. P0 never builds anything with the TARGET engine (NvRTX) and never writes into protected locations.**

**Goal.** Know the environment; a buildable runtime plugin on the **DEV engine** (stock launcher UE 5.6); proof that it works in a packaged Blueprint-only project on the DEV engine (U8) before any logic is written.

**Step 0: state after the incident of 2026-11-17 (see `docs/INCIDENTS.md`).**
- Uncommitted work from the first P0 attempt may exist in the working tree: `Plugins/LightSequence/` (scaffolding, 0.1.0) and `.uedev/LightSequenceDev/` (associated with the TARGET engine, with NvRTX warning flags copied into its target files). Keep the plugin scaffolding if it is clean; **re-associate `.uedev/LightSequenceDev/` with the DEV engine and remove the NvRTX-specific flags** (or recreate the project). Delete its `Binaries/` and `Intermediate/` only inside `.uedev/` (inside the repository, allowed).
- Do nothing about the TARGET engine's changed DLLs: their recovery is handled by the user (`docs/INCIDENTS.md`).

**Step 1: environment survey (read-only).**

_Start from_ `docs/CURRENT_PC_ENV.md` _(written by the user); verify it and write the result to_ `docs/ENVIRONMENT.md`_._

Record both engines (U10):
- **DEV engine**: launcher UE 5.6 install path (typically under `C:\Program Files\Epic Games\UE_5.6`, verify; the user installs it, you never do), exact version from `Engine/Build/Build.version`, the `EngineAssociation` string for projects (for launcher builds normally `"5.6"`, verify), `Engine/Build/InstalledBuild.txt` present, `UnrealInsights.exe` present, `RunUAT.bat` path. If the DEV engine is not installed, stop and ask the user to install it.
- **TARGET engine** (read-only facts only): path, version, GUID, as in `CURRENT_PC_ENV.md`.
- Visual Studio / Build Tools, MSVC toolsets and Windows SDKs that the DEV engine accepts (verify against the DEV engine's requirements);
- Python version (for `tools/`);
- the folder for packaged output (outside protected locations, for example `.uedev/_out/`), the test projects in `.uedev/` (U9).

Ask the user before installing or changing anything.

**Step 2: scaffolding (DEV engine).**

- `Plugins/LightSequence/LightSequence.uplugin`: `VersionName` 0.1.0, `EngineVersion` matching the DEV engine (verify the field and the value), `CanContainContent` true, one Runtime module `LightSequence`, `PlatformAllowList` Win64.
- Module with log category `LogLightSequence` and one trivial Blueprint-callable function (for example `ULightSequenceLibrary::GetPluginVersion()`), enough to see the plugin in Blueprint.
- The C++ **development** test project `.uedev/LightSequenceDev/` (U9), associated with the **DEV engine**, referencing the plugin of this repository (`AdditionalPluginDirectories` or a junction; record which in `ENVIRONMENT.md`). Check that `.uedev/` is git-ignored before creating files there.
- `tools/build_plugin.ps1`: `RunUAT BuildPlugin` of the **DEV engine** (`-Plugin=<repo>/Plugins/LightSequence/LightSequence.uplugin -Package=<out> -TargetPlatforms=Win64`; verify the arguments for 5.6). The engine path is a parameter with the DEV engine as default; the script refuses to run when the engine path is the TARGET engine (`D:\BESPOKE_ATRIUM\...`) unless an explicit switch for P7 is given.
- Before the first build: apply the checks of `CLAUDE.md` section 0a and write in the report which engine and paths were used.

**Step 3: packaging check (U8, DEV engine).**

- Create the **Blueprint-only** test project `.uedev/LightSequenceBP/` (U9; no `Source/` folder, associated with the DEV engine), copy the packaged plugin into its `Plugins/`, open it, call the trivial function from a level Blueprint (manual step for the user if the editor is needed; give exact clicks), package it for Win64 Development (and Shipping if it works) with the DEV engine's `RunUAT BuildCookRun`.
- Record in the report: did packaging compile C++ (log lines as evidence)? Did the packaged exe start and call the plugin function (log line)?

**Acceptance.** `ENVIRONMENT.md` exists with both engines; the plugin builds on the DEV engine with the script; the packaged Blueprint-only project (DEV engine) starts and its log shows the plugin function was called; the report lists every command that wrote files and confirms that **nothing was written into protected locations**.

---

## X1. Error vectors and frame-stamp files (external: recorder repository)

**Not done in this repository.** The user runs it in `art-stream-rec` (branch decided by the user, for example `dev/v1.2.2` from `master`), then copies the output into `spec/golden/errors/` and updates `spec/SPEC_SOURCE.md`.

Content of `tools/make_error_vectors.py` (uses `plsq.py`):

- one small file per error code of spec section 10 (see `spec/golden/errors/README.md`), `NotFinalized` made from the real interrupted recording `M1_9.plsq.part` (trimmed: header + meta area + 2 frames);
- valid files: with trailing bytes (`TrailingData` warning), without optional keys, with both optional keys, with one extra unknown key;
- **frame-stamp** pattern: chip 0 **and** the last chip hold the frame index as `uint32` little-endian (bytes R, G, B, W = index bytes 0..3); every other byte of frame `f` is `(base + 7 x f) mod 256`, where `base` is a fixed per-byte pattern (for example `(3 x c + k) mod 256`). Small committed files (for example 130 chips x 300 frames at 30 fps) plus a command line option to generate large ones (for example 64,000 chips, 60 fps, 60 s) into a git-ignored folder;
- `expected.json` (file -> expected result and code).

---

## P1. PLSQ reader (pure C++, no UObject)

**Goal.** Read and validate header and meta exactly as in the spec.

**Changes.**

- `FPlsqHeader`, `FPlsqInfo` (typed fields plus `TMap<FString, FString> AllFields` with every meta key as stored), `EPlsqError` with the codes of spec section 10 plus `TrailingData` as a warning flag.
- `FPlsqFile::ReadInfo(Path, OutInfo, OutError)`: reads 128 bytes, then the meta block, validates **in the order of section 10**, never reads the payload. File size via the platform file API (uint64).
- CRC-32 as specified (own table implementation). Meta parsed with the engine JSON module; all values must be strings (otherwise `MetaParseError`); unknown keys kept; the optional keys `short_packets` and `first_frame_partial` are not required.
- Port of the recorder's universe count (`mapping.py`: `effective_chips_per_universe`, `build_spans`, `count_universes`) **only** for the `InconsistentHeader` check and the info API (U6); a layout where no chip fits is `InconsistentHeader`.
- UTF-8 paths and meta (Cyrillic) must work.

**Acceptance.**

- Automation tests read `spec/golden/conformance_v1.plsq` and check every property of spec section 14, including the Cyrillic `developer_notes` and the file size 74,832.
- The real recordings in `test_data/` (`m1_1.plsq`, `sequence_1.plsq`) read without error; their key fields match `test_data/README.md`.
- `test_data/M1_9_trimmed.plsq.part` gives `NotFinalized`; a non-existent path gives `IoError`.
- After X1: every file in `spec/golden/errors/` gives the result of `expected.json` (one data-driven test). Until X1 is done, report this part as "pending X1".

---

## P2. Chunk streaming engine

**Goal.** Play files of any size (up to 64,000 chips at 60 fps, hours long) without loading the payload and without file I/O on the game thread (D6).

**Design (required).**

- `FPlsqStreamer`: `Open(Path)`, `Close()`, `Seek(FrameIndex)`, `CopyFrame(FrameIndex, uint8* Dest) -> bool`, metrics (underrun count, buffered chunks, bytes read).
- Chunk = `ChunkSeconds` of frames (default 1.0 s, at least 1 frame). Ring of `ReadAheadChunks` (default 4, clamp 2..16) plus the current chunk. Buffers allocated once at `Open`; no allocation per frame or per chunk.
- Memory cap `MaxBufferMB` (default 512): if `chunk_bytes x chunks` exceeds it, reduce read-ahead and log a warning.
- If the whole payload fits into the ring, all chunks stay resident: no re-reading at the loop point.
- One background reader (`FRunnable` with `IFileHandle`, or the 5.6 async file API if it is clearly better; justify in the report). Offset = `payload_offset + chunk_index x chunk_bytes` (uint64). The last chunk can be shorter.
- Game thread only calls `CopyFrame`; if the chunk is not ready it returns false (the player keeps the previous frame and counts an underrun).
- `Seek` cancels read-ahead, loads the target chunk first, then refills. Looping: after the last chunk comes chunk 0 (only when looping is on).
- `Open` completes (the `OnLoaded` moment) only after the first chunk is ready.
- Optional blocking wait in `CopyFrame` controlled by a flag (used by `bBlockOnUnderrun`, U2; not tuned).
- I/O errors go through the error path; never crash.

**Acceptance (needs X1 frame-stamp files).**

- Sequential playback of a generated 64,000-chip, 60 fps, 60 s frame-stamp file: every frame copied has matching stamps at chip 0 and the last chip and the expected content; zero underruns on the user's machine (report disk type).
- 1,000 random seeks land on the right frame (stamp check); no frame is glued from two frames (stamps at both ends equal).
- Memory steady (report numbers); loop of a small resident file causes no reads after the first pass.

---

## P3. `ULightSequencePlayer` (ActorComponent)

**Goal.** The Blueprint-facing player.

**Changes.**

- Properties: `FilePath`, `bLoop`, `PlayRate` (> 0), `ChunkSeconds`, `ReadAheadChunks`, `MaxBufferMB`, `bAllowChipCountMismatch` (false), `ModelChipsCount` (set from Blueprint or derived from the bound outputs; document which), `bBlockOnUnderrun` (false, U2).
- Functions (BlueprintCallable): `OpenFile`, `CloseFile`, `Play`, `Pause`, `Stop`, `SeekToFrame`, `SeekToTime`, `GetCurrentFrame`, `GetCurrentTime`, `IsPlaying`, `GetUnderrunCount`, `SetExternalTime(Seconds)` (U2: when used, the clock is driven from outside instead of DeltaTime; not tested beyond a smoke test).
- Events (dynamic multicast): `OnLoaded(Info)`, `OnFinished`, `OnLooped`, `OnError(ErrorCode, Message)`, `OnBuffering`, `OnBufferReady`. No event carries frame bytes.
- Chip count check (U3): on open, compare file `chips_count` with the model; refuse with `ChipCountMismatch` by default; with `bAllowChipCountMismatch` play `min` and send black to the extra model chips; mismatch info goes into `FLightSequenceInfo` and the JSON. `model_chips_tag` vs a component property `ModelChipsTag`: warning only.
- Time-based playback in `TickComponent`: `Time += DeltaTime x PlayRate`; `Frame = floor(Time x fps)` clamped to `frame_count - 1`; frames are skipped when the engine is slower than the content. End: loop or finish.
- Staging frame buffer owned by the player; each tick, if the frame index changed, copy once from the streamer and pass it to the bound `IChipFrameSink`s (P4).
- Debug `GetChipColor(ChipIndex)` from the staging buffer.
- Warning in the log (not an error) when `short_packets > 0` or `first_frame_partial == "1"`.

**Acceptance.** Automation tests (and a user-built test Blueprint, manual steps): play, pause, seek, loop, finish correct for 30 and 60 fps content with the engine at 30, 60 and 144 fps; chip count refuse / allow paths; player's own game-thread cost (without outputs) below 0.5 ms per tick at 64,000 chips (Unreal Insights, report).

---

## P5. Info API for Blueprint and Pixel Streaming

**Goal.** Every field except the payload reaches Blueprint and the frontend (D8).

**Changes.**

- `USTRUCT(BlueprintType) FLightSequenceInfo`: typed fields (`ModelName`, `ModelChipsTag`, `ChipsCount`, `SequenceName`, `SequenceVersion`, `DurationSec`, `Fps`, `FrameCount`, `FrameStride`, `StartUniverse`, `StartChannel`, `ChipsPerUniverse`, `UniversesCount`, `RecordedAt`, `RecorderVersion`, `SequenceId`, `DeveloperNotes`, quality counters, `ShortPackets` (0 if absent), `bFirstFramePartial` (false if absent)), chip-count mismatch info (U3), `AllFields` (every meta key exactly as stored), `FileName`, `FileSizeBytes`, `FileFormat`.
- `GetSequenceInfo()` and `GetSequenceInfoAsJson()`: compact JSON with all meta keys (strings, unknown keys included, optional keys only when present) plus `file_name`, `file_size_bytes`, and the mismatch fields when relevant (document their key names in the README).
- `ULightSequenceLibrary`: `ReadSequenceInfo(Path, bSuccess, Info, ErrorCode)` (header + meta only); `ListSequences(DirectoryPath) -> TArray<FLightSequenceInfo>` for `.plsq` files (ignores `.part`); `GetSequencesDirectory()` (U5).

**Acceptance.** All 27 required keys, the optional keys (when present; a file without them loads), and an extra unknown key appear in the JSON as stored; `ListSequences` on a folder with 100 files returns quickly without reading payloads (report the time).

---

## P4. Outputs (via `IChipFrameSink`, U7)

**Goal.** Drive the model at up to 64,000 chips (D7).

**4a. Texture output (fake light).**

- Runtime texture `PF_R8G8B8A8` (if the update path needs B8G8R8A8, swizzle during the copy and document it), no mips, no compression, **sRGB off** (D10), filter Nearest, address Clamp. Width `TextureWidth` (default 2048), height `ceil(chips / width)`; chip `i` is pixel `(i % W, i / W)`; W channel in alpha; padding pixels zero.
- Update only when the frame index changes, with the supported 5.6 mechanism that does not recreate the resource (verify `UpdateTextureRegions` or a render-command RHI update). **The source buffer must stay alive until the render thread has consumed it**: double-buffer or copy into the render command; document the choice.
- `GetChipTexture()` and a helper to set it on a dynamic material instance parameter.

**4b. ISM helper.**

- `AssignChipIndices(UInstancedStaticMeshComponent*)`: `NumCustomDataFloats >= 1`, chip index `i` into custom data slot 0 of instance `i` (identity, U4), one batch, render state dirty once. Index as float (exact to 16,777,216).

**4c. Per-chip light components.**

- `SetChipLights(const TArray<ULightComponent*>&)`: element `i` is chip `i` (U4; the array comes from Blueprint in DataTable row order; the plugin does not sort or look up components).
- Per frame: for each chip whose 4 bytes changed (diff with the previous frame), set the color: (R, G, B) / 255 linear (D10); `EWhiteMode`: `Ignore`, `AddToRGB` (default, `R' = min(1, R + W)` etc.). Use the cheapest color-update API that does not rebuild the render state; verify by profiling.
- Null or destroyed elements are skipped with one warning (no crash).
- No clusters. If the cost is too high, report measurements and wait for the user.

**Acceptance.** For each output alone and both together on a synthetic 64,000-chip, 60 fps file: game-thread ms per frame, render thread / GPU impact, memory (Unreal Insights). The texture path shows one texture update per frame and no per-instance updates.

---

## P6. Folder scanning and hot-add

**Goal.** Files copied into the sequences folder while the app runs appear without a rebuild.

**Changes.**

- Folder resolution as in U5 (command line `-LightSequencesDir=`, component property, `.ini`, default `FPaths::ProjectDir()/DmxChipsManagerPlsqFiles/`); the resolved path is logged once and returned by `GetSequencesDirectory()`. Report where the default resolves in the editor and in the packaged build of `.uedev/LightSequenceBP/`.
- `ULightSequenceWatcher` (ActorComponent or subsystem; justify): polls on a timer (default 2 s), diffs by name + size + modified time, ignores `.part` and files still growing (stable over two polls), fires `OnLibraryChanged(NewFiles, RemovedFiles)`.

**Acceptance.** Copying a `.plsq` into the folder during PIE and in a packaged build fires the event once the copy is complete; a half-written file is not announced; each override source works.

---

## P7. Transfer to the TARGET engine (NvRTX) and the host project

**Every step of P7 needs the user's explicit approval before it starts. Read `CLAUDE.md` section 0a again.** The plugin is finished and verified on the DEV engine before P7 begins.

**P7a. Final check on the DEV engine.** Build with the P0 script; install into `.uedev/LightSequenceBP/` and its packaged build; run the automation suite and the playback test with the real recordings from `test_data/`. Report.

**P7b. Build plan for the TARGET engine (read-only investigation, no builds).**
- Find out why UnrealBuildTool considered the TARGET engine out of date on 2026-11-17 (toolchain version used for the original engine build vs. the current default, build settings, makefiles, UBT logs).
- Find a way to compile the plugin for the TARGET engine **without writing anything into the engine folder** (for example: pin the compiler version the engine was built with; compile the plugin only as part of a Blueprint-only project's packaging, the way `Scene_A1` already compiles its temporary game target; or another way found in the engine source). Also cover how the plugin gets editor binaries for opening `Scene_A1` in the TARGET editor.
- Write `docs/P7_TARGET_BUILD_PLAN.md`: each command, the engine it uses, **every folder it writes to**, how to verify that no engine file changed (file list with sizes and times before and after), how to stop it, and what the user must back up first (for example a copy of `Engine/Binaries/Win64` and the project). Stop and wait for the user's approval.

**P7c. Build for the TARGET engine (only after approval of the plan).** Run exactly the approved plan, with a snapshot of the engine's file list before and after. If anything in the engine folder changes, stop immediately and report.

**P7d. Installation into `Scene_A1`.** Done by the user or on the user's explicit command, following the plugin README. `Scene_A1` stays Blueprint-only.

**Acceptance.** All tests pass on the DEV engine; the TARGET build follows the approved plan; the before/after snapshot shows no change in the engine folder; the report lists both engine versions, platform, what was tested and the U8 result for each engine.

---

## P8. Load tests and report (real time only, U2)

**Changes.** On the user's machine, with synthetic files (chips 128, 1,680, 10,000, 32,000, 64,000; fps 30 and 60; durations 10 s and 10 min) and the real `sequence_1.plsq`:

- time from `OpenFile` to `OnLoaded`;
- player cost, texture output cost, light output cost (separately; for lights CPU game thread and GPU separately);
- underruns, memory;
- hitches at the loop point and after seeks.

Measurements are taken on the development laptop with the **DEV engine** (see `ENVIRONMENT.md`); a repeat with the TARGET engine build is optional and only with the user's approval; the target is a remote server with different hardware, so state the hardware in the report and do not present the numbers as server numbers.

Write `docs/BENCHMARK_PLUGIN.md` with the table, an Unreal Insights note per scenario, a line on the status of MegaLights in UE 5.6 (information only, not a commitment) and a conclusion. No offline-render test.

**Acceptance.** The report states plainly which scenarios meet real time at 60 fps and which do not. No redesign based on the results without the user.

---

## Manual editor steps (for the user; copy into `Plugins/LightSequence/README.md`)

1. **Material for fake lights.** `PerInstanceCustomData[0]` = chip index `i`. With texture width `W`, height `H`: `u = (fmod(i, W) + 0.5) / W`, `v = (floor(i / W) + 0.5) / H`. Sample the chip texture at mip 0 (Nearest), RGB to Emissive (alpha is the white channel; combine as needed). Texture parameter set from `GetChipTexture()`. Emissive lights the surroundings only through Lumen.
2. **Blueprint wiring.** Add `ULightSequencePlayer` to the model actor; build the light array / ISM instances **in DataTable row order** at BeginPlay (do not use `Get Components By Class` order, do not reuse cached references from the editor); call `SetChipLights` or `AssignChipIndices` + texture; call `OpenFile` with a path from `ListSequences`; on `OnLoaded` send `GetSequenceInfoAsJson` over Pixel Streaming; call `Play`.
3. **Chip order.** The designer patches the sequence in Madrix/TouchDesigner in the same CHIP_ID order as the DataTable rows (U4).
