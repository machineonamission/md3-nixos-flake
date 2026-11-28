# settings.nix — the whole opencode.json, as a Nix value.
#
# Secrets are NOT in here: this repo is public and the generated file lands in
# the world-readable /nix/store. OpenCode substitutes `{file:<path>}` (and
# `{env:VAR}`) in any string when it loads the config, so the values are read
# from `secrets` (outside git, see hm-module.nix) at runtime.
#
# `flavor`: "desktop" | "tablet" (set by hm-module.nix from m2.opencode.host).
# Everything is shared byte-for-byte between machines EXCEPT the references
# and local plugins listed under `isDesktop` below — the tablet can't see
# /etc/nixos or the LLama-GUI checkout, and has no desktop-only local plugin.
#
# `version`: the opencode package's version (machines can run different ones:
# the desktop builds upstream's flake, the tablet nixpkgs'). Keys whose schema
# changed between versions branch on it, so each machine's config validates.
{
  lib,
  catalog,
  home,
  secrets,
  flavor ? "desktop",
  version,
}:
let
  permissions = import ./permissions.nix { };
  secret = name: "{file:${secrets}/${name}}";
  isDesktop = flavor == "desktop";
in
{
  # Tiered Flash-Next fork at xhigh (20k thinking cap); #high = the 12k-cap variant.
  model = "llama-swap/Qwen3.8-Flash-Next-Tiered#xhigh";
  default_agent = "M2.2 🛠️ Builder";
  username = "Melody";
  snapshots = true;
  formatter = true;
  warming = false;
  lsp = true;

  permissions = permissions.global;

  agents = permissions.agents // {
    # built-in title agent -> the tiny iGPU models (thinking off by default)
    title.model = {
      providerID = "llama-swap";
      model = "title";
    };
  };

  providers = import ./providers.nix { inherit lib catalog; };

  plugins = [
    "@plannotator/opencode"
    "opencode-tps-meter"
    "@mohak34/opencode-notifier"
    "@upstash/context7-opencode"
    "@tarquinen/opencode-dcp@latest" # config: generated ~/.config/opencode/dcp.jsonc (dcp.nix)
    "@nandoblanco/opencode-local-search"
    "@nandoblanco/opencode-local-memory"
    "@nandoblanco/opencode-local-backup"
    "opencode-models-discovery@latest" # only the llama-server provider uses it now
    "https://github.com/machineonamission/opencode-resume-plugin" # shared now (was desktop-local path); private repo — needs a gh/git credential on each machine
  ];

  # Project files are looked up per project; the last one is this config dir's.
  instructions = [
    "AGENTS.md"
    "CLAUDE.md"
    "README.md"
    "MACHINE-SQUARED.md"
    "${home}/.config/opencode/M2-GIT-GITHUB.md"
  ];

  # Native compaction is the failsafe; DCP (dcp.nix) should compress well before it.
  compaction = {
    auto = true;
    buffer = "${toString catalog.compactionBufferPct}%"; # of limit.input
  };

  experimental = {
    portable_shell_scanner = true;
  }
  # >= 2.4 dropped this flag; background compaction is `compaction.background`
  # there and defaults to on (core/src/session/compaction.ts).
  // lib.optionalAttrs (lib.versionOlder version "2.4") {
    background_compaction = true;
  };

  mcp.servers = {
    home_assistant = {
      type = "remote";
      url = "https://ha.melhome.me/api/mcp";
      headers.Authorization = "Bearer ${secret "home-assistant-token"}";
    };
    # the webhook id IS the credential
    ha-mcp = {
      type = "remote";
      url = secret "ha-mcp-url";
    };
    gh_grep = {
      type = "remote";
      url = "https://mcp.grep.app";
    };
  };

  # Everything here is shared between machines EXCEPT the two path-based
  # references at the bottom (desktop checkouts the tablet doesn't have).
  # Repository references are cloned+cached by OpenCode itself, on each
  # machine, into ~/.local/share/opencode/repos — same list, same result.
  references = {
    opencode-v2 = {
      repository = "anomalyco/opencode";
      branch = "v2";
      description = "OpenCode V2 source code and documentation. Use for understanding V2 internals, hooks, plugins, SDK, and migration details.";
    };
    opencode-v2-config-schema = {
      repository = "anomalyco/opencode";
      branch = "v2-config-schema";
      description = "OpenCode V2 config schema reference. Use for validating opencode.jsonc fields, selectors, and configuration shapes.";
    };
    nixpkgs = {
      repository = "NixOS/nixpkgs";
      branch = "nixos-unstable";
      description = "Nixpkgs package definitions and NixOS 26.05 channel. Use for package lookups, nixos options, and system configuration.";
    };
    home-manager = {
      repository = "nix-community/home-manager";
      branch = "master";
      description = "Home Manager module docs and examples. Use for HM module definitions, options, and config patterns.";
    };
    nix = {
      repository = "NixOS/nix";
      branch = "master";
      description = "Nix package manager source. Use for understanding Nix internals, language (Nix), and evaluation behavior.";
    };
    llama-swap = {
      repository = "mostlygeek/llama-swap";
      branch = "main";
      description = "Run multiple generative AI models on your machine and hot-swap between them on demand. llama-swap works with any OpenAI and Anthropic API compatible server and is used by thousands of people to power their local AI workflows.";
    };
    opencode-config = {
      path = "~/.config/opencode";
      description = "OpenCode global config directory. opencode.json there is GENERATED by the NixOS config (modules/llm/opencode in ~/Projects/NIXOS) and read-only; edit the Nix module instead. dcp.jsonc there is generated too (dcp.nix). Also holds AGENTS.md, skills, memory.";
    };
    knowledge-base = {
      path = "~/Projects/your knowledge base";
      description = "Melody's maintained knowledge base. Covers her system topology, home network, Home Assistant, and every project (PowerJournal/Dioxus+SeaORM, LLama-GUI, NixOS, quadlet, SLU, etc.). READ it before working on her systems or projects; UPDATE it whenever her network, NixOS, Home Assistant, or a project changes. It is also the place to record findings so future sessions don't have to re-discover them.";
    };
  }
  // lib.optionalAttrs isDesktop {
    nixos-config = {
      path = "/etc/nixos";
      description = "Local NixOS system configuration. Use for hardware-configuration.nix, nixos-rebuild targets, flake inputs, and module definitions.";
    };
    llama-gui-presets = {
      path = "~/LLama-GUI/presets";
      description = "LLama-GUI preset definitions. Use when working with LLama-GUI presets or custom prompt configurations.";
    };
  };
}
