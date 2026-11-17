# Error vectors (placeholder)

This folder is filled from the recorder repository (`art-stream-rec`, `tools/make_error_vectors.py`, task X1 in `docs/TASKS_UE_PLUGIN.md`). Do not create these files by hand in this repository.

Expected content once X1 is done:

- One small `.plsq` file per reader error code of `spec/PLSQ_SPEC.md` section 10: `Truncated`, `BadMagic`, `UnsupportedVersion`, `BadHeaderSize`, `HeaderCrcMismatch`, `UnsupportedFlags`, `NotFinalized`, `UnsupportedLayout`, `OutOfRange`, `InconsistentHeader`, `MetaOutOfBounds`, `MetaCrcMismatch`, `MetaParseError`, `MissingMetaKey`, `MetaMismatch`; plus a valid file with trailing bytes (`TrailingData` warning), a valid file without the optional keys, a valid file with both optional keys, and a valid file with an extra unknown meta key.
- Small **frame-stamp** files (see `docs/TASKS_UE_PLUGIN.md`, X1).
- `expected.json`: `{ "<file name>": { "result": "ok" | "error" | "warning", "code": "<code or empty>" } }`.

`IoError` is tested without a file (non-existent path).
