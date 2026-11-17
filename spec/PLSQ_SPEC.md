# PLSQ file format, version 1

Normative specification. MUST / SHOULD / MAY are used as in RFC 2119.
Reference implementations: `plsq.py` (Python recorder side) and the UE plugin (C++).
If this document and an implementation disagree, this document wins; report the disagreement to the user.

## 1. Purpose and conventions

A PLSQ file stores a baked DMX light sequence: `frame_count` frames, each frame is `chips_count x 4` raw bytes (0..255) exactly as received over Art-Net (RGBW, DMX order).

- All integers are little-endian. Strings are UTF-8 (no BOM).
- All offsets are in bytes from the start of the file.
- CRC-32 everywhere means the standard CRC-32 (IEEE 802.3, polynomial 0xEDB88320, init 0xFFFFFFFF, final XOR 0xFFFFFFFF), identical to Python `zlib.crc32`. The C++ side MAY use its own table-based implementation; it MUST pass the golden vector test (section 10).

## 2. File layout

```
offset 0        header          128 bytes, fixed
offset 128      meta block      capacity 65,536 bytes; meta_size bytes used, the rest is zero-filled
offset 69,632   payload         frame_count x frame_stride bytes (payload_offset is 4096-aligned)
end of file     = payload_offset + payload_size (no trailer in v1)
```

Writers produced by the recorder MUST use meta_offset = 128 and payload_offset = 69,632 (= 17 x 4096). Readers MUST use the offsets from the header and MUST NOT assume these values.

## 3. Header (128 bytes)

| Offset | Size | Type | Field | Rules |
|---|---|---|---|---|
| 0 | 4 | char[4] | `magic` | ASCII `PLSQ` (0x50 0x4C 0x53 0x51) |
| 4 | 2 | u16 | `format_version` | 1 |
| 6 | 2 | u16 | `header_size` | 128 in v1 |
| 8 | 4 | u32 | `flags` | see section 4 |
| 12 | 4 | u32 | `chips_count` | 1..64,000 |
| 16 | 2 | u16 | `channels_per_chip` | 4 in v1 |
| 18 | 2 | u16 | `fps` | recorder writes 30 or 60; readers accept 1..240 |
| 20 | 4 | u32 | `frame_count` | >= 1 |
| 24 | 4 | u32 | `frame_stride` | = chips_count x channels_per_chip |
| 28 | 4 | u32 | reserved | 0 |
| 32 | 8 | u64 | `payload_offset` | multiple of 4096, >= meta_offset + meta_size |
| 40 | 8 | u64 | `payload_size` | = frame_count x frame_stride |
| 48 | 8 | u64 | `meta_offset` | 128 in v1 |
| 56 | 4 | u32 | `meta_size` | 2..65,536 |
| 60 | 4 | u32 | `meta_crc32` | CRC-32 of the `meta_size` meta bytes |
| 64 | 2 | u16 | `start_universe` | 0..32,767 (Art-Net port-address, 0-based) |
| 66 | 2 | u16 | `start_channel` | 1..512 |
| 68 | 2 | u16 | `chips_per_universe` | EFFECTIVE value, 1..128 (never 0) |
| 70 | 2 | u16 | `universes_count` | number of universes used by the layout |
| 72 | 52 | - | reserved | zeros |
| 124 | 4 | u32 | `header_crc32` | CRC-32 of bytes 0..123 |

Python reference: `struct.Struct("<4sHHIIHHIIIQQQIIHHHH52xI")` has size 128 and the fields above in this order (`magic, format_version, header_size, flags, chips_count, channels_per_chip, fps, frame_count, frame_stride, reserved, payload_offset, payload_size, meta_offset, meta_size, meta_crc32, start_universe, start_channel, chips_per_universe, universes_count, header_crc32`).

## 4. Flags

| Bit | Name | Meaning |
|---|---|---|
| 0 | `COMPRESSED` | Reserved for a future version. MUST be 0 in v1. A v1 reader MUST reject a file with this bit set. |
| 1 | `FINALIZED` | 1 when the writer finished the file successfully. A reader MUST reject files without it (`NotFinalized`). |
| 2..31 | - | MUST be 0 when writing; readers ignore them. |

## 5. Meta block

A UTF-8 JSON object, flat, all values are **strings**. It holds every descriptive field of the sequence. Readers MUST accept and pass through unknown keys (they are forwarded to Blueprint and the frontend as-is). A writer MAY add keys without changing `format_version`.

Meta size limit: 65,536 bytes. The recorder MUST validate before recording starts that the meta will fit (the long free-text field is `developer_notes`).

Required keys (27), followed by optional keys (marked *optional*). The same keys, in this order, are written to JSON files:

