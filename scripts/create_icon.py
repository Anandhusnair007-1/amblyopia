#!/usr/bin/env python3
"""Create AmbyoAI app icon: blue background with eye symbol (no SightConnect)."""
import struct
import zlib
import os
import math

def make_png(size, bg_r, bg_g, bg_b):
    """Create PNG with eye symbol on solid background."""
    def chunk(name, data):
        c = struct.pack(">I", len(data))
        c += name + data
        crc = zlib.crc32(name + data) & 0xFFFFFFFF
        c += struct.pack(">I", crc)
        return c

    png = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png += chunk(b"IHDR", ihdr_data)

    raw_data = b""
    cx = size // 2
    cy = size // 2

    for y in range(size):
        row = b"\x00"
        for x in range(size):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            rel = size / 1024

            # White outer ring
            if 180 * rel < dist < 210 * rel:
                row += bytes([255, 255, 255])
            # Cyan inner ring
            elif 120 * rel < dist < 150 * rel:
                row += bytes([0, 180, 216])
            # White pupil dot
            elif dist < 60 * rel:
                row += bytes([255, 255, 255])
            # Blue background
            else:
                row += bytes([bg_r, bg_g, bg_b])
        raw_data += row

    compressed = zlib.compress(raw_data, 9)
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    return png


os.makedirs("assets/images", exist_ok=True)

# AmbyoAI blue: #1565C0
icon_data = make_png(1024, 21, 101, 192)
with open("assets/images/app_icon.png", "wb") as f:
    f.write(icon_data)

# Foreground for adaptive icon (same design)
fg_data = make_png(1024, 21, 101, 192)
with open("assets/images/app_icon_foreground.png", "wb") as f:
    f.write(fg_data)

print("Icons created:")
print("  assets/images/app_icon.png")
print("  assets/images/app_icon_foreground.png")
