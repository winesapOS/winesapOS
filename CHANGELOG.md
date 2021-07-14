# Change Log

## 2.1.0

- Change swap to be a file instead of a partition.
- Change and lower swap size from 8 GiB to 2 GiB.
- Remove/disable swap in the live installation environment.
- Add automatic logging for the installation script into the build.
- Add integration tests for all existing functionality.
- Add an upgrade script.
- Add a Btrfs subvolume for '/home' and a related upgrade.
- Add Btrfs compression with zstd and also TRIM/discard support to mounts along with a related upgrade.
- Change 'apple-bce' driver installation to be more reliable.
- Add start and end time to the install log file.
- Add Linux 5.4 as an alternative LTS kernel to 5.10.
- Change GRUB menu to show on boot.
- Add Heroic Games Launcher for Epic Games Store games.
- Change partition mounts from UUIDs to labels.
- Add desktop shortcuts.
- Add Proton GE package manager 'ge-install-manager' and Proton GE 6.5-2.
- Add 'protontricks'.
- Add Snapper configuration for '/home' backups/snapshots.
- Add 16 GB exFAT partition for normal flash drive usage.
- Add PulseAudio configuration to lower the volume which will helps Mac users.
- Add printer drivers and service.

## 2.0.0

- Change from Ubuntu 20.04 to Manjaro.
- Add automated installation script for Manjaro.
- Add script and service to automatically resize the root partition on first boot.
- Add fast/optimized package manager mirrors.
- Add automatic configuration of the 'stick' and 'root' users.
- Change from 'apt-btrfs' to 'snapper' and 'snap-pac' for Btrfs backups.
- Add MacBook Bridge/T2 driver.
- Add GameMode.
- Add autocpu-freq to help battery life.
- Change README file to be more consolidated.
- Remove Ansible roles.
- Add VERSION file.
- Add minimum and recommended requirements.

## 1.2.1

- Add note about CrossOver Mac being based on an old version of Wine.
- Change the percentage of supported 64-bit games on macOS. It has increased.
- Change the percentage of supported Windows games on Linux. It has increased.

## 1.2.0

- Add support for built-in speakers on newer Macs.
- Change the percentage of supported 64-bit games on macOS. It has increased.
- Add notes about CrossOver Mac.
- Remove support for all distros except for Ubuntu.
- Add a changelog.
- Remove notes about installing a newer Linux kernel. Ubuntu 20.04.2 now ships a usable Linux kernel (5.8).
- Change the percentage of supported Steam games on Linux. It has increased.
- Add notes about the Apple M1 Arm-based processor.

## 1.1.0

- Add the missing supportability goal.
- Add notes on addressing wireless keyboard and mouse issues.

## 1.0.0

- Initial release.
