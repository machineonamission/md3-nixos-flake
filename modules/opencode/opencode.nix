# modules/opencode/opencode.nix
#
# OpenCode (https://opencode.ai) for Melody — editor + generated config.
#
# This is a HOME-MANAGER module (option `programs.opencode`). It:
#   1. installs the OpenCode CLI + Desktop (same fixed-output node_modules
#      workaround as the old system module — see below)
#   2. writes ~/.config/opencode/opencode.jsonc via lib.genText
#
# Both are built by `nixos-rebuild build` / `nix build`. The generated JSONC is
# produced from the small declarative helpers below (models.nix, permissions.nix)
# instead of the old hand-written ~1200-line opencode.jsonc — so there is one
# place to edit, no duplicated model blobs, and nothing to drift.
#
# WHY THE node_modules WORKAROUND:
#   Upstream nix/hashes.json pins the node_modules fixed-output hash to a single
#   Bun version (anomalyco/opencode#59882). Following nixpkgs-unstable means this
#   build uses a different Bun, so the installed layout differs and the FOD check
#   fails on nearly every release. `hash = null` disables that check: Nix computes
#   and stores the real output hash without comparing it to a value that only
#   matches one Bun. No literal hash survives a version/Bun bump, so this stays
#   valid until upstream drops the aggregate hash (PR #59403).
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  opencodePkgs = inputs.opencode.packages.${system};

  fixedNodeModules = opencodePkgs.opencode.node_modules.override {
    hash = null;
  };

  fixedOpencode = opencodePkgs.opencode.override {
    node_modules = fixedNodeModules;
  };

  fixedOpencodeDesktop =
    (opencodePkgs.opencode-desktop.override {
      opencode = fixedOpencode;
    }).overrideAttrs
      (old: {
        postPatch = (old.postPatch or "") + ''
          for pkg in cli-linux-x64 cli-linux-x64-baseline opencode-linux-x64; do
            mkdir -p "packages/cli/dist/$pkg/bin"
            cp -L ${fixedOpencode}/bin/opencode "packages/cli/dist/$pkg/bin/opencode"
            cp -L ${fixedOpencode}/bin/opencode "packages/cli/dist/$pkg/bin/cli"
            printf '{"name":"@opencode/%s","version":"%s"}\n' "$pkg" "${fixedOpencode.version}" > "packages/cli/dist/$pkg/package.json"
          done
        '';
      });

  models = import ./models.nix { inherit lib; };
  permissions = import ./permissions.nix { inherit lib; };

  # Git-ignored secrets (HA MCP token). Read at build time so the token never
  # lands in the tracked Nix source.
  secrets = import ./secrets.nix;

  # The full config as a Nix value, assembled from the helpers above. This is
  # the single source of truth; `home.file` below serializes it to JSONC.
  configValue = {
    "$schema" = "https://opencode.ai/config.json";

    # Default model: llama-swap/coder at the `medium` reasoning variant.
    model = "llama-swap/coder#medium";

    default_agent = "M2.2 🛠️ Builder";

    username = "Melody";

    snapshots = true;

    # --- permissions (ordered — last match wins) ------------------------
    permissions = permissions.globalPermissions;

    # --- agents ---------------------------------------------------------
    agents =
      permissions.agents
      # `title` overrides the built-in title agent to use the tiny iGPU model
      # for fast session-title generation (thinking OFF via #noreasoning).
      // {
        "title" = {
          model = {
            providerID = "llama-swap";
            model = "title";
          };
        };
      };

    # --- plugins --------------------------------------------------------
    # NOTE on native vs plugin (checked against OpenCode v2.3.2 builtin list):
    #   * NONE of these are built-in — they all still ship as plugins.
    #   * The Desktop "memories" / "backups" UI you see comes from
    #       @nandoblanco/opencode-local-memory and -backup (not native).
    #   * opencode-tps-meter feeds the built-in `session.tps` footer toggle
    #     (Settings → Verbosity). It is optional; safe to drop.
    #   * @upstash/context7-opencode and the `context7` MCP server are two
    #     paths to the same thing — keep whichever you use, drop the other.
    plugins = [
      "@plannotator/opencode" # code annotations
      "opencode-tps-meter" # TUI tokens/sec (optional; feeds session.tps)
      "@mohak34/opencode-notifier" # desktop notifications
      "@upstash/context7-opencode" # /context7 command
      "@tarquinen/opencode-dcp@latest" # dynamic context pruning (see dcp.jsonc)
      "@nandoblanco/opencode-local-search" # side-panel search
      "@nandoblanco/opencode-local-memory" # Desktop memories UI
      "@nandoblanco/opencode-local-backup" # Desktop backups UI
      "opencode-models-discovery@latest" # refreshes the model catalog
    ]
    # NOTE: `title` model is declared in the `agents` block above, not here.
    ;

    # --- providers (llama.cpp + llama-swap) -----------------------------
    providers = models.providers;

    # --- instructions ---------------------------------------------------
    instructions = [
      "AGENTS.md"
      "CLAUDE.md"
      "README.md"
      "MACHINE-SQUARED.md"
      "./M2-GIT-GITHUB.md"
    ];

    # --- compaction -----------------------------------------------------
    # Config-level compaction is `{ auto?; keep?; buffer? }` — there is NO
    # `background` field. Background compaction is already the default in v2.3.1+
    # when `auto = true`, so the old `experimental.background_compaction` flag was
    # redundant (and is gone from the schema). Kept to the original's `auto`/`buffer`.
    compaction = {
      auto = true;
      buffer = "5%";
    };

    formatter = true;
    warming = false;

    # --- MCP servers ----------------------------------------------------
    # The HA token lives in secrets.nix (git-ignored), not here.
    mcp = {
      servers = {
        "home_assistant" = {
          type = "remote";
          url = "https://ha.melhome.me/api/mcp";
          headers = {
            Authorization = "Bearer ${secrets.haToken}";
          };
        };
        "ha-mcp" = {
          type = "remote";
          url = "https://ha.melhome.me/api/webhook/mcp_a4950e1b3cf71271259e20e5ba9932f4";
        };
        "gh_grep" = {
          type = "remote";
          url = "https://mcp.grep.app";
        };
      };
    };

    # --- references -----------------------------------------------------
    references = {
      "opencode-v2" = {
        repository = "anomalyco/opencode";
        branch = "v2";
        description = "OpenCode V2 source code and documentation. Use for understanding V2 internals, hooks, plugins, SDK, and migration details.";
      };
      "opencode-v2-config-schema" = {
        repository = "anomalyco/opencode";
        branch = "v2-config-schema";
        description = "OpenCode V2 config schema reference. Use for validating opencode.jsonc fields, selectors, and configuration shapes.";
      };
      "nixpkgs" = {
        repository = "NixOS/nixpkgs";
        branch = "nixos-unstable";
        description = "Nixpkgs package definitions and NixOS 26.05 channel. Use for package lookups, nixos options, and system configuration.";
      };
      "home-manager" = {
        repository = "nix-community/home-manager";
        branch = "master";
        description = "Home Manager module docs and examples. Use for HM module definitions, options, and config patterns.";
      };
      "nix" = {
        repository = "NixOS/nix";
        branch = "master";
        description = "Nix package manager source. Use for understanding Nix internals, language (Nix), and evaluation behavior.";
      };
      "llama-swap" = {
        repository = "mostlygeek/llama-swap";
        branch = "main";
        description = "Run multiple generative AI models on your machine and hot-swap between them on demand. llama-swap works with any OpenAI and Anthropic API compatible server and is used by thousands of people to power their local AI workflows.";
      };
      "nixos-config" = {
        path = "/etc/nixos";
        description = "Local NixOS system configuration. Use for hardware-configuration.nix, nixos-rebuild targets, flake inputs, and module definitions.";
      };
      "opencode-config" = {
        path = "~/.config/opencode";
        description = "OpenCode global config directory. Use for opencode.jsonc, cli.json, session data, plugins, and permissions files.";
      };
      "llama-gui-presets" = {
        path = "~/LLama-GUI/presets";
        description = "LLama-GUI preset definitions. Use when working with LLama-GUI presets or custom prompt configurations.";
      };
      "knowledge-base" = {
        path = "~/Projects/your knowledge base";
        description = "Melody's maintained knowledge base. Covers her system topology, home network, Home Assistant, and every project (PowerJournal/Dioxus+SeaORM, LLama-GUI, NixOS, quadlet, SLU, etc.). READ it before working on her systems or projects; UPDATE it whenever her network, NixOS, Home Assistant, or a project changes. It is also the place to record findings so future sessions don't have to re-discover them.";
      };
    };

    # --- experimental ---------------------------------------------------
    # portable_shell_scanner is a valid experimental flag. The old
    # `experimental.background_compaction` was redundant (background compaction is
    # the default when `compaction.auto` is on) and is no longer in the schema, so
    # it is dropped; see the compaction block above.
    experimental = {
      portable_shell_scanner = true;
    };

    lsp = true;
  };
in
{
  options.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode CLI + Desktop and generated config" {
      description = "Enable the OpenCode editor and generate ~/.config/opencode/opencode.jsonc from Nix.";
    };
  };
}
// lib.optionalAttrs config.programs.opencode.enable {
  # --- binaries -------------------------------------------------------
  home.packages = with pkgs; [
    fixedOpencode
    fixedOpencodeDesktop
  ];

  # --- generated config (built by nixos-rebuild build) ----------------
  # home-manager writes this text into ~/.config/opencode/opencode.jsonc.
  # models.prettyJson returns the full config as pretty-printed JSONC.
  home.file.".config/opencode/opencode.jsonc" = {
    text = models.prettyJson configValue;
  };
}
