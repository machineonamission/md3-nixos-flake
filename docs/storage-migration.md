# Storage migration: ext4 / BitLocker-NTFS -> btrfs

Status: **Phase 0 done** (2026-11-26). Each phase leaves a working system; tick them off here.

## Target layout

| Disk | Now | Target |
|---|---|---|
| 990 Pro 2TB `nvme0n1` | p1 ESP 1G, p2 ext4 `/` 1.8T, p3 swap 34G | p2 -> btrfs (zstd:1), converted in place, swap partition kept |
| 960 EVO 1TB `nvme1n1` | ESP, /boot, Fedora LUKS 635G, Windows-data NTFS 294G | wiped -> one btrfs `/scratch` (disposable, `nofail`) |
| WD Red 8TB `sda` | sda1 MSR 16M, sda2 BitLocker -> NTFS | one partition, LUKS2 -> btrfs, **data dup + metadata dup**, `/mnt/hdd` |

Why not merge the SSDs into one volume: no mainline filesystem fills the 990 first and then
spills onto the 960 (btrfs `single` allocates to whichever device has the most free space;
ext4/XFS on LVM spread across the whole address space), and doing it would make `/` depend on
the untrusted drive. bcachefs targets could do it, but bcachefs has been out of tree since 6.17.

## Phase 0 findings (2026-11-26)

Drive health (udisks SMART, readable without root):

| | power-on h | written | % used | media errors | unsafe shutdowns | notes |
|---|---|---|---|---|---|---|
| 990 Pro | 3 012 | 163 TB | 12 % | 0 | 83 | healthy; heavy writes (models / nix builds) |
| 960 EVO | 17 995 | 90 TB | 11 % | 0 | 287 | healthy on paper, 30 700 error-log entries (usually harmless unsupported-cmd noise on Samsung) |
| WD Red 8TB | 2 857 | - | - | 0 realloc / 0 pending / 0 uncorrectable | - | clean |

- `/` = 1.3T used: ~/.cache 329G (**huggingface 258G**, uv 18G, JetBrains 16G, appimage-run 13G),
  ~/.local/share 160G (**Steam 105G**, baloo 19G). Those are the first things to move to /scratch.
- 960 p4 (NTFS, 267G used) is **not a bootable Windows**: it has no `Windows` dir and its ESP only holds
  Fedora shim/grub. It is old C:/D: data. It is backed up on the HDD as `Windows-Old/` (robocopy
  of D:, 260 GB, 0 failed files, 2026-09-27) and also as `old ssd/`.
- So **Phase 2 needs a Windows USB** (no Windows install left on any disk).
- btrfs-progs 7.3: `btrfs-convert --uuid copy` exists. ntfs2btrfs is in nixpkgs, but we don't use it.
- smartd, btrfs-progs, compsize and nvme-cli added in `modules/hardware/disks.nix`.

## Phase 1: clean up the HDD (still NTFS), in progress 2026-11-26

Done so far:
- Indexed the drive from a raw `$MFT` dump (`sudo nix shell nixpkgs#sleuthkit --command icat <dev> 0 > hdd.mft`,
  parsed with a small Python script): 9.16M files, 3.01 TB. That's far faster than `du` on the HDD.
- Reorganized into `Personal/<type>/<machine>/`, `Projects/<machine>/`, `Devices/`, `Phones/`,
  `Exports/`, `Games/`, `Media/`. Nothing deleted: system files, caches, re-downloadables
  (Steam, LM Studio, Docker/WSL) and duplicate copies are in `_REVIEW/<reason>/<original path>`.
  Every move is logged (when, from, to) in `/_REORG-LOG.tsv` and `/_REVIEW/MANIFEST.tsv`, so any of them can be undone.
- Next: hash-verified dedupe of the kept trees into `_REVIEW/duplicates/`, then the user reviews
  and empties `_REVIEW`.

Original notes:
Goal: used < ~3.3T (dup needs 2x), smaller is faster. Tools: `nix run nixpkgs#czkawka`
(duplicates, GUI), Filelight. Candidates: `Windows-Old/` vs `old ssd/` (same source?),
`Windows-2026-09-26/` (robocopy of the previous C:), `ext4 backup/`, `babup/`, `$RECYCLE.BIN`, `.Trash-1000`, `found.000`.

