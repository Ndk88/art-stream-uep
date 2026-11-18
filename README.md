# art-stream-uep — LightSequence plugin for Unreal Engine 5.6

Plays baked light sequences (`.plsq` files) on 3D models of LED-chip installations in real time, for presentations over Pixel Streaming.

`.plsq` files are recorded from an Art-Net stream (Madrix 5, TouchDesigner) by the **Art Stream Sequence Recorder**: https://github.com/Ndk88/art-stream-rec (release v1.2.1). The format is specified in `spec/PLSQ_SPEC.md` (a read-only copy, see `spec/SPEC_SOURCE.md`).

The plugin handles **only `.plsq`**. The recorder can also save small sequences (1 or 2 universes) as JSON; those are played by the existing, tested Blueprint JSON parser of the host UE project, which stays unchanged and is not part of this repository.

| Document | Content |
|---|---|
| `docs/ARCHITECTURE.md` | How recorder and plugin work together; plugin components |
| `docs/TASKS_UE_PLUGIN.md` | Development tasks P0..P8 |
| `docs/BACKLOG.md` | Risks and deferred features |
| `CLAUDE.md` | Rules and decisions for Claude Code |
| `test_data/README.md` | Real recordings used for tests |

Status: development of v0.1.0 (branch `dev/v0.1.0`). Task P0 done: plugin scaffolding in `Plugins/LightSequence/` (user docs: `Plugins/LightSequence/README.md`), build and test scripts in `tools/`, environment in `docs/ENVIRONMENT.md`.

Engines: development and tests run on the stock **UE 5.6 from the Epic Games Launcher**. The host project's engine (a source build of UE 5.6.1, NvRTX Caustics) is never modified by this project; the plugin is compiled for it only in the final task P7, with a plan approved by the user (see `CLAUDE.md` section 0a).

## Versions and branches

| Ref | Purpose |
|---|---|
| `master` | Latest release (none yet: initial import only) |
| tag `vX.Y.Z` | Exact state of a released version |
| `dev/vX.Y.Z` | Development of the next version (currently `dev/v0.1.0`) |

The plugin version is `VersionName` in `Plugins/LightSequence/LightSequence.uplugin`. It is independent of the recorder version.
