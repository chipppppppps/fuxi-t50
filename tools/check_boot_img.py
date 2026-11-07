"""Read an Android boot image header (v0..v3) and print what the loader will see."""
import hashlib
import struct
import sys
from pathlib import Path

MAGIC = b"ANDROID!"


def main(path):
    data = Path(path).read_bytes()
    assert data[:8] == MAGIC, f"not a boot image: {data[:8]!r}"
    kernel_size = struct.unpack_from("<I", data, 8)[0]
    ramdisk_size = struct.unpack_from("<I", data, 16)[0]
    os_version = struct.unpack_from("<I", data, 20)[0]
    header_size = struct.unpack_from("<I", data, 24)[0]
    header_version = struct.unpack_from("<I", data, 40)[0]
    cmdline = data[44:44 + 1536].split(b"\x00", 1)[0].decode("ascii", "replace")
    print(f"file            {len(data):,} bytes")
    print(f"sha256          {hashlib.sha256(data).hexdigest()}")
    print(f"header_version  {header_version} (header_size {header_size})")
    print(f"kernel          {kernel_size:,} bytes  {kernel_size / 1024 / 1024:.1f} MiB")
    print(f"ramdisk         {ramdisk_size:,} bytes  {ramdisk_size / 1024 / 1024:.1f} MiB")
    print(f"os_version      0x{os_version:08x}")
    print(f"cmdline         {cmdline!r}")
    if header_version < 3:
        raise SystemExit("this packer is expected to write header v3")
    page = 4096
    offset = page
    body = len(data) - offset
    print(f"body            {body:,} bytes")
    print(f"sizes agree     {body == kernel_size + ramdisk_size}")
    # the payload is a raw FAT image: look for its volume label near the start
    payload = data[offset + kernel_size:offset + kernel_size + ramdisk_size]
    print(f"ramdisk head    {payload[:16]!r}")
    print(f"FUXIESP label   {b'FUXIESP' in payload[:65536]}")


if __name__ == "__main__":
    main(sys.argv[1])