| Key | Example | Meaning |
|---|---|---|
| `file_format` | `"plsq"` | `"plsq"` or `"json"` |
| `format_version` | `"1"` | |
| `sequence_id` | `"3f2a...-...."` | UUID v4 generated when the file is saved |
| `recorded_at` | `"2026-11-15T14:32:10+03:00"` | ISO 8601, local time with UTC offset, seconds precision |
| `recorder_version` | `"1.1.0"` | value of `APPV` |
| `model_name` | `"Crystal Links Model 1"` | free text |
| `model_chips_tag` | `"crystal_links_model_1_chip"` | free text |
| `model_chips_count` | `"64000"` | equals header `chips_count` |
| `sequence_name` | | free text |
| `sequence_version` | `"1.0"` | free text |
| `sequence_duration_sec` | `"6.0"` | `str(round(frame_count / fps, 3))` |
| `sequence_fps` | `"30"` | equals header `fps` |
| `sequence_frame_count` | `"180"` | equals header `frame_count` |
| `sequence_frame_stride` | `"256000"` | equals header `frame_stride` |
| `input_mapping_start_universe` | `"1"` | equals header `start_universe` |
| `input_mapping_start_channel` | `"1"` | equals header `start_channel` |
| `input_mapping_channels_per_chip` | `"4"` | equals header `channels_per_chip` |
| `input_mapping_chips_per_universe` | `"128"` | effective value, equals header |
| `input_mapping_universes_count` | `"500"` | equals header `universes_count` |
| `post_skip_frames` | `"0"` | frames dropped at the start by post-processing |
| `post_loop_blend_frames` | `"0"` | loop-blend length that was applied |
| `recorded_frames_raw` | `"180"` | frames captured before post-processing (including skipped and blend frames) |
| `missing_frames` | `"0"` | frames in which a mapped universe had no data yet (whole raw recording) |
| `late_frames` | `"0"` | frames sampled more than 1.5 periods late (whole raw recording) |
| `partial_source_frames` | `"0"` | source frames committed incomplete (see recorder task R5); `"0"` when the source is always complete |
| `lost_packets` | `"0"` | packets lost according to Art-Net sequence numbers; `"0"` if the source does not use sequence numbers |
| `developer_notes` | | free text |
| `short_packets` | `"0"` | *optional; reader must not require it.* ArtDMX packets that carried fewer DMX channels than the mapping needs for their universe (missing channels recorded as 0), whole raw recording. Written by recorder 1.2.x when the frame assembler was on; absent otherwise |
| `first_frame_partial` | `"0"` | *optional; reader must not require it.* `"1"` if the recording started on a partial assembled frame (no complete frame within 2 s), else `"0"` |

Number formatting: decimal integers without leading zeros, no separators. Keys with empty text are written as `""`, never omitted.

The plugin additionally exposes `file_name`, `file_size_bytes` and `file_format` derived from the file system; these are NOT stored in the file.

## 6. Consistency rules between header and meta

The following pairs MUST be equal (validator checks them):

| Header | Meta key |
|---|---|
| `chips_count` | `model_chips_count` |
| `fps` | `sequence_fps` |
| `frame_count` | `sequence_frame_count` |
| `frame_stride` | `sequence_frame_stride` |
| `start_universe` | `input_mapping_start_universe` |
| `start_channel` | `input_mapping_start_channel` |
| `channels_per_chip` | `input_mapping_channels_per_chip` |
| `chips_per_universe` | `input_mapping_chips_per_universe` |
| `universes_count` | `input_mapping_universes_count` |

Also: `sequence_duration_sec` = `round(frame_count / fps, 3)`; `file_format` = `"plsq"`; `format_version` = `"1"`.

## 7. Payload and addressing

```
frame f starts at   payload_offset + f * frame_stride
chip c in frame f   payload_offset + f * frame_stride + c * 4
bytes of a chip     [R, G, B, W]   (DMX channel start_channel + 0..3 of its universe)
```

No per-frame header, no padding between frames. Random access to any frame is a single offset calculation.

## 8. Mapping semantics

Chips are laid out over universes by `build_spans` of the recorder (reference: `main.py`):

- `effective_chips_per_universe = 128` when the user setting is 0 (auto), otherwise `min(setting, 128)`.
- The first universe starts at `start_channel`; every following universe starts at channel 1; chips never straddle a universe boundary.
- `universes_count = len(build_spans(...))`.

The mapping fields are informational for playback (the payload is already packed by chip index) but they are needed to reproduce the capture and to show on the frontend.

## 9. Writer procedure (recorder, streaming)

1. Create `<target>.part`. Write a placeholder header: `FINALIZED = 0`, `frame_count = 0`, `payload_size = 0`, valid header CRC. Seek to `payload_offset` and append frames as they are produced (never hold the whole recording in memory).
2. Loop blend, when enabled, is applied in place after capture stops (first `blend` frames are rewritten); see recorder task R4.
3. On stop: flush the payload, write the meta block at `meta_offset` (zero-pad up to its capacity or leave the gap zero), write the final header with the real counts and `FINALIZED = 1`, flush, then atomically replace the target: `os.replace(part, target)`.
4. On failure keep the `.part` file and report its path. Never delete it silently.

