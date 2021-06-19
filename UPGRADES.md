# Upgrade Notes

## 2.0.0 to 2.1.0

- The directory `/home/` has been converted into a Btrfs subvolume.
    - The original `/home/` directory has been renamed to `/homeUPGRADE/` and needs to be manually deleted.
    - All files have been copied from the old subvolume `/` to the new one `/home/`.
