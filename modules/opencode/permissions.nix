# modules/opencode/permissions.nix
#
# Permission rules. ORDER MATTERS: OpenCode evaluates rules top-to-bottom and
# the LAST matching rule wins (see https://opencode.ai/docs/permissions). Broad
# rules go first, specific exceptions last. Keep this order intentional —
# reordering changes behavior.
{
  lib,
  ...
}:
let

  # --- Top-level (global) rules ---------------------------------------------
  # This list is ORDERED. Last match wins.
  globalPermissions = [
    # general defaults
    {
      action = "external_directory";
      resource = "/*";
      effect = "allow";
    }
    {
      action = "read";
      resource = "*";
      effect = "allow";
    }
    {
      action = "edit";
      resource = "*";
      effect = "ask";
    }
    {
      action = "edit";
      resource = "./*";
      effect = "allow";
    }
    {
      action = "glob";
      resource = "*";
      effect = "allow";
    }
    {
      action = "grep";
      resource = "*";
      effect = "allow";
    }
    {
      action = "shell";
      resource = "*";
      effect = "ask";
    }
    {
      action = "shell";
      resource = "cat *";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "find *";
      effect = "deny";
    }
    {
      action = "home_assistant_*";
      resource = "*";
      effect = "allow";
    }
    {
      action = "execute";
      resource = "*";
      effect = "allow";
    }

    # Edit ~/.config/opencode/* → always ask
    {
      action = "edit";
      resource = "/home/melody/.config/opencode/*";
      effect = "ask";
    }

    # Shell on AGENTS.md, ~/.config/opencode/*, git push, opencode CLI → always ask
    {
      action = "shell";
      resource = "/home/melody/.config/opencode/*";
      effect = "ask";
    }
    {
      action = "shell";
      resource = "git push *";
      effect = "ask";
    }
    {
      action = "shell";
      resource = "opencode *";
      effect = "ask";
    }
    {
      action = "shell";
      resource = "opencode service *";
      effect = "deny";
    }

    # sudo → always ask (Howdy camera approval)
    {
      action = "shell";
      resource = "sudo *";
      effect = "ask";
    }

    # Web tools always allowed
    {
      action = "websearch";
      resource = "*";
      effect = "allow";
    }
    {
      action = "webfetch";
      resource = "*";
      effect = "allow";
    }
    {
      action = "question";
      resource = "*";
      effect = "allow";
    }
    {
      action = "subagent";
      resource = "*";
      effect = "allow";
    }
    {
      action = "skill";
      resource = "*";
      effect = "allow";
    }
    {
      action = "todowrite";
      resource = "*";
      effect = "allow";
    }
    {
      action = "lsp";
      resource = "*";
      effect = "allow";
    }
    {
      action = "codesearch";
      resource = "*";
      effect = "allow";
    }
  ];

  # --- Per-agent rules ------------------------------------------------------
  # Agent rules are appended AFTER the global rules (they do not replace them),
  # and last match still wins within the combined list.
  agents = {
    "M2.0 🛡️ Isolated" = {
      description = "No filesystem access. Research-only mode: internet/research, thinking, using skills (not adding), opencode tools. All fs operations denied.";
      mode = "all";
      permissions = [
        {
          action = "read";
          resource = "./*";
          effect = "deny";
        }
        {
          action = "edit";
          resource = "./*";
          effect = "deny";
        }
        {
          action = "glob";
          resource = "./*";
          effect = "deny";
        }
        {
          action = "grep";
          resource = "./*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "deny";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "deny";
        }
      ];
    };

    "M2.1 📝 Planner" = {
      description = "Read-only/research mode. Full read, glob, grep. Edit/write+shell WITHIN project dir only (must commit backup first — no non-temporary uncommitted files). Ask for any shell or write outside project dir. Deny sudo.";
      mode = "all";
      permissions = [
        {
          action = "read";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "glob";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "grep";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "./*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "/*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "./*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "sudo *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "/*";
          effect = "ask";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "allow";
        }
        {
          action = "websearch";
          resource = "*";
          effect = "allow";
        }
        {
          action = "webfetch";
          resource = "*";
          effect = "allow";
        }
      ];
    };

    "M2.2 🛠️ Builder" = {
      description = "Project build mode. Full read/write/shell/git within active project dir. Gated: writes outside project dir, shell commands leaving permanent FS writes outside project dir (reading/probing like cat/tee is fine). Deny sudo. Behavioral: cargo/uv/package managers ok in-project; rustup/system-level tools not allowed. Always commit backup before edits.";
      mode = "all";
      permissions = [
        {
          action = "read";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "./*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "/*";
          effect = "ask";
        }
        {
          action = "glob";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "grep";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "./*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "sudo *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "/*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "allow";
        }
        {
          action = "home_assistant_*";
          resource = "*";
          effect = "allow";
        }
      ];
    };

    "M2.3 🖥️ System Admin" = {
      description = "System manager mode (dangerous). Full fs read/write (backup required before overwrite/delete). Permitted: nixos-rebuild (gated: switch/boot), nix, opencode (gated: service), shutdown/reboot (ask). Sudo → ask. Behavioral: always make a copy before overwriting/deleting anything.";
      mode = "all";
      permissions = [
        {
          action = "read";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "./*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "glob";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "grep";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "nixos-rebuild *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "nixos-rebuild switch *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "nixos-rebuild boot *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "systemctl *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "nix *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "opencode reload";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "shutdown *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "reboot *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "sudo *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "allow";
        }
        {
          action = "home_assistant_*";
          resource = "*";
          effect = "allow";
        }
      ];
    };

    "M2.5 ⚠️‼️ NO RESTRICTIONS" = {
      description = "DANGEROUS UNRESTRICTED MODE — all permissions fully enabled. BEFORE running anything: prompt user with GUI 'are you sure?' (emoji ⚠️‼️ in agent name as warning). All operations allowed including sudo, opencode service, shutdown. Behavioral: confirm with Melody before any destructive operation.";
      mode = "all";
      permissions = [
        {
          action = "edit";
          resource = "*AGENTS.md*";
          effect = "ask";
        }
        {
          action = "edit";
          resource = "~/.config/opencode/*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "*AGENTS.md*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "~/.config/opencode/*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "git push *";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "opencode *";
          effect = "allow";
        }
        {
          action = "read";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "glob";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "grep";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "skill";
          resource = "*";
          effect = "allow";
        }
        {
          action = "webfetch";
          resource = "*";
          effect = "allow";
        }
        {
          action = "websearch";
          resource = "*";
          effect = "allow";
        }
        {
          action = "question";
          resource = "*";
          effect = "allow";
        }
        {
          action = "external_directory";
          resource = "/*";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "*";
          effect = "allow";
        }
        {
          action = "home_assistant_*";
          resource = "*";
          effect = "allow";
        }
      ];
    };
  };

in
{
  inherit globalPermissions agents;
}
