# Upgrade Notes

## 3.2.1 to 3.3.0

**Action Required:**

- None.

**No Action Required:**

- 'base-devel' is manually upgraded.
- 'pacman' is manually upgraded to deal with the [community] repository being merged into the [extra] repository.
- Packages are now installed from the renamed [holo-rel] repository instead of the original [holo] repository.
- 'steamdeck-kde-presets' is now replaced by 'vapor-steamos-theme-kde'.
- 'nano' is set as the default text editor.
- 'pipewire' is now split into two packages: 'pipewire' and 'libpipewire'.
- Pacman support is added to the Discover package manager.

## 3.2.0 to 3.2.1

**Action Required:**

- None.

**No Action Required:**

- The "Steam Deck Client" is changed from the "beta" to "stable" update channel.
- The SteamOS repositories now use the new SteamOS 3.4 names.

## 3.1.1 to 3.2.0

**Action Required:**

- None.

**No Action Required:**

- 'linux-neptune' is replaced by 'linux-steamos'.
- Flatseal is installed.
- GParted is installed.
- 'game-devices-udev' is installed.
- Pamac is replaced by bauh.
- 'broadcom-wl' is installed.
- 'mbpfan-git' is installed.

## 3.1.0 to 3.1.1

**Action Required:**

- None.

**No Action Required:**

- 'pipewire-media-session' is replaced by 'wireplumber'.
- Vimix theme for GRUB is installed.

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
- 'clang-libs' is replaced by 'clang' which is a newer version from Arch Linux.
- The remote upgrade script itself is now always updated for smoother upgrades.
- Ignored packages such as Linux kernels and GRUB will now be updated.
- Mac drivers are now re-installed for the newer Linux kernels.
- NVIDIA graphics drivers will now be updated.
- All system packages will now be upgraded as part of winesapOS upgrades.

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
