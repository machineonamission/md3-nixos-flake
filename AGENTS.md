This is the full NixOS-unstable flake config for MelDesktop3 (single host).

This repo is not /etc/nixos, but both track the same GitHub upstream, so this
copy is for testing and /etc/nixos for deploying. Deploying needs root and is
done by the user.

## Layout

```
flake.nix               inputs + the one nixosConfigurations.MelDesktop3
configuration.nix       host entry point (imports, a few host vars, stateVersion)
hardware-configuration.nix   generated, do not edit
modules/                one concern per file; the file name says what's in it.
  default.nix           imports every module (all modes), grouped + annotated
  modes/                boot modes (see below)
    specialisations.nix   meldesktop.mode/desktop/llm options + the specialisations
    mode-command.nix      the `mode` show/switch CLI
    saver.nix             (saver) session env off the dGPU, KWin exempt
    headless.nix          (headless) TTY autologin + NVIDIA-for-CUDA without Xorg
  system/               nix.nix (daemon, substituters, nixpkgs.config), boot.nix
                        (bootloader, kernel, kernel modules), memory.nix (zram swap,
                        reclaim sysctls, user.slice MemoryLow), users, locale, fonts,
                        networking (hostname/NM/firewall/ssh/warp), audio (pipewire)
  hardware/             nvidia.nix, igpu.nix (meldesktop.igpuEnv/intelIcd options,
                        run-on-igpu), firmware, storage (ntfs/fuse), bluetooth,
                        printing, openrgb, vr (wivrn), face-unlock (howdy),
                        disks.nix (the 3 internal disks: smartd, btrfs tools, mounts)
  desktop/              (mkIf desktop) plasma.nix (SDDM + aurora theme in sddm/,
                        Plasma, Xorg, kwallet), flatpak.nix, remote-desktop.nix (xrdp)
  programs/             cli-tools.nix (systemPackages), git.nix (system git identity),
                        apps.nix (firefox, steam, kdeconnect, onedrive)
                        claude-desktop/ (desktop; official .deb repackaged, vendored
                        from poeck/claude-desktop-nix-flake; bump with its update.sh)
  compat/               non-Nix software: portable.nix (nix-ld + run-portable),
                        appimage.nix, usr-share-mounts.nix (bindfs for flatpak)
  llm/
    models/             THE model list (plain data, not a module), shared by
                        llama-swap/ and opencode/: models.nix (models keyed by device
                        group, with tags), profiles.nix (model sets picked by tag
                        query), presets.nix (defaults), default.nix (resolves it)
    llama-swap/         (mkIf meldesktop.llm) helpers.nix (spec -> llama-server flags,
                        AND the llama.cpp build: flake input `llama-cpp` = ggml-org
                        master, upstream .devops/nix on pkgs-llama, CUDA+Vulkan, all
                        CPU variants), package.nix (llama-swap v277 override; nixpkgs
                        is behind)
    opencode/           opencode packages + generated ~/.config/opencode/opencode.json
                        (home-manager programs.opencode): settings.nix,
                        providers.nix (models from models/), permissions.nix,
                        serve.nix (headless: `opencode serve` at boot)
home/                   home-manager (melody.nix, spotify.nix)
docs/                   reference: llama-server --help, llama-swap example config,
                        repo-structure.md (annotated map of every file),
                        storage-migration.md (disk layout + in-progress btrfs migration runbook)
scripts/                test.sh (build), deploy.sh (rsync to /etc/nixos + switch)
```

## Boot modes = specialisations

One system, three boot-menu entries:
- `normal` (default): full desktop, everything on the dGPU. llama-swap runs as a ghost:
  `--fit` headroom 1536 MiB, every model's idle ttl forced to 60 s, `voice` CPU-only.
- `saver`: desktop + llama-swap (fit headroom 512 MiB); all userspace Vulkan/GL renders on the iGPU
  (meldesktop.igpuEnv in hardware/igpu.nix: Vulkan/GL on the iGPU, Electron in software; KWin exempt)
  to save VRAM. Takes effect at login: after a live `mode saver`, log out + in.
- `headless`: raw TTY (firmware framebuffer, no nvidia_drm), autologin; llama-swap (fit headroom 128 MiB), `opencode serve` (localhost:4096,
  reach via `ssh -L 4096:localhost:4096`), openrgb all start at boot.

