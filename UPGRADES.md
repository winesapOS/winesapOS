# Upgrade Notes

## 2.1.0 to 2.2.0

**Action Required:**

- None.

**No Action Required:**

- The initramfs is updated with more storage device drivers to help with boot problems.
    - Refer to: https://github.com/ekultails/mac-linux-gaming-stick/issues/94

## 2.0.0 to 2.1.0

**Action Required:**

- The directory `/home/` has been converted into a Btrfs subvolume.
    - The original `/home/` directory has been renamed to `/homeUPGRADE/` and needs to be manually deleted.
    - All files have been copied from the old subvolume `/` to the new one `/home/`.

**No Action Required:**

- Btrfs mounts now use zstd compression and have TRIM/discard support enabled.
- Linux 5.4 kernel is installed as an alternative to the Linux 5.10 kernel.
- apple-bce drivers are updated.
- GRUB menu now shows up on boot.
- Heroic Games Launcher is installed for playing Epic Games Store games.
- smartmontools is installed for monitoring drive health.
- Shortcuts are added to the desktop for game launchers and the office suite.
- Proton-6.5-GE-2 is installed as an alternative Steam Play compatibility tool.
- Printer drives are installed.
