# Upgrade Notes

## 3.0.1 to 3.1.0

**Action Required:**

- None.

**No Action Required:**

- winesapOS now has a repository that is added.
- Temporary mounts switched from `ramfs` to `tmpfs` to support FUSE which is required by AppImage and Flatpaks.
- SteamOS 3.2 provides a new 'linux-firmware-neptune-rtw-debug' package that replaces 'linux-firmware'. This makes systems unbootable. The new package is now ignored and removed if detected.
- Upstream Arch Linux repositories are enabled since SteamOS has not updated their mirror Arch Linux packages since launch. This fixes various issues.
- ProtonUp-Qt is installed as a Flatpak instead of from the AUR due to build issues.
- Xbox controller support is added.
- AntiMicroX is installed to support configuring controllers.
- A simple text editor, kate, is installed.
- The GRUB menu is now updated after an upgrade to include new Btrfs snapshots.
- 'mesa' is replaced by 'mesa-steamos' which is a customized package of Mesa from SteamOS for support for all graphics drivers (not just AMD).

## 3.0.0 to 3.0.1

**Action Required:**

- None.

**No Action Required:**

- `makepkg` (used by `yay` to build packages) is configured to use all available cores for faster package builds.
- Pamac from the AUR is broken upstream and is fixed by installing an older version.

## 3.0.0-rc.0 to 3.0.0

**Action Required:**

- None.

**No Action Required:**

- The exFAT partition is updated with the "msdata" flag to allow it to be mounted on Windows automatically.

## 2.1.0 to 2.2.0

**Action Required:**

- None.

**No Action Required:**

- The initramfs is updated with more storage device drivers to help with boot problems.
    - Refer to: https://github.com/LukeShortCloud/winesapOS/issues/94
- Pacman is now configured to download up to 5 packages in parallel (instead of the default of 1).

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
- Printer drivers are installed.
