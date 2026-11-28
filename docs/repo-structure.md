# Repo Structure — MelDesktop3 NixOS flake

Full annotated map of every Nix file in this repo (i7-14700K + RTX 5070 Ti 16GB, NixOS-unstable).
Keep in sync when files are added/removed. See `../AGENTS.md` for commands and the model/mode system docs.

```
NIXOS/
│
├── flake.nix                    inputs: nixpkgs-unstable, home-manager, nix-flatpak,
│                                llama-cpp (ggml master, non-flake src), llama-cpp-ruby
│                                (local ruriww fork checkout). Injects pkgs-llama
│                                (separate CUDA 12.0 package set) via specialArgs.
├── configuration.nix            entry point: imports hardware-config + ./modules,
│                                MEMINI_HOME, programs.portableApps.enable, stateVersion 26.11
├── hardware-configuration.nix   generated (ext4 /, vfat /boot, swap, kvm-intel)
├── AGENTS.md · TODO.md
│
├── scripts/
│   ├── test.sh                  nixos-rebuild build (all 3 modes) + --update flag
│   └── deploy.sh                rsync → /etc/nixos, then nixos-rebuild switch (run0)
│
├── home/                        home-manager for melody (useGlobalPkgs, useUserPackages)
│   ├── melody.nix               ~100 user packages: JetBrains ×8, dev toolchains
│   │                            (rustup/bun/uv/dotnet), browsers ×3, Wine, creative,
│   │                            KDE apps, nix tooling (nixd/nil/statix) + git identity
│   │                            reuse from modules, bash, gh, ssh config
│   └── spotify.nix              Spotify flatpak (pkgs.spotify removed in 26.11)
│
└── modules/
    ├── default.nix              imports ALL modules in every mode (mode-gating is
    │                            inside each file via mkIf, never in imports)
    │
    ├── modes/                   ═══ THE CORE IDEA: 1 system, 3 boot entries ═══
    │   ├── specialisations.nix  meldesktop.mode option (normal|saver|headless) +
    │   │                        meldesktop.desktop bool + llm.fitTarget (1536/512/128
    │   │                        MiB --fit headroom) + llm.ttl (60s in normal only).
    │   │                        specialisation.saver/.headless = whole re-eval per mode
    │   ├── mode-command.nix     `mode` CLI: show / live-switch / once / boot <mode>
    │   │                        (switch-to-configuration test + bootctl set-oneshot/default)
    │   ├── saver.nix            session env = igpuEnv at login (Vulkan/GL→iGPU);
    │   │                        KWin systemd dropin UNsets it (drives the monitors)
    │   └── headless.nix         TTY autologin; nvidia kernel modules w/o nvidia_drm
    │                            (firmware fb keeps console) so CUDA works without Xorg
    │
    ├── system/                  ── core OS ──
    │   ├── nix.nix              24 jobs, 4 substituters (incl. nixos-cuda), no global
    │   │                        cudaSupport, gtk2-broken→warn, auto-optimise
    │   ├── boot.nix             systemd-boot, linuxPackages_latest (NTFS 7.1 driver),
    │   │                        coretemp + nct6683 sensors
    │   ├── users.nix            melody: wheel/networkmanager/i2c/input
    │   ├── locale.nix           America/Chicago, en_US.UTF-8
    │   ├── fonts.nix            Atkinson Hyperlegible + Noto, fontconfig tweaks
    │   ├── networking.nix       MelDesktop3, NetworkManager, firewall OFF, ssh+pw, warp
    │   └── audio.nix            PipeWire (alsa+pulse, rtkit)
    │
    ├── hardware/                ── peripherals ──
    │   ├── nvidia.nix           open driver, modesetting; overrideInstall pulls
    │   │                        MPS/nvidia-smi out of origBin; container toolkit
    │   ├── igpu.nix             meldesktop.intelIcd + meldesktop.igpuEnv (the tested
    │   │                        "off the dGPU" env: VK ICD + EGL mesa + DRI_PRIME);
    │   │                        `run-on-igpu` wrapper; intel-media-driver
    │   ├── firmware.nix         redistributable fw, intel microcode, fwupd
    │   ├── storage.nix          ntfs in initrd (ntfs3, after ntfs-driver EIO saga),
    │   │                        fuse, partition-manager, polkit rule (no auth prompts)
    │   ├── disks.nix            smartd (selftests 02:00 / monthly 03:00), nvme-cli,
    │   │                        btrfs-progs, compsize. 3 disks documented (btrfs migration pending)
    │   ├── bluetooth.nix        off at boot
    │   ├── printing.nix         CUPS
    │   ├── openrgb.nix          intel mobo, all-plugins, openrgb system user (i2c)
    │   ├── vr.nix               WiVRn (Quest 3)
    │   └── face-unlock.nix      howdy + IR emitter; PAM for kde/sddm/polkit, not sshd;
    │                            polkit-helper sandbox opened for the camera
    │
    ├── desktop/                 ── mkIf meldesktop.desktop (normal + saver) ──
    │   ├── plasma.nix           SDDM "aurora" theme (breeze + AURORA.jpg via
    │   │                        ./sddm/), Plasma 6, Xorg nvidia, KWallet PAM
    │   ├── flatpak.nix          flatpak + portals (portal-kde pkg stays in every mode)
    │   └── remote-desktop.nix   xrdp → second virtual Plasma X11 session
    │
    ├── programs/                ── software ──
    │   ├── cli-tools.nix            jq/ripgrep/fd/nixfmt/gpg/android-tools/archivers…
    │   ├── git.nix                /etc/gitconfig (Melody) + /etc/git-m2.conf (M²)
    │   ├── apps.nix               firefox, steam, kdeconnect, onedrive
    │   └── claude-desktop/        official .deb repackaged (vendored from poeck's
    │       ├── default.nix            flake; mkIf desktop; perl-patches app.asar
    │       ├── package.nix            for OVMF/virtiofsd paths)
    │       └── update.sh              bumper (reads Anthropic's apt Packages)
    │
    ├── compat/                  ── non-Nix software ──
    │   ├── portable.nix           defines programs.portableApps: ~90-lib nix-ld set
    │   │                          (+ NVML from the live driver) + `run-portable` wrapper
    │   ├── appimage.nix           binfmt, appimage-run, bubblewrap, gdbus
    │   └── usr-share-mounts.nix   bindfs ro mounts /usr/share/{fonts,icons,themes}
    │
    ├── docs/                    llama-server --help, llama-swap example YAML,
    │                            storage-migration runbook
    │
    └── llm/                     ═══ BIGGEST SUBSYSTEM: 1 catalog → 2 consumers ═══
        │
        ├── models/              ★ PLAIN DATA (not a module). Port 9930.
        │   ├── presets.nix      6 preset factories → full spec:
        │   │                      model        (APEX-I-NanoPlus coder, ctx 262144, kvq q8_0)
        │   │                      valV3        (27B dense hybrid, 128K fitCtx, self-MTP)
        │   │                      flashNext    (thinking OFF, budget 4096, +xhigh)
        │   │                      tieredModel  (ruriww fork serve.sh, ~94 GiB NVMe-MoE)
        │   │                      titleModel   (tiny iGPU, presence penalty)
        │   │                      voiceModel   (cpu|cuda, vramMiB claim, ttl, taskset)
        │   ├── models.nix       31 models in 3 llama-swap groups:
        │   │                        cpu  ×1   voice-Qwen3.5-4B
        │   │                        vram ×28  4×Tiel/Cyber · 7×Qwen3.8-27B VAL-V3
        │   │                                 (+4 Huihui/Swift/TTURBO/Coder390 abliterated)
        │   │                                 · Flash-Coder/Next/Tiered · 3×MiniCPM-V
        │   │                                 · 2×Occamy · Xing · Qwen3.6 · LFM · Ornith
        │   │                                 · Sage · Flint · KAT · Thomson · T-Search
        │   │                                 · voice-gpu-gemma-4-12b
        │   │                        igpu ×2   Qwen3.5-2B / -0.8B (titles, ttl 120s)
        │   ├── profiles.nix     8 selector profiles (llama-swap selectors ≡ OpenCode
        │   │                      models): coder · coder-unsafe · coder-mtp · moe ·
        │   │                      hybrid · hybrid-unsafe · title · voice (fit+no_evict)
        │   └── default.nix      resolver: derived tags, match/prefer/fallback → targets,
        │                        effort union rules, dupe-id assert, virtual profile specs
        │
        ├── llama-swap/          (every mode; the "how politely" part)
        │   ├── default.nix        settings from catalog: models+selectors+routing
        │   │                      (capacity router, vram pool 16000 MiB, coders
        │   │                      evict_cost 100). Normal mode filters the GPU voice
        │   │                      model out. VK_ICD env for the service;
        │   │                      /var/lib/llm-models tmpfiles dir. Build-time
        │   │                      `llama-swap -validate` schema check.
        │   ├── helpers.nix      llama.cpp builds: unified CUDA+Vulkan+ALL_CPU_VARIANTS
        │   │                      (upstream .devops/nix scope) + fork as ruby-llama-*;
        │   │                      ruby-serve-<id> wrappers around the fork's serve.sh;
        │   │                      spec→entry per kind (coder/title/voice/tiered) — all
        │   │                      the llama-server flags (-fit, -fitt, mtpFlags, taskset…)
        │   ├── package.nix        llama-swap v277 override (need fit/capacity ≥v273;
        │   │                      nixpkgs at v268). Bump instructions inline.
        │   └── TODO.md
        │
        └── opencode/            (generates ~/.config/opencode/opencode.json, schema-validated)
            ├── default.nix        wires HM programs.opencode + secrets/{file:} convention
            ├── settings.nix       the json as Nix: model llama-swap/coder#medium, 9 plugins,
            │                      HA + ha-mcp + gh_grep MCP, 9 references, compaction
            ├── providers.nix      llama-swap provider (discovery OFF): all 31 models +
            │                      8 profiles as models, #low/#medium/#high/#xhigh/#noreasoning
            │                      variants from each spec's efforts. Plus llama-server:9931
            │                      (discovery ON) sidecar provider.
            ├── permissions.nix    last-match-wins rules + `guards` appended to every agent
            │                      (AGENTS.md/config/secrets/git push) + 5 M2 agents
            │                      (M2.0 Isolated → M2.5 ⚠️‼️)
            └── serve.nix          headless-only: `opencode serve` on 127.0.0.1:4096
                                   (reach via ssh -L)
```

## The three mental models

1. **Modes as specialisations** — `meldesktop.mode` is set per specialisation; every other
   module just `mkIf`s on it (or on `meldesktop.desktop`). `normal` = ghost LLM,
   `saver` = session on iGPU, `headless` = TTY + CUDA + services at boot.
2. **One catalog, two consumers** — `llm/models/` is pure data; `llama-swap/helpers.nix`
   turns specs into llama-server flags, `opencode/providers.nix` turns the same specs into
   OpenCode models + variants. They can never drift.
3. **Everything validated at build time** — llama-swap settings via `-validate`,
   opencode.json via `validateFiles.config`, profile targets asserted in `default.nix`.
