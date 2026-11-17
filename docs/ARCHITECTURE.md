# Architecture of the LightSequence plugin

Status: approved by the user on 2026-11-17. Changes need the user's consent (see `CLAUDE.md`, section 2).

## 1. The pipeline in plain words

A designer creates a light animation in Madrix or TouchDesigner. The program sends it over the network (Art-Net) as a stream of commands: "chip 1: this much red, green, blue and white; chip 2: ...", many times per second. Each chip has 4 values from 0 to 255.

The **recorder** pretends to be the installation: it listens to that stream and, exactly 30 or 60 times per second, takes a snapshot of the colors of all chips. One snapshot is one **frame**. All frames are written one after another into a `.plsq` file:

- **header** (128 bytes): how many chips, frames, frames per second, where the data starts;
- **meta** (a JSON "passport"): model and sequence names, recording date, recorder version, notes, quality counters; it can be read without touching the frames;
- **payload**: the frames, packed back to back, all the same size, so frame `f` starts at `payload_offset + f x frame_stride`.

A file can be huge (64,000 chips at 60 fps = about 55 GB per hour), so the format is as simple as possible.

The **plugin** is a player for this file inside Unreal Engine:

1. it **checks** the file (header, meta, consistency) and reports a clear error code when something is wrong;
2. it **reads the file in chunks** in the background, a few seconds ahead, like a video player buffering; the game thread never waits for the disk;
3. it **plays by the clock**: after 2.5 s at 60 fps it shows frame 150; if the engine is slow, frames are skipped, the animation is never slowed down; pause, seek, loop and play rate are supported;
4. it **colors the model**, either with cheap "fake lights" (spheres whose emissive material reads one pixel per chip from a small texture) or with real light components (one per chip; only chips whose color changed are updated);
5. it **exposes the passport** to Blueprint and as one JSON string for the web frontend (Pixel Streaming);
6. it **watches the sequences folder**, so a file copied in while the app runs appears in the list.

**One condition makes it all match:** chip `i` in the file must be chip `i` in the model. The model places chips by the designer's DataTable, row by row (Row Name = CHIP_ID). The designer must number the chips in Madrix/TouchDesigner in the same order as in the DataTable. The plugin does not check this; a wrong order is visible at once (the light runs "in a mess").

## 2. Components

```
.plsq file
   |
   v
FPlsqFile            pure C++: header + meta, validation in the order of spec section 10,
   |                 own CRC-32, meta as TMap<FString,FString> (unknown keys kept)
   v
FPlsqStreamer        background thread, ring of preallocated chunk buffers (default 1 s each,
   |                 read-ahead 4, cap MaxBufferMB), uint64 offsets, Seek, seamless loop;
   |                 game thread only calls CopyFrame(f, Dest) -> bool (false = underrun)
   v
ULightSequencePlayer ActorComponent: time-based playback, Play/Pause/Stop/Seek/Loop/PlayRate,
   |                 staging frame buffer, chip count check (U3), events OnLoaded/OnFinished/
   |                 OnLooped/OnError/OnBuffering/OnBufferReady (no frame bytes in events),
   |                 primitives SetExternalTime(t), bBlockOnUnderrun (untested, U2)
   |
   |  IChipFrameSink  (one interface for all outputs; source-agnostic, U7)
   +----------------------+-------------------------+
   v                      v                         v
Texture output        ISM helper                 Light output
RGBA8, sRGB off,      chip index -> CustomData[0] one light component per chip,
Nearest, no mips,     once (identity order, U4)  diff with previous frame,
one upload per frame,                            color = RGB/255 linear,
W in alpha, buffer                               EWhiteMode (Ignore, AddToRGB default)
alive until render
thread consumed it

Info API (D8): FLightSequenceInfo (typed fields + AllFields + file name/size/format
+ chip-count-mismatch info), GetSequenceInfoAsJson(), ReadSequenceInfo(path),
ListSequences(dir) -- header + meta only, no payload.

Watcher: folder (U5), poll every 2 s, ignores .part and growing files,
OnLibraryChanged(New, Removed).
```

Module: one Runtime module `LightSequence` (UE 5.6, Win64), log category `LogLightSequence`, packaged with `RunUAT BuildPlugin`.

## 3. Key rules (short)

- Universes play no role in playback (U6); the frame is an offset in a flat RGBW-per-chip array. The universe-count port is only for validation and info. Note the recorder's function signature: `count_universes(start_universe, start_channel, chips_per_universe, chips)`; capacity of the first universe = `(512 - (start_channel - 1)) // 4` chips (capped by the effective chips per universe); every following universe starts at channel 1; a mapping where no chip fits is an `InconsistentHeader` (as in the Python reader).
- Chip order comes from Blueprint (DataTable row order). The plugin accepts arrays as given (U4).
- Chip count mismatch: refuse by default, optional `bAllowChipCountMismatch` (U3).
- Real-time only (U2).
- Lumen: emissive "fake lights" light their surroundings only through Lumen; this is a note for the README, not a task.

## 4. Risks

See `docs/BACKLOG.md`.