## 10. Reader procedure and errors

A reader MUST perform these checks in order and report the first failure with the error code:

| Code | Check |
|---|---|
| `IoError` | file cannot be opened or read |
| `Truncated` | file shorter than 128 bytes, or shorter than `payload_offset + payload_size` |
| `BadMagic` | magic is not `PLSQ` |
| `UnsupportedVersion` | `format_version` is not 1 |
| `BadHeaderSize` | `header_size` < 128 |
| `HeaderCrcMismatch` | CRC of bytes 0..123 differs from `header_crc32` |
| `UnsupportedFlags` | bit 0 (`COMPRESSED`) is set |
| `NotFinalized` | bit 1 (`FINALIZED`) is not set |
| `UnsupportedLayout` | `channels_per_chip` is not 4 |
| `OutOfRange` | `chips_count` not in 1..64,000; `fps` not in 1..240; `frame_count` < 1; `start_universe` > 32,767 or `start_universe + universes_count - 1` > 32,767; `start_channel` not in 1..512; `chips_per_universe` not in 1..128 |
| `InconsistentHeader` | `frame_stride` != `chips_count x 4`; `payload_size` != `frame_count x frame_stride`; `payload_offset` not a multiple of 4096 or < `meta_offset + meta_size`; `universes_count` differs from the value computed with the mapping rules |
| `MetaOutOfBounds` | `meta_size` not in 2..65,536, or meta lies outside the file |
| `MetaCrcMismatch` | CRC of the meta bytes differs from `meta_crc32` |
| `MetaParseError` | meta is not a JSON object of string values |
| `MissingMetaKey` | a required key (section 5) is absent |
| `MetaMismatch` | a pair from section 6 differs |

Extra bytes after `payload_offset + payload_size` are a warning (`TrailingData`), not an error.

Payload bytes are not checksummed (too large); header and meta are.

## 11. Streaming guidance for readers (non-normative)

- Frames have a fixed stride, so a reader reads any frame range with one seek and one read.
- A practical chunk is 1 second of frames (`fps` frames). At 64,000 chips and 60 fps one chunk is 15.36 MB.
- `payload_offset` is 4096-aligned so that chunk reads can be aligned when `chunk_bytes` is a multiple of 4096 (optional optimization).

## 12. JSON format (small installations only)

JSON files are written only when `universes_count <= 2` (decision D3).

```json
{
  "file_format": "json",
  "format_version": "1",
  "sequence_id": "...",
  "...": "all 27 keys of section 5, in that order, all values strings",
  "developer_notes": "...",
  "sequence": {
    "data": [
      0.276, 0.0, 1.0, 0.0, ...,
      ...
    ]
  }
}
```

- `sequence.data` is a flat array of floats: `round(byte / 255, 3)`, one frame per line, UTF-8, `\n` line endings (as in the current writer).
- Layout: `data[frame * stride + chip * 4 + channel]`.
- Converting back is lossless: `byte = round(value * 255)`.
- The JSON header carries the same keys and values as the `.plsq` meta, with `file_format = "json"`.

## 13. Limits summary

| Item | Limit |
|---|---|
| Chips | 1..64,000 |
| Channels per chip | 4 |
| FPS written by the recorder | 30 or 60 |
| Universes | 1..500 for 128 chips per universe; always inside 0..32,767 |
| Meta | at most 65,536 bytes |
| Payload | `frame_count x frame_stride`, up to many GB (use u64 everywhere in code) |

## 14. Conformance file (golden test)

`tests/golden/conformance_v1.plsq` is generated by `tools/make_golden.py` and MUST be read identically by the Python validator and the C++ reader.

| Property | Value |
|---|---|
| chips_count | 130 |
| fps | 30 |
| frame_count | 10 |
| start_universe / start_channel | 1 / 1 |
| chips_per_universe / universes_count | 128 / 2 |
| byte of frame `f`, chip `c`, channel `k` | `(f * 7 + c * 3 + k) mod 256` |
| model_name | `Conformance` |
| model_chips_tag | `conformance_chip` |
| sequence_name | `Conformance Sequence` |
| sequence_version | `1.0` |
| developer_notes | `Тест UTF-8: привет` |
| recorded_at | `2026-01-01T00:00:00+00:00` |
| recorder_version | `test` |
| sequence_id | `00000000-0000-4000-8000-000000000000` |
| post_skip_frames, post_loop_blend_frames, missing_frames, late_frames, partial_source_frames, lost_packets | `0` |
| recorded_frames_raw | `10` |
| input_mapping_channels_per_chip | `4` |

The file size is 69,632 + 10 x 520 = 74,832 bytes.

## 15. Future (not in v1)

- Compression: set `COMPRESSED`, add a chunk index in a footer whose offset is stored in a reserved header field; new `format_version` or a flag-guarded extension.
- More meta keys: just add them (no version change).
