# permissions.nix — global permission rules + the M2 agents.
#
# ORDER MATTERS: rules are evaluated top to bottom and the LAST matching rule
# wins (https://opencode.ai/docs/permissions). Broad rules first, exceptions last.
# Lists keep their order through Nix -> JSON, so what you see is what OpenCode gets.
{ home }:
let
  rule = effect: action: resource: { inherit action resource effect; };
  allow = rule "allow";
  ask = rule "ask";
  deny = rule "deny";

  agent = description: permissions: {
    mode = "all";
    inherit description permissions;
  };
in
{
  global = [
    # general defaults
    (allow "external_directory" "/*")
    (allow "read" "*")
    (ask "edit" "*")
    (allow "edit" "./*")
    (allow "glob" "*")
    (allow "grep" "*")
    (ask "shell" "*")
    (deny "shell" "cat *")
    (deny "shell" "find *")
    (allow "home_assistant_*" "*")
    (allow "execute" "*")
    # editing / shelling into the opencode config dir -> always ask
    (ask "edit" "${home}/.config/opencode/*")
    (ask "shell" "${home}/.config/opencode/*")
    # git push, opencode CLI -> ask; opencode service -> never
    (ask "shell" "git push *")
    (ask "shell" "opencode *")
    (deny "shell" "opencode service *")
    # sudo -> always ask (Howdy camera approval)
    (ask "shell" "sudo *")
    # web + agent tooling always allowed
    (allow "websearch" "*")
    (allow "webfetch" "*")
    (allow "question" "*")
    (allow "subagent" "*")
    (allow "skill" "*")
    (allow "todowrite" "*")
    (allow "lsp" "*")
    (allow "codesearch" "*")
  ];

  agents = {
    "M2.0 🛡️ Isolated" =
      agent
        "No filesystem access. Research-only mode: internet/research, thinking, using skills (not adding), opencode tools. All fs operations denied."
        [
          (deny "read" "./*")
          (deny "edit" "./*")
          (deny "glob" "./*")
          (deny "grep" "./*")
          (deny "shell" "*")
          (deny "external_directory" "/*")
        ];

    "M2.1 📝 Planner" =
      agent
        "Read-only/research mode. Full read, glob, grep. Edit/write+shell WITHIN project dir only (must commit backup first — no non-temporary uncommitted files). Ask for any shell or write outside project dir. Deny sudo."
        [
          (allow "read" "/*")
          (allow "glob" "/*")
          (allow "grep" "/*")
          (allow "edit" "./*")
          (ask "edit" "/*")
          (allow "shell" "./*")
          (ask "shell" "sudo *")
          (ask "shell" "/*")
          (allow "external_directory" "/*")
          (allow "subagent" "*")
          (allow "websearch" "*")
          (allow "webfetch" "*")
        ];

    "M2.2 🛠️ Builder" =
      agent
        "Project build mode. Full read/write/shell/git within active project dir. Gated: writes outside project dir, shell commands leaving permanent FS writes outside project dir (reading/probing like cat/tee is fine). Deny sudo. Behavioral: cargo/uv/package managers ok in-project; rustup/system-level tools not allowed. Always commit backup before edits."
        [
          (allow "read" "/*")
          (allow "edit" "./*")
          (ask "edit" "/*")
          (allow "glob" "/*")
          (allow "grep" "/*")
          (allow "shell" "./*")
          (ask "shell" "sudo *")
          (ask "shell" "/*")
          # NOTE: last match wins, so this overrides the two `ask`s above
          (allow "shell" "*")
          (allow "external_directory" "/*")
          (allow "subagent" "*")
          (allow "home_assistant_*" "*")
        ];

    "M2.3 🖥️ System Admin" =
      agent
        "System manager mode (dangerous). Full fs read/write (backup required before overwrite/delete). Permitted: nixos-rebuild (gated: switch/boot), nix, opencode (gated: service), shutdown/reboot (ask). Sudo → ask. Behavioral: always make a copy before overwriting/deleting anything."
        [
          (allow "read" "/*")
          (allow "edit" "./*")
          (allow "edit" "/*")
          (allow "glob" "/*")
          (allow "grep" "/*")
          (allow "external_directory" "/*")
          (allow "shell" "nixos-rebuild *")
          (ask "shell" "nixos-rebuild switch *")
          (ask "shell" "nixos-rebuild boot *")
          (ask "shell" "systemctl *")
          (allow "shell" "nix *")
          (allow "shell" "opencode reload")
          (ask "shell" "shutdown *")
          (ask "shell" "reboot *")
          (ask "shell" "sudo *")
          # NOTE: last match wins, so this overrides every shell `ask` above
          (allow "shell" "*")
          (allow "external_directory" "/*")
          (allow "subagent" "*")
          (allow "home_assistant_*" "*")
        ];

    "M2.5 ⚠️‼️ NO RESTRICTIONS" =
      agent
        "DANGEROUS UNRESTRICTED MODE — all permissions fully enabled. BEFORE running anything: prompt user with GUI 'are you sure?' (emoji ⚠️‼️ in agent name as warning). All operations allowed including sudo, opencode service, shutdown. Behavioral: confirm with Melody before any destructive operation."
        [
          # Always-gated (base rules that must survive unrestricted mode)
          # NOTE: last match wins, so the `edit /*` / `shell *` allows below override these
          (ask "edit" "*AGENTS.md*")
          (ask "edit" "~/.config/opencode/*")
          (ask "shell" "*AGENTS.md*")
          (ask "shell" "~/.config/opencode/*")
          (ask "shell" "git push *")
          (allow "shell" "opencode *")
          # Full unrestricted access
          (allow "read" "/*")
          (allow "edit" "/*")
          (allow "glob" "/*")
          (allow "grep" "/*")
          (allow "shell" "*")
          (allow "skill" "*")
          (allow "webfetch" "*")
          (allow "websearch" "*")
          (allow "question" "*")
          (allow "external_directory" "/*")
          (allow "subagent" "*")
          (allow "home_assistant_*" "*")
        ];
  };
}
