# llama-swap TODO

## Done

- [x] **profiles.nix: all models in selectors, mode = warm**
  - Rewrote `profiles.nix` into 13 selectors covering every loadable model
    (26 vram + 2 igpu title). Verified: no dangling selector targets, no
    loadable model without a selector, all `strategy = "warm"`.
  - Removed the dangling `Tiel-Coder-35B-A3B-MTP` reference from the `vram`
    routing group in `default.nix`.

- [x] **Tiel coder MTP crash**
  - Dropped the cross-quant `Tiel-Coder-35B-A3B-MTP` literal. It dies at load:
    `context type MTP requested but model doesn't contain MTP layers` — the
    IsValorum plain quant has `nextn_predict_layers=0` (no MTP head), so a
    separate-draft `--spec-type draft-mtp` can't attach. Its own comment said
    to drop it if it breaks. The plain `Tiel-Coder-35B-A3B` (the MoE coder) is
    unaffected and works.

- [x] **Broken selfMtp / specType WIP (was in the working tree)**
  - The uncommitted WIP had `selfMtp` commented out and `specType ? null`, which
    killed speculative decode on every self-contained-MTP model. Restored:
    `selfMtp = ["--spec-draft-n-max" "4"]` (tuning flags only) and the
    `specType` auto-detect so each model emits exactly one `--spec-type`
    (verified via the built config — no duplicate flags).

- [x] **Refactor: `valV3` helper**
  - Extracted the 27B VAL-APEX-NanoPlus-V3 family into a `valV3` helper
    (`helpers.nix`); 6 models became one-liners. Arete stays a plain `model`
    (text-only, no MTP head). Output verified identical.

## In progress / needs runtime verification (can't test — would evict from GPU)

- [ ] **Qwen3.8-27B heavy CPU offload / slow generation**
  - Tuned `ctx`/`fitCtx` = 65536 for `Qwen3.8-27B-VAL` and
    `Qwen3.8-27B-EfficientThink` (was 262144 / 131072). Rationale: 27B dense
    hybrid won't fully fit in 16 GB VRAM, so a huge KV cache starved the
    layers of VRAM and forced heavy CPU offload. Smaller KV cache lets
    `--fit` put VRAM into layers. **Trade-off: max context dropped from 256K to
    64K.** Needs a real run to confirm the generation-speed win.

## Notes / gotchas

- **mlock warning** (`failed to mlock 1289093120-byte buffer`): only appears
  with `--load-mode mlock`. The current config uses `--load-mode auto`, so this
  is not a config bug. Don't add mlock unless you bump `ulimit -l` as root.
- **Image mmproj runs on CPU** (`--no-mmproj-offload`): the Vulkan0 / iGPU path
  garbles every image model. Never offload mmproj to Vulkan0.
- **Can't hot-test models**: running llama-swap evicts the assistant from the
  GPU. Verify flag changes via `nixos-rebuild build --flake .` + inspecting the
  generated `*.yaml` cmd.
