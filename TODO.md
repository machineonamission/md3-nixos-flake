# general

## unmerged git branches:

`nofollow`: i think a mangled llama-swap config that doesnt launch so i revferted

`live`: branch off earlier nofollow, as of writing, live/deployed/tested working config

`main`: very behind because opencode merge fucked up bad

all of the WIP changes need to be collected into a proper config

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

## stretch: unified model list that maps to llama swap AND opencode

once opencode is nix and llama-swap is nix, what if i had a master model definiton that could update in opencode config and llama-swap without requiring discovery :3. i hate code duplication so much soooo much ill sooner do evil functional language hacks than copy paste yknow

# opencode

## task: opencode config: jsonc -> nix

opencode.jsonc present in ~/.config/opencode and mirrored in /home/melody/Projects/m2_opencode/opencode-m2-config/ . i want to move to a nix based folder in `./modules` (like how `./modules/llama` is structured). 

status: this was mostly completed, and merged into `main` branch, but the merge was mangled and the current HEAD of `main` does not build due to conflicts with the opencode flake bugs

## opencode nix flake issues

the opencode nix in THIS repo works (branch `live`). there is [an upstream bug](https://github.com/anomalyco/opencode/issues/59882) of them incorrectly generating fixed output nix hashes from node_modules, so the workaround in `./modules/opencode.nix` is the best solution until the issue is closed upstream (open at time of writing, 2026-11-22 2pm)

status: upstream still has issue, but local nix workaround works for the time being

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