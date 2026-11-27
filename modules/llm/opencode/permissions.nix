# permissions.nix — global permission rules + the M2 agents (OpenCode v2).
#
# How v2 evaluates (https://opencode.ai/v2/docs/permissions):
#   * every agent's list = built-in base ++ `global` ++ that agent's rules,
#     and the LAST matching rule wins (no match at all = ask)
#   * the built-in base starts with `* * allow` (+ ask on *.env), so
#     "allow X *" rules are only needed to undo an earlier ask/deny
#   * `*` matches anything INCLUDING `/`, patterns match the whole value
#   * read/edit resources: paths inside the project are RELATIVE
#     (`src/main.rs`), outside it they are canonical ABSOLUTE paths. So
#     `edit /*` = "edit outside the project" and `edit *` = "edit anything".
#     (`./*` matches nothing.) `~` / `$HOME` are expanded for read/edit/
#     external_directory, NOT for shell.
#   * shell resources are the raw command text (each part of a compound
#     command is checked; any deny wins), so a shell pattern can't say
#     "inside the project dir": the descriptions carry that as behaviour.
#
# Because agent rules come after `global`, an agent's broad `shell * allow`
# would cancel every global ask/deny. So the rules that must ALWAYS hold are
# in `guards` and appended at the very end of every agent (and global).
{ }:
let
  rule = effect: action: resource: { inherit action resource effect; };
  allow = rule "allow";
  ask = rule "ask";
  deny = rule "deny";

  # Last in every list, so no agent can loosen them.
  guards = [
    # agent instructions + the opencode config dir: always ask
    (ask "edit" "*AGENTS.md")
    (ask "shell" "*AGENTS.md*")
    (ask "edit" "~/.config/opencode/*")
    (ask "shell" "*.config/opencode/*")
    # tokens the config loads via {file:} (default.nix): never readable
    (deny "read" "~/.config/opencode/secrets/*")
    (deny "edit" "~/.config/opencode/secrets/*")
    (deny "shell" "*opencode/secrets*")
    (ask "shell" "git push *")
    # use the native read/glob/grep tools instead
    (deny "shell" "cat *")
    (deny "shell" "find *")
  ];

  # `rules` go after global; `final` after the guards (only for denies that
  # must beat the guards' asks, e.g. Isolated).
  agent =
    {
      description,
      rules ? [ ],
      final ? [ ],
    }:
    {
      mode = "all";
      inherit description;
      permissions = rules ++ guards ++ final;
    };

  # edits inside the project are free, outside it ask
  projectEdits = [
    (allow "edit" "*")
    (ask "edit" "/*")
  ];
in
{
  # Built-in agents (build, plan, ...) and the base for the M2 ones.
  global = [
    (ask "shell" "*")
    (ask "edit" "/*") # outside the project
    (ask "shell" "opencode *")
    (deny "shell" "opencode service *")
  ]
  ++ guards;

  agents = {
    "M2.0 🛡️ Isolated" = agent {
      description = "No filesystem access. Research-only mode: internet/research, thinking, using skills (not adding), opencode tools. All fs operations denied.";
      final = [
        (deny "read" "*")
        (deny "edit" "*")
        (deny "glob" "*")
        (deny "grep" "*")
        (deny "shell" "*")
        (deny "external_directory" "*")
      ];
    };

    # Shell stays `ask` (from global): a pattern can't tell in-project shell apart.
    "M2.1 📝 Planner" = agent {
      description = "Read-only/research mode. Full read, glob, grep. Edit/write WITHIN project dir only (must commit backup first — no non-temporary uncommitted files). Every shell command asks. Ask for any write outside project dir. Deny sudo.";
      rules = projectEdits ++ [ (deny "shell" "sudo *") ];
    };

    "M2.2 🛠️ Builder" = agent {
      description = "Project build mode. Full read/write/shell/git within active project dir. Gated: writes outside project dir, shell commands leaving permanent FS writes outside project dir (reading/probing like cat/tee is fine). Deny sudo. Behavioral: cargo/uv/package managers ok in-project; rustup/system-level tools not allowed. Always commit backup before edits.";
      rules = projectEdits ++ [
        (allow "shell" "*")
        (deny "shell" "sudo *")
        (deny "shell" "rustup *")
        (deny "shell" "nix-env *")
        (deny "shell" "nix profile *")
        (ask "shell" "nixos-rebuild *")
        (ask "shell" "opencode *")
        (deny "shell" "opencode service *")
      ];
    };

    "M2.3 🖥️ System Admin" = agent {
      description = "System manager mode (dangerous). Full fs read/write (backup required before overwrite/delete). Permitted: nixos-rebuild (gated: switch/boot), nix, opencode (gated: service), shutdown/reboot (ask). Sudo → ask. Behavioral: always make a copy before overwriting/deleting anything.";
      rules = [
        (allow "edit" "*")
        (allow "shell" "*")
        (ask "shell" "nixos-rebuild switch *")
        (ask "shell" "nixos-rebuild boot *")
        (ask "shell" "systemctl *")
        (ask "shell" "shutdown *")
        (ask "shell" "reboot *")
        (ask "shell" "sudo *")
        (ask "shell" "opencode service *")
      ];
    };

    "M2.5 ⚠️‼️ NO RESTRICTIONS" = agent {
      description = "DANGEROUS UNRESTRICTED MODE — all permissions fully enabled. BEFORE running anything: prompt user with GUI 'are you sure?' (emoji ⚠️‼️ in agent name as warning). All operations allowed including sudo, opencode service, shutdown (only the always-on guards still ask: AGENTS.md, ~/.config/opencode, git push). Behavioral: confirm with Melody before any destructive operation.";
      rules = [
        (allow "edit" "*")
        (allow "shell" "*")
      ];
    };
  };
}
