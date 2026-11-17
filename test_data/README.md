# Test data

Real recordings made with recorder v1.2.1 during the manual checks of 2026-11-16/17 (see `art-stream-rec`, `docs/manual_tests/MANUAL_CHECKS_session_15_11_2026_#2_RESULTS.md` on branch `dev/v1.2.1`). They are **not** in the recorder repository (its `.gitignore` excludes them); the user copies them here from disk.

| File | What it is | Expected key values | Committed |
|---|---|---|---|
| `m1_1.plsq` | M1.1, test source (`packets_tester`, rainbow pattern), 104 chips | 104 chips, 30 fps, 180 frames, stride 416, 1 universe, chips_per_universe 128, size 144,512 bytes, all quality counters 0, optional keys present (`0`) | yes |
| `sequence_1.plsq` | M2, **real TouchDesigner recording** | 1,680 chips, 14 universes, 30 fps, 900 frames, stride 6,720, size 6,117,632 bytes, all quality counters 0 | yes |
| `M1_2.json` | M1.2, JSON export of the same 104-chip source. **Not read by the plugin** (U1: JSON is played by the existing Blueprint parser of the host project); kept only to cross-check payload bytes against `m1_1.plsq` | 104 chips, 180 frames, stride 416, about 471 KB | yes |
| `M1_9.plsq.part` | M1.9, interrupted 64,000-chip recording (window closed after about 4 s), about 57.5 MB | not finalized | **no** (too large, git-ignored) |
| `M1_9_trimmed.plsq.part` | Header + meta area + 2 frames of `M1_9.plsq.part`, made with `tools/trim_part.py` | reader result: `NotFinalized` | yes |

## How to add the files (user, once)

PowerShell, from the repository root (adjust the source folder):

```powershell
$src = "D:\path\to\recordings"
Copy-Item "$src\m1_1.plsq", "$src\sequence_1.plsq", "$src\M1_2.json", "$src\M1_9.plsq.part" .\test_data\
python tools\trim_part.py test_data\M1_9.plsq.part test_data\M1_9_trimmed.plsq.part --frames 2
git add test_data\m1_1.plsq test_data\sequence_1.plsq test_data\M1_2.json test_data\M1_9_trimmed.plsq.part
git commit -m "Add real test recordings from recorder v1.2.1 manual checks"
```

Expected size of `M1_9_trimmed.plsq.part`: 69,632 + 2 x 256,000 = 581,632 bytes.

## generated/

Synthetic files (hundreds of MB) are generated into `test_data/generated/`, which is git-ignored.
