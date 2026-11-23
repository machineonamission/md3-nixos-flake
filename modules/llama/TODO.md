# lama todo

- [ ] profiles.nix: add all models to all appropriate selectors and selector mode on warm 
- [ ] tiel coder 

0.00.071.984 I srv  llama_server: initializing ...
0.00.285.691 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.286.062 W srv  server_setup: security: no API key is set and CORS allows all origins (see https://github.com/ggml-org/llama.cpp/pull/25655)
0.00.287.706 I srv    load_model: loading model 'IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF'
0.00.698.392 W operator(): failed to measure the memory of the extra model, fitting without it: failed to create llama_context from model
0.00.989.746 W operator(): failed to measure the memory of the extra model, fitting without it: failed to create llama_context from model
0.02.386.388 W llama_model_loader: tensor overrides to CPU are used with mmap enabled - consider using --load-mode none for better performance
0.03.251.106 I cmn          init: llama threadpool init, n_threads = 8
0.03.251.143 I common_speculative_init_result: creating MTP draft context against the target model '/var/cache/llama-swap/huggingface/hub/models--IsValorum--Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF/snapshots/89a0b41aa70f275edf19ad203a9ad5714947d704/Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf'
0.03.251.144 W llama_init_from_model: context type MTP requested but model doesn't contain MTP layers
0.03.251.144 E common_speculative_init_result: failed to create MTP context
0.03.251.145 E srv    load_model: failed to create MTP context
0.03.251.147 I srv    operator(): operator(): cleaning up before exit...
0.03.251.973 E srv  server_run_i: exiting due to model loading error

- qwen 3.8 (normal and efficientthink)

its offloading WAY TOO HEAVILY to the cpu and its slooowwww

0.00.288.818 I srv  llama_server: initializing ...
0.00.577.702 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.578.081 W srv  server_setup: security: no API key is set and CORS allows all origins (see https://github.com/ggml-org/llama.cpp/pull/25655)
0.00.579.985 I srv    load_model: loading model 'IsValorum/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF'
0.09.337.341 I cmn          init: llama threadpool init, n_threads = 8
0.09.337.836 I common_speculative_init_result: creating MTP draft context against the target model '/var/cache/llama-swap/huggingface/hub/models--IsValorum--Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF/snapshots/6dd329564ad14a7c9d12819d3b449f8f6e9e5ebc/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3.gguf'
0.09.631.431 I srv    load_model: loaded multimodal model, '/var/cache/llama-swap/huggingface/hub/models--IsValorum--Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF/snapshots/6dd329564ad14a7c9d12819d3b449f8f6e9e5ebc/mmproj-Qwen3.8-27B-Q4_K_M.gguf'
0.09.631.442 I srv    load_model: initializing, n_slots = 1, n_ctx_slot = 131072, kv_unified = 'false'
0.09.729.025 W srv          init: chat template supports preserving reasoning, it is enabled by default (may use more tokens, disable via --no-reasoning-preserve)
0.09.729.202 I srv  server_run_i: model loaded
0.09.729.233 I srv  server_on_li: listening on http://0.0.0.0:5817
0.21.822.887 I srv    operator(): operator(): cleaning up before exit...
0.00.107.650 I srv  llama_server: initializing ...
0.00.330.754 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.331.064 W srv  server_setup: security: no API key is set and CORS allows all origins (see https://github.com/ggml-org/llama.cpp/pull/25655)
0.00.333.067 I srv    load_model: loading model 'IsValorum/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF'
0.07.755.807 I cmn          init: llama threadpool init, n_threads = 8
0.07.755.851 I common_speculative_init_result: creating MTP draft context against the target model '/var/cache/llama-swap/huggingface/hub/models--IsValorum--Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF/snapshots/6dd329564ad14a7c9d12819d3b449f8f6e9e5ebc/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3.gguf'
0.08.038.602 I srv    load_model: loaded multimodal model, '/var/cache/llama-swap/huggingface/hub/models--IsValorum--Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF/snapshots/6dd329564ad14a7c9d12819d3b449f8f6e9e5ebc/mmproj-Qwen3.8-27B-Q4_K_M.gguf'
0.08.038.609 I srv    load_model: initializing, n_slots = 1, n_ctx_slot = 131072, kv_unified = 'false'
0.08.129.025 W srv          init: chat template supports preserving reasoning, it is enabled by default (may use more tokens, disable via --no-reasoning-preserve)
0.08.129.038 I srv  server_run_i: model loaded
0.08.129.040 I srv  server_on_li: listening on http://0.0.0.0:5817
0.08.305.378 I slot get_availabl: id  0 | task -1 | selected slot by LRU, n_tokens = 0, t_last = -1
0.08.305.816 I slot launch_slot_: id  0 | task 0 | processing task, is_child = 0
0.12.621.855 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =   4096, progress = 0.30, t =   4.19 s / 978.23 tokens per second
0.14.702.223 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =   6144, progress = 0.45, t =   6.26 s / 981.30 tokens per second
0.16.839.413 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =   8192, progress = 0.60, t =   8.39 s / 975.97 tokens per second
0.19.035.057 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =  10240, progress = 0.75, t =  10.59 s / 967.32 tokens per second
0.21.249.270 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =  12231, progress = 0.89, t =  12.80 s / 955.79 tokens per second
0.22.356.668 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =  13151, progress = 0.96, t =  13.92 s / 944.77 tokens per second
0.22.947.958 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =  13648, progress = 1.00, t =  14.52 s / 939.96 tokens per second
0.23.297.497 I slot print_timing: id  0 | task 0 | prompt processing, n_tokens =  13663, progress = 1.00, t =  14.98 s / 912.33 tokens per second
0.32.231.669 I slot print_timing: id  0 | task 0 | n_gen =    100, tg =  11.41 t/s, tg_3s =  11.53 t/s
0.35.351.053 I slot print_timing: id  0 | task 0 | n_gen =    147, tg =  12.38 t/s, tg_3s =  15.07 t/s
0.38.463.576 I slot print_timing: id  0 | task 0 | n_gen =    184, tg =  12.27 t/s, tg_3s =  11.89 t/s
0.41.594.998 I slot print_timing: id  0 | task 0 | n_gen =    211, tg =  11.64 t/s, tg_3s =   8.62 t/s
0.44.737.372 I slot print_timing: id  0 | task 0 | n_gen =    243, tg =  11.42 t/s, tg_3s =  10.18 t/s
0.47.887.995 I slot print_timing: id  0 | task 0 | n_gen =    278, tg =  11.38 t/s, tg_3s =  11.11 t/s
0.51.026.103 I slot print_timing: id  0 | task 0 | n_gen =    322, tg =  11.69 t/s, tg_3s =  14.02 t/s
0.54.186.295 I slot print_timing: id  0 | task 0 | n_gen =    365, tg =  11.88 t/s, tg_3s =  13.61 t/s
0.54.644.772 I slot print_timing: id  0 | task 0 | prompt eval time =   15249.21 ms / 13667 tokens (    1.12 ms per token,   896.24 tokens per second)
0.54.644.773 I slot print_timing: id  0 | task 0 |        eval time =   31089.62 ms /   371 tokens (   84.03 ms per token,    11.90 tokens per second)
0.54.644.774 I slot print_timing: id  0 | task 0 |       total time =   46338.83 ms / 14038 tokens
0.54.644.775 I slot print_timing: id  0 | task 0 |    graphs reused =        137
0.54.644.776 I slot print_timing: id  0 | task 0 |   graph reallocs =          2    /     0        (same size) / (changed size)
0.54.644.778 I slot print_timing: id  0 | task 0 | draft acceptance = 0.55635 (  232 accepted /   417 generated), mean len =  2.67
0.54.646.141 I slot      release: id  0 | task 0 | stop processing: n_tokens = 14038, truncated = 0