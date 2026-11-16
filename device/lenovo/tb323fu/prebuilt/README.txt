prebuilt/kernel — Lenovo TB323FU AERA recovery kernel
=====================================================

Source : TB323_ZUXOS_2.0.12.088_Tool/image/vmlinux (ELF, with debug info)
Format : raw ARM64 Image (not ELF)
Size   : 39,956,480 bytes (0x261b000)
Header : magic at 0x38 = "ARM\x64"; image_size = 0x26d0000
SHA256 : 34a518bd71f4dee12814fa78434dcba1c536bc009e4a0f1c48e2a66c15ced96f

Linux version / vermagic:
  6.12.30-android16-5-maybe-dirty-4k

Why this file exists (and why it is optional):
  Stock recovery.img has kernel_size = 0; recovery mode runs on the kernel
  from the boot partition.  That boot kernel is
  6.12.30-android16-5-g1750f757fabe-ab13938768-4k, while vendor_dlkm modules
  are tagged 6.12.30-android16-5-maybe-dirty-4k.
  That difference is NOT a load failure: with CONFIG_MODVERSIONS=y and a
  module __versions section, same_magic() skips everything before the first
  space and compares only " SMP preempt mod_unload modversions aarch64";
  symbol CRCs enforce ABI compatibility.  The stock boot kernel therefore
  loads the stock modules unchanged.
  This Image is kept only for reference or an intentional boot-kernel
  experiment; it is not packed into recovery.img and is not needed for the
  normal AERA port.  Never patch vermagic or bundle vendor .ko files.

Regenerate:
  python3 tools/make_kernel_image.py <image/vmlinux> prebuilt/kernel

Note:
  Recovery is kernel-less (BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true)
  and runs on the stock boot kernel.  Do not put vendor .ko files next to
  this Image; AERA mounts /vendor and /vendor_dlkm and loads the live
  firmware modules from those partitions.