`meldesktop.mode` is set per specialisation in modules/modes/specialisations.nix; modules
branch on it with `lib.mkIf` (never in `imports`, that would recurse).
`config.meldesktop.desktop` is the shorthand for "not headless".
llama-swap runs in every mode; `meldesktop.llm.fitTarget` (--fit headroom, MiB) and
`meldesktop.llm.ttl` (forced idle unload, normal only) are set per mode there. A model's
`fitt` in the model list overrides the mode's headroom (default null).

## Commands

```bash
# no root
nixos-rebuild build --flake .          # builds all 3 modes into ./result
ls result/specialisation               # saver headless
nix flake update                       # bump all inputs (llama.cpp CUDA rebuilds!)
nix flake update llama-cpp             # just llama.cpp to current master (CUDA rebuild)

# root
sudo nixos-rebuild switch --flake .                            # activate normal, all 3 in boot menu
sudo nixos-rebuild test --flake . --specialisation saver       # live-switch to saver (no boot entry change)
# deploy while RUNNING saver/headless: plain `switch` would bounce you through normal
# mode (llama-swap stops). This sets the boot default AND activates saver live:
sudo nixos-rebuild switch --flake . --specialisation saver
sudo /run/current-system/specialisation/headless/bin/switch-to-configuration test   # same, from the running system
bootctl list                                                   # find the entry ids
sudo bootctl set-oneshot nixos-generation-<N>-specialisation-headless.conf && sudo reboot
readlink /run/current-system           # name ends in -saver / -headless when in that mode
```

## Models: one list, two consumers

Add/change a model or profile ONLY in modules/llm/models. It becomes a llama-swap model
or selector AND an OpenCode model `llama-swap/<id>` (variants low/medium/high/
noreasoning are generated; llama-swap discovery in OpenCode is off on purpose).
Profiles pick targets by tag (`match = [ "dense" "!unsafe" ]`, `prefer = [...]`
first); see the header of modules/llm/models/profiles.nix. Show what a profile resolves to:
`nix eval .#nixosConfigurations.MelDesktop3.config.specialisation.saver.configuration.services.llama-swap.settings.selectors.<id>.targets`
`fallback = [...]` puts ids last.
Reasoning efforts: each model declares the `efforts` its chat template accepts (default
low/medium/high; the EfficientThink/DAU family is low/medium/xhigh). A selector offers the
union of its targets' efforts, but its DEFAULT effort is always one the first (preferred)
target accepts. `flashNext` (presets.nix) is the preset for the Qwen3.8 Flash MoE slices
(thinking off by default, 4096-token budget).

