#!/usr/bin/env python3
#
# Rebuild the bootable ARM64 Image from the firmware's vmlinux ELF.
#
# The TB323_ZUXOS_2.0.12.088 package ships:
#   image/vmlinux  -> ELF with debug info, vermagic 6.12.30-...-maybe-dirty-4k
#   image/boot.img -> a different 6.12.30-...-g1750... build
# vendor_dlkm/vendor_boot modules match vmlinux, so this script produces the
# Image that must be used as TARGET_PREBUILT_KERNEL (and inside recovery.img).
#
# Usage:
#   tools/make_kernel_image.py <vmlinux> <out/Image>
#
import struct
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: make_kernel_image.py <vmlinux> <out/Image>", file=sys.stderr)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        eh = f.read(64)
        if eh[:4] != b"\x7fELF" or eh[4] != 2 or eh[5] != 1:
            print(f"{src}: not a little-endian ELF64 file", file=sys.stderr)
            return 1

        e_phoff = struct.unpack("<Q", eh[32:40])[0]
        e_phentsize = struct.unpack("<H", eh[54:56])[0]
        e_phnum = struct.unpack("<H", eh[56:58])[0]
        f.seek(e_phoff)
        ph = f.read(e_phentsize * e_phnum)

        loads = []
        for i in range(e_phnum):
            p = ph[i * e_phentsize:(i + 1) * e_phentsize]
            p_type = struct.unpack("<I", p[0:4])[0]
            if p_type != 1:  # PT_LOAD
                continue
            p_offset, p_vaddr, p_paddr, p_filesz, p_memsz = struct.unpack(
                "<QQQQQ", p[8:48]
            )
            loads.append((p_offset, p_vaddr, p_paddr, p_filesz, p_memsz))

        if not loads:
            print(f"{src}: no PT_LOAD segments", file=sys.stderr)
            return 1

        base = min(paddr for _, _, paddr, _, _ in loads)
        image = bytearray()
        for off, _vaddr, paddr, filesz, _memsz in sorted(loads, key=lambda x: x[2]):
            image_off = paddr - base
            if len(image) < image_off:
                image.extend(b"\x00" * (image_off - len(image)))
            f.seek(off)
            data = f.read(filesz)
            image[image_off:image_off + filesz] = data

    if image[0x38:0x3C] != b"ARM\x64":
        print("warning: output does not carry the ARM64 Image magic", file=sys.stderr)
    with open(dst, "wb") as out:
        out.write(image)
    print(f"wrote {dst}: {len(image)} bytes (0x{len(image):x})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
