# Updating Oozenix

Oozenix includes an updater that brings your installation up to date with a single command.

## Requirements

- Oozenix was installed with `install-oozenix.sh`.
- The dotfiles are located in `~/dotfiles`.
- You are running as your normal user, not as root.

## Update

```bash
bash ~/dotfiles/update-oozenix.sh
```

The updater shows what is new, applies it, and asks before doing anything optional. When it finishes, it offers to reload Hyprland and restart OozeShell.

To see whether an update is available without changing anything:

```bash
bash ~/dotfiles/update-oozenix.sh --check
```

## Options

| Option | Description |
|---|---|
| `--check` | Report whether an update is available, change nothing |
| `--system` | Also run a full system update (Arch only) |
| `--force` | Redo extraction, native build and link checks even without changes |
| `-y`, `--yes` | Never ask; use the safe default for every question |
| `-h`, `--help` | Show help |

## What it updates

- The dotfiles repository, including your configs and OozeShell.
- Missing base packages and, if you choose, the whole system (Arch only).
- The OozeShell native core, rebuilt when OozeShell or Qt changes.
- Config symlinks, script permissions and fontconfig.
- Environment settings in `env.lua`.
- OozeWalls, rebuilt only if it changed and you already had it installed.

## Your changes are safe

- Local edits to your dotfiles are set aside in a git stash and re-applied after the update.
- The previous OozeShell is backed up in `~/.local/share/oozeshell/backups`.
- `env.lua` is backed up there before it is modified.
- Existing files that are not symlinks are never replaced without asking.

## After updating

- If the summary says `env.lua` changed, log out and back in.
- If the summary says the updater itself changed, run it once more to use the new steps.
- If it says the installer changed, read the diff if you rely on its questions.

## Troubleshooting

**"No existing install detected"**
Run `install-oozenix.sh` first. The updater only works on an existing install.

**"The current branch has no upstream"**
Set one with:
```bash
git -C ~/dotfiles branch --set-upstream-to=origin/main
```

**Your local changes conflict with the update**
The repository is left clean on the new version and your changes stay in the stash. Review and re-apply them with:
```bash
git -C ~/dotfiles stash show -p
git -C ~/dotfiles stash pop
```

**Your branch diverged from the remote**
The updater asks whether to rebase your local commits. If you decline, resolve it manually with `git -C ~/dotfiles pull --rebase`.

**The native core did not build**
OozeShell still works in pure QML. Make sure `cmake` is installed and retry with the build script path shown in the output.

**OozeWalls did not build**
Retry later with `bash ~/dotfiles/OozeWalls/install.sh`.

**AUR packages were not updated**
With `-y`, AUR packages are skipped. Run `paru -Sua --devel` or `yay -Sua --devel` yourself.

**Hyprland is older than 0.55**
The Lua configuration requires Hyprland 0.55 or newer. Run a system update with `--system`.
