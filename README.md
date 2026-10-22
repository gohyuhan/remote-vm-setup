# remote-vm-setup

Sets up a macOS or Linux machine with the same tools, versions, and configs as the source Mac.

## What it installs

Each tool installs at the version in `config/versions.lock`.

| Tool | How |
| --- | --- |
| Neovim, Go, Node.js | Official release tarball in `~/.local/opt` |
| Rust | rustup, with the locked toolchain |
| ripgrep, fd, tree-sitter CLI | `cargo install --locked` |
| gopls | `go install` |
| uv | Official installer, at the locked version |
| Python, pre-commit | `uv python install`, `uv tool install` |
| rtk, gitti, koshi | Release binary in `~/.local/bin` (on arm64 Linux, rtk builds from its release tag) |
| Claude Code | Official installer, at the locked version |
| Neovim plugins | lazy.nvim, at the commits in `config/nvim/lazy-lock.json` |
| Treesitter parsers, Mason packages | The locked list and versions |
| Claude Code marketplaces and plugins | The locked marketplace commits |

The configs for Neovim, gitti, koshi, and Claude Code go in place exactly as on the source Mac.
Sessions, logs, caches, and credentials are not part of the repo.

The first install uses the locked versions. Claude Code, gitti, and koshi keep auto-update on.
`setup.sh` does not touch a tool that is already installed, so it never downgrades a tool.

## Supported platforms

CI runs `setup.sh` on these systems:

- macOS 26 on Apple silicon. Intel Macs are not supported.
- On x86_64 and arm64:
  - Ubuntu 22.04, 24.04, 26.04
  - Debian 12, 13
  - Fedora 44, 45
  - Arch Linux (Arch Linux ARM on arm64)

Linux needs glibc 2.34 or later.

## Set up a machine

1. Clone the repo on the target machine.
2. Run `./setup.sh`.
   - On macOS, run it as your normal user.
   - On Linux, run it as root, or as a user that can use sudo.
3. Open a new shell.
4. Run `claude` to log in.

`setup.sh` runs `verify.sh` as its last step. You can run `setup.sh` again safely. If a config
file on the machine is different, `setup.sh` keeps it as `<file>.bak.<timestamp>`.

To check a machine at any time, run `./verify.sh`.

## Update the snapshot

1. On the source Mac, run `./collect.sh`. It replaces `config/` and writes
   `config/versions.lock`.
2. Review the diff, then commit it.

## Files

| File | Purpose |
| --- | --- |
| `setup.sh` | Installs the tools and places the configs |
| `verify.sh` | Checks every version and config against the repo |
| `collect.sh` | Copies the configs and versions from the source Mac into `config/` |
| `config/` | The configs and `versions.lock` |
| `.github/workflows/setup.yml` | Runs `setup.sh` on clean machines in CI |

## License

MIT. See [LICENSE](LICENSE).