### Tiered model (ruriww fork, `Qwen3.8-Flash-Next-Tiered`)
Runs the fork's own `serve.sh` (every flag/MOE_* knob lives there). Tuning on top is per-model in
models.nix: `env` (MOE_* exported right before serve.sh's `exec`, patched in by helpers.nix
tieredServe), `args` (extra llama-server flags, last wins), `cpus` (taskset). Current tuning
(2026-11-27 sweep, 5070 Ti + 14700K, decode t/s, noise ~8%): P-cores `0-15` + `-t 8`,
`MOE_DYN_BOOST=2.0` (think boost stays 1.25) = 96-100 vs 82-89 stock. Measured worse/no gain:
`-t 6` (73), `-t 12`, `--spec-draft-n-max 3` (52), ring cache GB 14/26. Swap: modules/system/memory.nix
(zram first, swappiness 150, desktop protected by user.slice MemoryLow; the fork recommends >= 100). Benchmark by copying
serve.sh, sourcing an overrides file before `exec`, and timing /v1/chat/completions
(efforts need max_tokens >= cap + 12000, else 400).
Multi-session: the fork's fast paths need one sequence (`-np 1`), so OpenCode sessions are juggled
through the host-RAM prompt cache instead (`cacheRamMiB`, default 8192 = ~5 parked 90k-token
sessions; serve.sh's own 2048 fits ~1). Vision: `files.mmproj` = unsloth's Flash-Next mmproj-F16.
Effort caps live in nix (`effortCaps`, `answer`, `maxPct` -> MOE_EFFORT_BUDGETS / MOE_THINK_ANSWER);
MOE_THINK_ROOM_ERROR=0 fits the cap (>= half) near the end of the context instead of the fork's
overflow error, and MOE_THINK_CHAIN_RESERVE = ctx - OpenCode's compaction point.

### Home Assistant voice (`voice` selector)
Home Assistant's voice agent sends model `voice`. Rule: voice never touches a coder (a loaded
coder counts as busy; llama-swap can't tell busy from idle). This is pure llama-swap config:
- `routing.router.use = capacity`, one pool `vram` (16000 MiB). Coders claim all of it
  (`--fit` grabs what's free) with `evict_cost` 100; `voice-gpu-gemma-4-12b` claims 8200, ttl 600,
  loaded on demand (no preload; cold first turn ~6.5 s). CPU (`voice-Qwen3.5-4B`, ttl 600) and iGPU title models claim nothing.
- `voice` selector: `strategy: fit`, `no_evict: true`, targets `[voice-gpu, voice-cpu]`. GPU free →
  GPU model (gemma-4-12b, ~0.4 s turns, cold-started if needed); coder loaded/loading → CPU
  (Qwen3.5-4B, ~2-5 s).
- Catch: a loaded CPU model wins ties over a cold GPU one, so after a coder unloads voice stays on
  the CPU until its 600 s ttl; its cold start re-prefills HA's ~9k-token prompt (~55-65 s).
- `fit`/`capacity` need llama-swap >= v273; nixpkgs has v268, so modules/llm/llama-swap/package.nix
  pins v277 (bump instructions in the file; delete it once nixpkgs catches up).
- Both voice models run `-rea off` (HA sends enable_thinking + `reasoning_effort: low`). Thinking
  was benchmarked 2026-11-27 and made every model worse (see the comment in models.nix), as did the
  MoE candidates (gemma-4-26B-A4B, Inkling-2-Mini, LFM2.5-24B-A2B); on the CPU, gemma-26B-A4B is
  ~1 case better than Qwen3.5-4B but needs 18 GB RAM next to a coder, so the CPU model stays.
Benchmarks and the eval harness live in `~/Projects/home-assistant-server/voice/` (see its
AGENTS.md). The iGPU is slower than the CPU for this, so it's deliberately unused. Coder `fitt`
defaults were raised to 768/1024 MiB after Tiel OOM'd on the first request with 128.

## OpenCode config

~/.config/opencode/opencode.json and dcp.jsonc (DCP plugin, opencode/dcp.nix) are
generated (read-only store symlinks); opencode.json is validated against opencode's own
v2 schema at build time. Do NOT leave an opencode.jsonc there: OpenCode loads it ON TOP
of opencode.json (`opencode debug config --standalone` lists both documents), so its
keys silently win (2026-11-27: a leftover hand config overrode compaction/permissions).
This repo is PUBLIC: secrets go in ~/.config/opencode/secrets/<name> (gitignored,
outside the store) and are referenced as `{file:...}` (settings.nix). Inspect the
loaded config with `opencode debug config --standalone` (without --standalone it
asks the already-running background server, which has the old config cached).
~/.config/opencode is also its own private git repo (machineonamission/opencode)
for the files that are still hand-edited (AGENTS.md, skills, memory).

Context limits: native compaction (`compaction.buffer`, % of limit.input, constant in
models/default.nix) is the failsafe; DCP's compress nudges (80% / 50%) should fire first.
A model whose server needs room on top of the prompt sets `inputLimit` below `ctx`
(tiered: ctx - (largest effort cap / 2 + answer) = 141840); OpenCode compacts below it,
and dcp.nix emits per-model token thresholds from it (DCP's own "%" is of limit.context).

## Verifying refactors

Pure refactors must not change `nix eval --raw .#nixosConfigurations.MelDesktop3.config.system.build.toplevel.drvPath`.
That single drv covers all three modes (the specialisations are inputs of it).
llama-swap settings and opencode.json are validated against their schemas at
build time, so run a real `nixos-rebuild build`, not just eval, after touching
anything under modules/llm. To check a change to the llama
side alone, diff `nix eval --json ...specialisation.saver.configuration.services.llama-swap.settings`
before/after.