## Phase 2: shrink the BitLocker volume (Windows USB)
1. Have the BitLocker password/recovery key at hand.
2. Boot a Windows install USB -> Repair -> Command Prompt (or Hiren's BootCD PE).
3. `manage-bde -status`, then `manage-bde -unlock X: -pw` (or `-rp <recovery key>`)
4. `diskpart` -> `list volume` -> `select volume X` -> `shrink querymax`, then
   `shrink desired=<MB>` down to about used + 10 %. If querymax is too small (unmovable files), boot back,
   delete more / defrag in Windows, and retry.
5. Back in Linux, check that the HDD still unlocks and mounts as before.

## Phase 3: new filesystem in the freed tail
```bash
# as root; X = start of free space (parted print free)
parted /dev/sda -- mkpart hdd-new X 100%                         # -> sda3
install -d -m 0700 /etc/secrets
(umask 077; dd if=/dev/urandom of=/etc/secrets/hdd.key bs=64 count=1) && chmod 0400 /etc/secrets/hdd.key
cryptsetup luksFormat --type luks2 /dev/sda3                     # passphrase (backup way in)
cryptsetup luksAddKey /dev/sda3 /etc/secrets/hdd.key
cryptsetup open /dev/sda3 hdd --key-file /etc/secrets/hdd.key
mkfs.btrfs -L hdd -d single -m dup /dev/mapper/hdd
mount -o compress=zstd:3,noatime /dev/mapper/hdd /mnt/hdd
rsync -aHAX --info=progress2 /run/media/melody/HDD/ /mnt/hdd/ \
  --exclude '/System Volume Information' --exclude '/$RECYCLE.BIN'
rsync -rcn --itemize-changes /run/media/melody/HDD/ /mnt/hdd/ \
  --exclude '/System Volume Information' --exclude '/$RECYCLE.BIN'   # must print nothing
```
Store the LUKS passphrase in a password manager; also keep a copy of `/etc/secrets/hdd.key`
somewhere off this machine (losing both = losing the HDD).

## Phase 4: take over the whole disk
```bash
# unmount + lock the BitLocker volume first
parted /dev/sda -- rm 2 rm 1                                     # BitLocker + MSR gone
parted /dev/sda -- mkpart hdd 1MiB <start-of-sda3>               # new front partition (-> sda1)
cryptsetup luksFormat --type luks2 /dev/sda1 && cryptsetup luksAddKey /dev/sda1 /etc/secrets/hdd.key
cryptsetup open /dev/sda1 hdd-front --key-file /etc/secrets/hdd.key
btrfs device add /dev/mapper/hdd-front /mnt/hdd
btrfs device remove /dev/mapper/hdd /mnt/hdd                    # moves all data, online, hours
cryptsetup close hdd && parted /dev/sda -- rm 3 resizepart 1 100%
cryptsetup resize hdd-front && btrfs filesystem resize max /mnt/hdd
btrfs balance start -dconvert=dup -mconvert=dup /mnt/hdd        # many hours, online
```
Then switch `disks.nix` to the final LUKS UUID (Phase 5) and reboot.

## Phase 5: NixOS config for the HDD
In `modules/hardware/disks.nix`: crypttab entry (keyfile `/etc/secrets/hdd.key`, `nofail`), `fileSystems."/mnt/hdd"`
(`compress=zstd:3,noatime,nofail`), `services.btrfs.autoScrub`. Drop the BitLocker parts of `storage.nix`.

## Phase 6: 960 -> /scratch
`wipefs -a` every partition, then one GPT partition and `mkfs.btrfs -L scratch -m dup`, then `fileSystems."/scratch"`
(`compress=zstd:1,noatime,nofail`). Move `~/.cache/huggingface` (set `HF_HOME`), the Steam library (add as a
Steam library folder), and anything else that can be re-downloaded.

## Phase 7: convert / in place
1. Copy `/home` (without `.cache`) to `/mnt/hdd/backup/home-preconvert`.
2. In `hardware-configuration.nix`, set `/` to `fsType = "btrfs"`, `options = [ "compress=zstd:1" "noatime" ]`. Then `nixos-rebuild boot`.
3. Boot the NixOS live USB: `e2fsck -f /dev/nvme0n1p2 && btrfs-convert --uuid copy /dev/nvme0n1p2`, then reboot.
   (Rollback while `ext2_saved` exists: `btrfs-convert -r`, then boot the previous generation.)
4. Once happy: `btrfs subvolume delete /ext2_saved`, `btrfs balance start -m /`,
   optionally `btrfs filesystem defragment -r -czstd /` (before any snapshots exist).
5. Optional: give /home its own subvolume, so it can be snapshotted separately.

## Phase 8: backups
`services.btrbk`: snapshots of /home on the 990 and a daily `btrfs send` to `/mnt/hdd/backup`.
