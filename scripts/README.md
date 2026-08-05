# System control plane

The scripts in this directory are the only supported local system-management entry points.

| Command | Behavior |
|---|---|
| `dotfiles status` | Repository and symlink state |
| `dotfiles inventory` | Redacted inventory under `$DOTFILES_STATE_DIR` or `$XDG_STATE_HOME/dotfiles` |
| `dotfiles doctor` | Non-destructive health checks |
| `dotfiles hermes` | Hermes Studio profile, runtime, exit-code, and secret-mode audit |
| `dotfiles config` | Managed, runtime, and legacy configuration-surface audit |
| `dotfiles audit` | Inventory, health checks, config audit, and docs |
| `dotfiles sync` | Inventory + configuration audit + generated Obsidian pages |
| `dotfiles docs` | Generated Obsidian pages only; no raw config copying |
| `dotfiles cleanup` | Dry-run candidate report only |

The legacy scripts in `~/bin` are compatibility wrappers. They must not regain direct
`rm`, `brew uninstall`, `docker prune`, volume deletion, or raw configuration-copy logic.

After installing software, changing a runtime, or adding a Python CLI, run
`dotfiles sync`; update the relevant manifest row before changing its status from
`review` to `active`.

Use `HERMES_AUDIT_STRICT=1 dotfiles hermes` when inline provider keys or unsafe
secret-file permissions must fail the command instead of remaining advisory.
