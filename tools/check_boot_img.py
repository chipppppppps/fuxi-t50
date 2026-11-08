"""Read an Android boot image header (v0..v3) and print what the loader will see."""
import hashlib
import struct
import sys
import zlib
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
    kernel = data[offset:offset + kernel_size]
    tail = data[offset + kernel_size:]
    try:
        plain = zlib.decompress(kernel, 47)
        wrapper = "gzip" if kernel[0] == 0x1F and kernel[1] == 0x8B else "zlib"
        print(f"inflated        {len(plain):,} bytes  ({wrapper})")
        print(f"FUXIESP label   {b'FUXIESP' in plain}")
    except zlib.error as error:
        print(f"inflate failed  {error}")
    print(f"tail            {len(tail):,} bytes  (dtb: {tail[-4096:][:4] == b'd00d'})")


if __name__ == "__main__":
    main(sys.argv[1])
