# nvidia-smi crashes with SEGV in glibc dynamic linker (`dl_main`) under glibc 2.44-57

**Status:** Workaround applied (pin glibc back to `2.44-25`). Root cause is a glibc dynamic-linker regression.

## Summary

`nvidia-smi` (from NVIDIA driver package `615.78.08`, open driver, `branch=bleeding_edge`) crashes with a segmentation fault at process startup under NixOS **glibc `2.44-57`**. It works under **glibc `2.44-25`**.

The crash is a **glibc dynamic-linker bug**, not an NVIDIA driver bug: the dynamic linker (`ld-linux-x86-64.so.2`) faults in `dl_main` while processing nvidia-smi's ELF program headers. The regression was introduced by a change in the glibc 2.44 series — a later `2.44-master.patch` level (`2.44-57` vs the working `2.44-25`).

## Environment

| Item | Value |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5070 Ti |
| Driver | `nvidia` `615.78.08` (open driver, `branch=bleeding_edge`) |
| OS | NixOS, `nixpkgs-unstable` (bleeding edge) |
| Crashing glibc | `2.44-57` — `/nix/store/pqyiidz5mi73wv5f91d48s9plcqyj5bz-glibc-2.44-57` |
| Working glibc | `2.44-25` — `/nix/store/h4wfwic161kxrr74jlzla5lsm28hgary-glibc-2.44-25` |
| Binary | `/nix/store/liy6bd3ijqgc7pnr8mfh4zx6cig7fr8h-nvidia-x11-615.78.08-bin/bin/nvidia-smi` (non-PIE, EXEC) |

## Reproduction

```console
$ nvidia-smi --version
Segmentation fault (core dumped)          # rc = 139
```

Works fine when the system is built with glibc `2.44-25`.

## Crash signature (from systemd-coredump / `coredumpctl`)

```
Signal: 11 (SEGV)   si_code: SEGV_ACCERR
Command Line:       nvidia-smi
Executable:         /nix/store/...-nvidia-x11-615.78.08-bin/bin/nvidia-smi
ELF object binary architecture: AMD x86-64

Stack trace of thread:
#0  dl_main             (ld-linux-x86-64.so.2 + 0x25a74)   [glibc-2.44-57]
#1  _dl_sysdep_start     (ld-linux-x86-64.so.2 + 0x22630)
#2  _dl_start            (ld-linux-x86-64.so.2 + 0x23ee1)
#3  _start                (ld-linux-x86-64.so.2 + 0x22be8)
```

`SEGV_ACCERR` = protection fault — the process tried to **write to a page that is not writable**.

## Root cause (investigated)

The dynamic linker writes to address `0x401568` during `dl_main`, and that address lands **inside nvidia-smi's own read-only LOAD segment** `[0x400000, 0x404000)` (flags = R). nvidia-smi is a non-PIE EXEC binary whose first LOAD segment VirtAddr is `0x3ff000`. The linker's reformatting/relocation logic in `dl_main` (changed between glibc `2.44-25` and `2.44-57`) attempts to write into that read-only segment and faults.

Key points:

- **The driver never changed.** Driver `615.78.08` and its upstream blob are identical across the working and crashing builds; the only variable is the glibc version.
- The regression is **in glibc itself**. glibc `2.44-57` applies ~33 more `2.44-master.patch` commits than `2.44-25`, including dynamic-linker fixes. One of these reintroduced/triggered the `dl_main` behavior that faults on this binary's program-header layout.
- This is a **glibc bug triggered by a non-PIE binary with a specific program-header layout** (a read-only LOAD segment sitting near the executable base, where the linker's fixup pointer lands).

## Evidence

1. Core dump from the affected system shows the fault in `dl_main` of glibc `2.44-57`'s `ld-linux-x86-64.so.2` (signature above).
2. The affected binary crashes (`rc = 139`, core dumped) when run under glibc `2.44-57`.
3. The same binary runs cleanly (`rc = 0`, prints the full `nvidia-smi --version` output) under glibc `2.44-25`.
4. The current active system profile (`MelDesktop3-26.11.20261015.fe13242`, pinned to nixpkgs `fe13242281`, glibc `2.44-25`) runs `nvidia-smi --version` successfully:

   ```
   NVIDIA-SMI version  : 615.78.08
   NVML version        : 615.78
   DRIVER version      : Deprecated, see "KMD version" instead
   CUDA version        : Deprecated, see "CUDA UMD version" instead
   KMD version         : 615.78.08
   CUDA UMD version    : 13.4
   (rc = 0)
   ```
5. Driver blob `sha256` is identical across the working and crashing commits, confirming the driver / nvidia-smi binary is not the cause.

## Workaround / fix

Pin glibc (or nixpkgs) back to the last working version (glibc `2.44-25`).

In `flake.nix`, pin `nixpkgs-unstable` to the last-working commit:

```nix
inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
```

…then `nix flake lock --update nixpkgs-unstable && nixos-rebuild switch`.

Or do a **targeted glibc-only pin** via `overrideInputs` on the nixpkgs input, pointing glibc to the `2.44-25` commit.

This has already been applied: the current `flake.lock` pins `nixpkgs-unstable → fe13242281`, and `nvidia-smi` works again.

## Suggested next steps for maintainers

- Bisect the glibc `2.44` branch (or the NixOS `2.44-master.patch` set) between the `2.44-25` and `2.44-57` levels to find the exact commit that introduced the `dl_main` regression.
- The upstream glibc dynamic-linker fix that changed this behavior is the likely culprit; a point release pinning that specific fix (or reverting it) would resolve the crash without a full revert.

## Where to file

- **NixOS-specific angle** (which `2.44-master.patch` level regressed): [`github.com/NixOS/glibc`](https://github.com/NixOS/glibc/issues).
- **Underlying bug** (dynamic linker writing to a read-only segment on non-PIE binaries): upstream glibc — bugzilla [`sourceware.org/bugzilla`](https://sourceware.org/bugzilla/) / [`github.com/bminor/glibc`](https://github.com/bminor/glibc).
