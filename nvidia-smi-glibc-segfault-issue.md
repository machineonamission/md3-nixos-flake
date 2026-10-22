# nvidia-smi segfaults (SIGSEGV, exit 139) after a glibc bump — regression in nixpkgs `nixos-unstable`

> Submitting from a user. Preflight diagnostics / build log attached below.

## Summary

`nvidia-smi` crashes with a segmentation fault on **every** invocation on a freshly
built `nixos-unstable` system. The crash appeared after a `nix flake update` that
bumped `glibc` from `2.44-25` to `2.44-57` (and pulled the rest of `nixpkgs` along
with it). Rolling `nixpkgs-unstable` back one commit restores a working `nvidia-smi`.

The NVIDIA driver package is **identical** in both cases (`nvidia-x11-615.78.08-bin`),
so this is not a driver-version change — it is the `glibc` rebuild.

## Environment

| | working | broken |
| --- | --- | --- |
| nixpkgs-unstable commit | `fe13242281a67641c0102cdb1087f0ebe586c7df` (2026-10-15) | `02c087f3fe673c9e317f206a627cb6b910336dbe` (2026-10-20, tip) |
| glibc | `2.44-25` | `2.44-57` |
| nvidia driver | `nvidia-x11-615.78.08-bin` | `nvidia-x11-615.78.08-bin` (same) |
| NVIDIA-SMI / KMD / CUDA UMD | 615.78.08 / 615.78.08 / 13.4 | 615.78.08 / 615.78.08 / 13.4 (same) |
| GPU | NVIDIA GeForce RTX 5070 Ti | same |
| kernel modules loaded | `nvidia`, `nvidia_drm`, `nvidia_modeset`, `nvidia_uvm` | same |
| `nvidia-smi` result | **rc=0**, full report | **rc=139** (SIGSEGV) |

Host: `MelDesktop3` (NixOS, `nixos-unstable`, desktop + KDE).

## Reproduction

```bash
# on a system built from the current nixpkgs-unstable tip (02c087f):
$ nvidia-smi
# SIGSEGV, exit code 139. Every program that calls nvidia-smi crashes the same way.
```

## What I verified

1. `nvidia-smi` on the live system returns rc=139 (segfault) on every run.
2. Built the same configuration pinned to the previous commit
   (`fe13242281`, glibc `2.44-25`): `nvidia-smi` returns rc=0 and prints the full
   GPU/Memory/Process report for the RTX 5070 Ti.
3. The `nvidia-x11` binary package is byte-for-byte the same driver version
   (`615.78.08-bin`) in both builds — only `glibc` changed.

## Workaround (works)

Pin `nixpkgs-unstable` back to the last working commit until upstream fixes it:

```nix
# flake.nix
nixpkgs-unstable.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
```

then `nix flake update nixpkgs-unstable` and `nixos-rebuild switch`.

## Why I'm filing here

This looks like a regression introduced by the `glibc` 2.44-25 → 2.44-57 rebuild in
`nixpkgs`, breaking NVIDIA's precompiled `nvidia-smi` userspace tool. It may be:

- an glibc `ld.so` / dynamic-linker change that crashes this prebuilt binary, or
- NVIDIA's `nvidia-smi` refusing the newer glibc build (a version check), or
- a `patchelf`/loader interaction specific to the Nix store layout.

If the maintainers think the real home is NVIDIA's bug tracker instead of nixpkgs,
this report can be moved / cross-referenced.

## Known recurrence

The same crash has been reported outside NixOS as a recurring pattern whenever
glibc is bumped past the version NVIDIA prebuilt their tools against:

- Nonguix #350 — "nvidia-smi currently segfaults" (notes "glibc has been updated",
  possibly a `patchelf` issue too)
- Arch Linux forums — same `nvidia-smi` segfault avoided by not updating glibc

## Expected behavior

`nvidia-smi` should run and report GPU state with the driver installed, without
segfaulting, after a routine `nix flake update`.
