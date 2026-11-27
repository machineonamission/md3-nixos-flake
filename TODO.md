# general

## [DONE] consolidate branches + refactor (2026-11-26)

`main` is now the refactored config (force-pushed over the old broken main).
Everything from `opencodedev` is in it. Layout + workflow: see AGENTS.md.

- one system, 3 boot modes as specialisations (normal / saver / headless),
  switch live with `mode saver|headless|normal`, at boot with `mode once|boot <mode>`
- llama module rewritten (data-driven models, groups derived, selector targets asserted)
- unused flake inputs dropped, one llama.cpp CUDA build instead of two
- builds + evaluates; NOT yet booted / switched on real hardware

## next: deploy + test the modes on real hardware

- [ ] `sudo nixos-rebuild switch --flake .`, check boot menu shows (saver) / (headless)
- [ ] `mode saver`: llama-swap up, apps on iGPU (`nvidia-smi` shows little VRAM use)
- [ ] `mode headless` over ssh: monitors go to TTY, llama-swap + `opencode serve`
      (localhost:4096, `ssh -L 4096:localhost:4096`) + openrgb running
- [ ] `mode normal`: llama-swap stopped, games on the dGPU
- [ ] check `bootctl list` entry names match what `mode once/boot` expects
- [ ] SubControl now needs `run-on-igpu` in normal mode (VK_ICD_FILENAMES is saver-only)

## old branches

`nofollow`, `live`, `opencodedev` etc. are superseded by main; delete when the
new main is confirmed working.

## needs a decision (found during the refactor, left as-is)

- `system.stateVersion = "26.11"` was bumped by an LLM; home-manager says 26.05.
  It should be the release this machine was INSTALLED with. Find it before touching.
- howdy `abort_if_ssh = false`: comment said SSH logins should skip face auth (= true).
- firewall is off + ssh password auth + every llama-server binds 0.0.0.0 (per-model
  ports open to the LAN, no auth). `--host 127.0.0.1` in llama/helpers.nix would fix the latter.
- `scripts/deploy.sh` rsyncs without `--delete`, so deleted files linger in /etc/nixos
  (harmless, nothing imports them).

# local llm inference (llama-swap)

## [DONE] bug: wrong hf specification of MTP head

- Fixed in `helpers.nix`: llama.cpp requires `--spec-draft-hf <repo>` and `--spec-draft-model <file>` (NOT `--spec-draft-model repo:file`, which llama.cpp treated as a missing local disk path).
- Removed deprecated `--draft-max` in favor of `--spec-draft-n-max`.

## [DONE] get VAL-APEX (qwen3.8-27b quants by IsValorum) fully working, optimized for my hardware + MTP

- System hardware: RTX 5070 Ti (16gb vram), 32gb system ram, intel i7-14700k CPU, 2tb NVMe ssd.
- Exact GGUF files for all 7 Qwen3.8-27B VAL-APEX variants verified against Hugging Face API and explicitly targeted via `-hff <file>`:
  * `Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3.gguf`
  * `Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3.gguf`
  * `Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3.gguf` (bypasses sidecar dflash conflict)
  * `Qwen3.8-27B-TTURBO-709-Uncen.APEX-I-NanoPlus-V3.gguf`
  * `Arete-27B-VAL-APEX-I-NanoPlus-V3.gguf`
  * `Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated.VAL-APEX-I-NanoPlus-V3.gguf`
  * `Swift-1.5-Qwen3.8-27B-Uncensored-VAL-APEX-I-NanoPlus-V3.gguf`
- Tested with self-contained MTP (`blk.64.*`, 15 tensors): achieving ~40.2 t/s generation speed at full precision.
- Disambiguated `--spec-type` so `draft-mtp` is emitted cleanly without competing `--spec-type none`.

## [DONE] MTP non-gpu offload

- Separate MTP draft models (e.g. Cyber-Tiel-Coder-35B-A3B MTP, KAT-Coder, Occamy) configured with `--spec-draft-device Vulkan0 --spec-draft-ngl all` in `mtpExtra`.
- Draft models are placed on the Intel UHD Graphics 770 iGPU (`Vulkan0`) or CPU, consuming 0 MiB of VRAM on the main RTX 5070 Ti.

## [RESOLVED] igpu "output is mangled" mmproj?

- Confirmed: Intel Mesa ANV Vulkan driver has floating-point precision / subgroup bugs in `clip_encode` (vision encoders) on Gen12/Xe (UHD 770), causing NaNs / mangled vision tokens.
- Image models deliberately keep mmproj on CPU (`--no-mmproj-offload`), which runs bit-exact on the i7-14700K without risking GPU memory or garbled output.

