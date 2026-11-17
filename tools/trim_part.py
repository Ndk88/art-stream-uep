#!/usr/bin/env python3
"""
Make a small copy of an interrupted PLSQ recording (.part) for use as a test vector.

Usage:
    python tools/trim_part.py <source.plsq.part> <dest.plsq.part> [--frames N]

Copies the first payload_offset + N * frame_stride bytes (default N = 2) of the
source into a new file. Header and meta area are copied unchanged, so the
header CRC stays valid and the file still has no FINALIZED flag: a reader must
report NotFinalized (spec/PLSQ_SPEC.md section 10).

The source file is never modified. Python 3.9+, stdlib only.
"""

import argparse
import os
import struct
import sys
import zlib

HEADER = struct.Struct("<4sHHIIHHIIIQQQIIHHHH52xI")
FLAG_FINALIZED = 1 << 1


def main(argv=None):
    p = argparse.ArgumentParser(description="Trim an interrupted .plsq.part file.")
    p.add_argument("source")
    p.add_argument("dest")
    p.add_argument("--frames", type=int, default=2, help="whole frames to keep")
    args = p.parse_args(argv)

    if args.frames < 0:
        print("error: --frames must be >= 0", file=sys.stderr)
        return 2
    if os.path.abspath(args.source) == os.path.abspath(args.dest):
        print("error: dest must differ from source", file=sys.stderr)
        return 2
    if os.path.exists(args.dest):
        print("error: dest already exists: %s" % args.dest, file=sys.stderr)
        return 2

    size = os.path.getsize(args.source)
    with open(args.source, "rb") as f:
        raw = f.read(HEADER.size)
        if len(raw) < HEADER.size:
            print("error: source shorter than the 128-byte header", file=sys.stderr)
            return 1
        fields = HEADER.unpack(raw)
        magic, flags, stride = fields[0], fields[3], fields[8]
        payload_offset, header_crc = fields[10], fields[19]
        if magic != b"PLSQ":
            print("error: bad magic %r" % magic, file=sys.stderr)
            return 1
        if (zlib.crc32(raw[:124]) & 0xFFFFFFFF) != header_crc:
            print("error: header CRC mismatch in source", file=sys.stderr)
            return 1
        if flags & FLAG_FINALIZED:
            print("warning: source is FINALIZED; the copy will not be a NotFinalized vector")
        if stride == 0:
            print("error: frame_stride is 0 in the header", file=sys.stderr)
            return 1

        whole_frames = max(0, (size - payload_offset) // stride)
        keep_frames = min(args.frames, whole_frames)
        keep = payload_offset + keep_frames * stride
        if keep > size:
            keep = size

        f.seek(0)
        remaining = keep
        with open(args.dest, "wb") as out:
            while remaining > 0:
                chunk = f.read(min(remaining, 1 << 20))
                if not chunk:
                    break
                out.write(chunk)
                remaining -= len(chunk)

    print(
        "source: %d bytes, %d whole frames (stride %d, payload_offset %d)"
        % (size, whole_frames, stride, payload_offset)
    )
    print("dest:   %d bytes, %d frames kept -> %s" % (keep, keep_frames, args.dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
