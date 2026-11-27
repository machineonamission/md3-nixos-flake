# llama-swap notes

## Open
- [ ] Qwen3.8-27B family runs with `--fit-ctx 131072` (valV3 default). Earlier
      notes proposed 65536 for speed; needs a real throughput test.
- [ ] MiniCPM-V-4.7-35B-A3B-MTP: unverified that the dspark-* file works as a draft head.
- [ ] Profiles don't cover every model (e.g. Flint, Sage, T-Search, KAT, Thomson,
      LFM2.5, Flash-Coder/Next). They're now tag queries (modules/llm/models/profiles.nix),
      so give those models tags (family, moe/dense, unsafe) and they join automatically.
      Unsure which of them are MoE, so they're untagged for now.
- [ ] Each llama-server binds `--host 0.0.0.0` on its swap port; llama-swap only
      needs localhost, and the firewall is off, so those ports are open to the LAN
      unauthenticated. Consider `--host 127.0.0.1` in helpers.nix.
- [ ] `server_prepa: embeddings enabled with n_batch (2048) > n_ubatch (512)` warning:
      harmless (llama.cpp clamps n_batch itself).

- [ ] Qwen3.8-Flash-Coder gave garbage ("return null;" loops, ~46 t/s). `flashNext` preset
      (thinking off by default, 4096 budget) is the untested fix for the suspected thinking
      doom-loop. Verify on the box; if still bad try ctx 65536 (vendor quickstart) and min-p 0.

## Gotchas
- mmproj stays on the CPU (`--no-mmproj-offload`): Intel ANV Vulkan garbles clip_encode.
- `--load-mode mlock` needs a raised `ulimit -l`; we use `auto`.
- Can't hot-test models without evicting whatever is on the GPU. Verify flag changes with
  `nixos-rebuild build --flake .` and `nix eval .#nixosConfigurations.MelDesktop3.config.services.llama-swap.settings.models.<id>.cmd`.