## qwen-flash-next

as far as i can tell, qwen-flash-next is like upwards of 100gb and has like ram/vram/disk swap built into the architecture? earlier an agent found a quant of it that should be tuned for my system? maybe not the best now, but i want to get this working in my current llama setup!!!

## [ANSWERED] concept: *partial* offload MTP onto igpu?

- A separate draft model is only ~1.2–1.5 GB. The UHD 770 iGPU exposes ~23.8 GB of shared system memory, so the draft model fits entirely in `Vulkan0` with headroom.
- Splitting a 1.5 GB draft model across both CPU and iGPU adds inter-layer PCIe/cross-engine sync overhead and slows down speculative drafting. Offloading 100% of the draft model to `Vulkan0` (or 100% to CPU) is optimal.

## [DONE] unified model list that maps to llama swap AND opencode (2026-11-26)

modules/llm is the one list (see AGENTS.md "Models: one list, two consumers").
Profiles are tag queries now (`match = [ "dense" "!unsafe" ]`).

## [ANSWERED] `embeddings enabled with n_batch (2048) > n_ubatch (512)` warning

harmless: llama.cpp clamps n_batch to n_ubatch itself, that's what the second line says.

# opencode

## [DONE, NOT DEPLOYED] opencode config: jsonc -> nix (2026-11-26)

modules/opencode generates ~/.config/opencode/opencode.json (see AGENTS.md "OpenCode config").
Secrets already extracted to ~/.config/opencode/secrets/ (gitignored there).

To deploy:
- [ ] in ~/.config/opencode: `git rm opencode.jsonc` (it would override the
      generated opencode.json) and add `opencode.json` to its .gitignore; commit
- [ ] switch, then `systemctl --user restart` / restart opencode + desktop app
- [ ] `opencode debug config --standalone` shows the generated file as the source
- [ ] pick `llama-swap/coder#high` etc. in the UI; check HA MCP connects
- [ ] ROTATE the HA long-lived token + ha-mcp webhook id: both were in plaintext
      in NIXOS commits f8cde1c/f40c547 (public repo; not on any remote branch now,
      but they may have been pushed before) and in the opencode repo history
- [ ] old-opencode-nix branch (local, rescued ec3f043) contains the token: never push it,
      delete once this is confirmed working

Permissions rewritten for v2 semantics (modules/opencode/permissions.nix header):
`./*` matched nothing (Isolated could read the project!), agent `shell * allow`
cancelled the global guards, Builder/Admin sudo + switch/reboot asks were dead.
- [ ] after deploy: sanity-check prompts per agent (`opencode debug agents --standalone`
      shows each agent's final ordered rule list)
- [ ] the old `swap-back` model was dropped: llama-swap has no such id (it would 404)

## opencode nix flake issues

the opencode nix in THIS repo works (branch `live`). there is [an upstream bug](https://github.com/anomalyco/opencode/issues/59882) of them incorrectly generating fixed output nix hashes from node_modules, so the workaround in `./modules/opencode.nix` is the best solution until the issue is closed upstream (open at time of writing, 2026-11-22 2pm)

status: now using nixpkgs' `pkgs.opencode` (modules/opencode.nix), so the upstream
flake + workaround are unused (flake input removed). Old workaround:
`git show 26d3a9e^:"modules/opencode copy.nix"`.

# user experience

## fine but maybe could be better: nix-ld

still not 100% sure if i have the best setup for nix-ld, the goal being as many programs as possible working as-is/unmodified on my system

## issue: rust/cargo

the "benchmark" is that my dioxus project powerjournal needs to be able to compile and run for this system both for web and self-contained desktop/bundle mode: there were issues with nix-ld as always, i think with ssl specifically 

## remote desktop

so i have elsewhere on the network, remotely accessible home assistant that can wake-on-lan this desktop. the goal being, when im not evne home: i can:
- wake on lan to turn on pc
- remotely type in my password (this step is broken)
- remote control to code, and opencode service autostarts and is nginx accessible (works via kde remote desktop)

so i used to have some weird xrdp server that did work out of the box on the login screen. but it seemed to start a new desktop sesssion, when i want to control the existing one (like chrome remote desktop or kde's thing). right now i can start the rdp session on the login screen but i cant do anything, some x11/gui related bug, it wont start.

honestly, if i could do the "enter password to start desktop session/services on my physical pc" thing headlessly over like, ssh, thatd be sick too

i do like that the kde remote desktop just shows me a view of the existing desktops, but also i really love the like, 2nd remote session thing that can resize to the remote monitor thing, idk can i make it so i can swap between em?

could i use the kde rdp service and bake it into nixos to turn it on at boot (behind auth of course)