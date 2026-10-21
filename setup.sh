#!/usr/bin/env bash
# Bootstrap a macOS or Linux machine (desktop or server) to match the source Mac: install the
# exact versions in config/versions.lock, put the configs from ./config in place, then run
# verify.sh. Any step that fails stops the run, except Mason packages: verify.sh reports those.
#
# Usage: ./setup.sh   (as root, or as a user with sudo; safe to re-run)
# Run it on the target machines, not on the Mac that collect.sh reads from.
#
# Versions are pinned for the first install. A tool that is already installed is left alone,
# so tools that update themselves (Claude Code, gitti, koshi) are never downgraded.
#
# Linux needs x86_64 or arm64, glibc 2.34+ (official Node.js binaries require it), and one of:
#   apt     Ubuntu 22.04+, Debian 12+
#   dnf     Fedora, RHEL/Rocky/Alma/Oracle/CentOS Stream 9+, Amazon Linux 2023
#   zypper  openSUSE
#   pacman  Arch
# Distro base packages (git, zsh, the C compiler) come from the distro and are not pinned.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
lock="$repo/config/versions.lock"
opt_dir="$HOME/.local/opt"
bin_dir="$HOME/.local/bin"
env_file="$HOME/.config/remote-vm-setup/env.sh"
stamp="$(date +%Y%m%d%H%M%S)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

# retry COMMAND...: run COMMAND up to 3 times, for downloads that fail now and then
# (e.g. "stream error ... INTERNAL_ERROR" from proxy.golang.org).
retry() {
  local attempt
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    fi
    log "Attempt $attempt of 3 failed: $*"
    sleep 10
  done
  return 1
}

# pin NAME: the locked version of tool NAME.
pin() {
  local version
  version="$(awk -v name="$1" '$1 == "tool" && $2 == name {print $3}' "$lock")"
  if [ -z "$version" ]; then
    die "No version for $1 in $lock"
  fi
  echo "$version"
}

if [ ! -f "$lock" ]; then
  die "$lock is missing. Run collect.sh on the source Mac first."
fi
for tool in neovim go node python rust ripgrep fd tree-sitter-cli gopls uv rtk gitti koshi \
  claude-code pre-commit; do
  pin "$tool" >/dev/null
done

case "$(uname -s)" in
  Darwin)
    os="darwin"
    nvim_os="macos"
    ;;
  Linux)
    os="linux"
    nvim_os="linux"
    ;;
  *) die "Unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  x86_64)
    cpu="x86_64"
    goarch="amd64"
    node_arch="x64"
    ;;
  aarch64 | arm64)
    cpu="arm64"
    goarch="arm64"
    node_arch="arm64"
    ;;
  *) die "Unsupported CPU: $(uname -m)" ;;
esac

# linux-arm64 builds rtk from source instead; see install_tools.
case "$os-$cpu" in
  darwin-arm64) rtk_target="aarch64-apple-darwin" ;;
  darwin-x86_64) rtk_target="x86_64-apple-darwin" ;;
  linux-x86_64) rtk_target="x86_64-unknown-linux-musl" ;;
esac

# Mason has no build of this package for this platform (its receipt lists no asset for it), so
# install_mason_gap installs the same version from the project's own release. Keep in sync with
# verify.sh.
case "$os-$cpu" in
  linux-arm64) mason_gap="clangd" ;;
  darwin-x86_64) mason_gap="swiftlint" ;;
  *) mason_gap="" ;;
esac

sudo_cmd=""
if [ "$os" = "darwin" ]; then
  if [ "$(id -u)" -eq 0 ]; then
    die "On macOS, run setup.sh as your normal user, not root."
  fi
elif [ "$(id -u)" -ne 0 ]; then
  has sudo || die "Run as root, or as a user that can use sudo."
  sudo_cmd="sudo"
  sudo -v # Ask for the password once, at the start.
fi

install_macos_base() {
  # The Command Line Tools provide clang and git. The check and the headless install are the
  # ones Homebrew's installer uses (github.com/Homebrew/install, install.sh): the placeholder
  # file makes softwareupdate list the Command Line Tools, so no GUI dialog is needed (SSH works).
  local clt_git="/Library/Developer/CommandLineTools/usr/bin/git"
  local placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  local label
  if [ -e "$clt_git" ]; then
    return 0
  fi
  log "Installing the Xcode Command Line Tools"
  sudo touch "$placeholder"
  label="$(softwareupdate -l | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ *\*/ {print $2}' |
    sed -e 's/^ *Label: //' -e 's/^ *//' | sort -V | tail -n 1)" || label=""
  if [ -n "$label" ]; then
    sudo softwareupdate -i "$label"
  fi
  sudo rm -f "$placeholder"
  if [ ! -e "$clt_git" ]; then
    die "The Command Line Tools did not install. Run 'xcode-select --install' on the Mac, then re-run."
  fi
  sudo xcode-select --switch /Library/Developer/CommandLineTools
}

# Runs after the base packages, so python3 is present on minimal images that lack getconf.
check_glibc() {
  local version major minor
  version="$(python3 -c 'import platform; print(platform.libc_ver()[1])')"
  if [ -z "$version" ]; then
    die "glibc not found. musl distros such as Alpine are not supported."
  fi
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 34 ]; }; then
    die "glibc $version is too old; need 2.34+ (Ubuntu 22.04+, Debian 12+, RHEL 9+)."
  fi
}

install_linux_base() {
  local install base attempt=1
  if has apt-get; then
    # After first boot, apt-daily, unattended-upgrades, or cloud-init can hold the apt locks.
    # `install` waits for the dpkg lock through DPkg::Lock::Timeout (apt-pkg/deb/debsystem.cc).
    # `update` takes the lists lock without waiting (GetLock uses F_SETLK), so retry it.
    # NEEDRESTART_MODE=l makes needrestart list services instead of restarting them.
    install="env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get -o DPkg::Lock::Timeout=600 install -y"
    base="git ca-certificates tar gzip xz-utils unzip zsh build-essential libclang-dev python3"
    until $sudo_cmd apt-get update; do
      if [ "$attempt" -ge 60 ]; then
        die "apt-get update failed 60 times in 10 minutes."
      fi
      attempt=$((attempt + 1))
      sleep 10
    done
  elif has dnf; then
    install="dnf install -y"
    base="git ca-certificates tar gzip xz unzip zsh gcc gcc-c++ make clang-devel python3 findutils diffutils"
  elif has zypper; then
    install="zypper --non-interactive install"
    base="git ca-certificates tar gzip xz unzip zsh gcc gcc-c++ make clang-devel python3 findutils diffutils"
  elif has pacman; then
    install="pacman -S --needed --noconfirm"
    base="git ca-certificates tar gzip xz unzip zsh base-devel clang python findutils diffutils"
    $sudo_cmd pacman -Syu --noconfirm
  else
    die "No supported package manager found (apt-get, dnf, zypper, pacman)."
  fi
  # libclang: the tree-sitter CLI build runs bindgen (rquickjs-sys), which needs it. Package names
  # from rust-lang.github.io/rust-bindgen/requirements.html. On macOS the Command Line Tools have it.
  # Add curl only when missing, so a preinstalled curl-minimal (Fedora family) stays untouched.
  if ! has curl; then
    base="$base curl"
  fi

  log "Installing system packages"
  # $install and $base are word lists; the word splitting is intended.
  $sudo_cmd $install $base
  check_glibc
}

# install_tree NAME VERSION URL: unpack a release tarball into ~/.local/opt/NAME-VERSION.
install_tree() {
  local dest="$opt_dir/$1-$2"
  if [ -d "$dest" ]; then
    return 0
  fi
  log "Installing $1 $2"
  curl -fsSLo "$tmp_dir/$1.tar.gz" "$3"
  rm -rf "$dest.partial"
  mkdir -p "$dest.partial"
  tar -C "$dest.partial" --strip-components=1 -xzf "$tmp_dir/$1.tar.gz"
  mv "$dest.partial" "$dest"
}

# install_binary NAME VERSION URL: copy the NAME binary from a release tarball to ~/.local/bin.
install_binary() {
  local name="$1" unpack="$tmp_dir/$1" found
  if has "$name"; then
    return 0
  fi
  log "Installing $name $2"
  curl -fsSLo "$tmp_dir/$name.tar.gz" "$3"
  mkdir -p "$unpack"
  tar -C "$unpack" -xzf "$tmp_dir/$name.tar.gz"
  found="$(find "$unpack" -type f -name "$name" | head -n 1)"
  if [ -z "$found" ]; then
    die "No $name binary inside $3"
  fi
  mkdir -p "$bin_dir"
  install -m 0755 "$found" "$bin_dir/$name"
}

install_runtimes() {
  local version
  version="$(pin neovim)"
  install_tree nvim "$version" \
    "https://github.com/neovim/neovim/releases/download/v$version/nvim-$nvim_os-$cpu.tar.gz"
  version="$(pin go)"
  install_tree go "$version" "https://go.dev/dl/go$version.$os-$goarch.tar.gz"
  version="$(pin node)"
  install_tree node "$version" "https://nodejs.org/dist/v$version/node-v$version-$os-$node_arch.tar.gz"
}

# One env file holds every PATH entry; shells, setup.sh, and verify.sh all source it.
write_env() {
  local rc
  mkdir -p "$(dirname "$env_file")"
  cat >"$env_file" <<EOF
# Written by remote-vm-setup/setup.sh: PATH for the pinned tools.
export PATH="$opt_dir/nvim-$(pin neovim)/bin:$opt_dir/node-$(pin node)/bin:$opt_dir/go-$(pin go)/bin:\$HOME/.local/bin:\$HOME/.cargo/bin:\$HOME/go/bin:\$PATH"
EOF
  . "$env_file"
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if ! grep -qF "$env_file" "$rc" 2>/dev/null; then
      printf '\n# Added by remote-vm-setup\n. "%s"\n' "$env_file" >>"$rc"
      echo "Added $env_file to $rc"
    fi
  done
}

install_tools() {
  local version
  mkdir -p "$bin_dir"
  version="$(pin uv)"
  if ! has uv; then
    log "Installing uv $version"
    curl -LsSf "https://astral.sh/uv/$version/install.sh" | env UV_NO_MODIFY_PATH=1 sh
  fi

  # Mason builds its Python tools with the python3 on PATH, so pin that too.
  version="$(pin python)"
  uv python install "$version"
  if [ ! -e "$bin_dir/python3" ]; then
    ln -s "$(uv python find "$version")" "$bin_dir/python3"
  fi

  version="$(pin gitti)"
  install_binary gitti "$version" \
    "https://github.com/gohyuhan/gitti/releases/download/v$version/gitti-v$version-$os-$goarch.tar.gz"
  version="$(pin koshi)"
  install_binary koshi "$version" \
    "https://github.com/gohyuhan/koshi/releases/download/v$version/koshi-v$version-$os-$goarch.tar.gz"

  version="$(pin claude-code)"
  if ! has claude; then
    log "Installing Claude Code $version"
    curl -fsSL https://claude.ai/install.sh | bash -s "$version"
  fi

  version="$(pin rust)"
  if ! has rustup; then
    log "Installing Rust $version"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "$version"
  fi
  # rustup puts its proxies, rust-analyzer included, in ~/.cargo/bin.
  # The rust-analyzer-lsp and gopls-lsp Claude plugins need both servers on PATH.
  rustup component add rust-analyzer

  if ! has rg; then
    log "Building ripgrep $(pin ripgrep)"
    cargo install --locked ripgrep --version "$(pin ripgrep)"
  fi
  if ! has fd; then
    log "Building fd $(pin fd)"
    cargo install --locked fd-find --version "$(pin fd)"
  fi
  if ! has tree-sitter; then
    log "Building tree-sitter CLI $(pin tree-sitter-cli)"
    cargo install --locked tree-sitter-cli --version "$(pin tree-sitter-cli)"
  fi
  version="$(pin rtk)"
  if [ "$os-$cpu" != "linux-arm64" ]; then
    install_binary rtk "$version" \
      "https://github.com/rtk-ai/rtk/releases/download/v$version/rtk-$rtk_target.tar.gz"
  elif ! has rtk; then
    # The arm64 Linux release binary needs glibc 2.39 ("GLIBC_2.39 not found" on Ubuntu 22.04),
    # so build the release tag. The crates.io crate named rtk is a different project.
    log "Building rtk $version"
    cargo install --locked --git https://github.com/rtk-ai/rtk --tag "v$version" rtk
  fi
  if ! has gopls; then
    log "Installing gopls $(pin gopls)"
    retry go install "golang.org/x/tools/gopls@v$(pin gopls)"
  fi
  if ! has pre-commit; then
    uv tool install "pre-commit==$(pin pre-commit)" --python "$(pin python)"
  fi
}

# Install $mason_gap from its upstream release, at the version the lock has for it.
install_mason_gap() {
  local version dest found
  # Check this install, not PATH: a distro package can bring its own build (Fedora's clang-devel
  # brings clangd).
  if [ -z "$mason_gap" ] || [ -x "$bin_dir/$mason_gap" ]; then
    return 0
  fi
  version="$(awk -v name="$mason_gap" '$1 == "mason" && $2 == name {print $3}' "$lock")"
  if [ -z "$version" ]; then
    return 0
  fi
  dest="$opt_dir/$mason_gap-$version"
  if [ ! -d "$dest" ]; then
    log "Installing $mason_gap $version (Mason has no $os-$cpu build)"
    rm -rf "$dest.partial"
    mkdir -p "$dest.partial"
    case "$mason_gap" in
      clangd)
        # Only LLVM's full toolchain (about 1.7 GB) has an arm64 Linux clangd. Stream it into
        # tar, so the archive never lands in a RAM-backed /tmp, and keep clangd and its builtin
        # headers (clangd finds them at ../lib/clang next to its real path). tar(1) documents no
        # default for whether * matches / in member names, so set it.
        curl -fsSL "https://github.com/llvm/llvm-project/releases/download/llvmorg-$version/LLVM-$version-Linux-ARM64.tar.xz" |
          tar -C "$dest.partial" --strip-components=1 --wildcards --wildcards-match-slash -xJf - \
            '*/bin/clangd' '*/lib/clang/*'
        ;;
      swiftlint)
        # The universal macOS binary covers Intel Macs.
        curl -fsSLo "$tmp_dir/swiftlint.zip" \
          "https://github.com/realm/SwiftLint/releases/download/$version/portable_swiftlint.zip"
        unzip -q "$tmp_dir/swiftlint.zip" -d "$dest.partial"
        ;;
    esac
    mv "$dest.partial" "$dest"
  fi
  found="$(find "$dest" -type f -name "$mason_gap" | head -n 1)"
  if [ -z "$found" ] || [ ! -x "$found" ]; then
    die "No $mason_gap binary in $dest"
  fi
  ln -sf "$found" "$bin_dir/$mason_gap"
}

# place SRC DEST: copy SRC to DEST. A different DEST is kept as DEST.bak.<stamp>.
place() {
  local src="$1" dest="$2"
  if [ -e "$dest" ]; then
    if diff -rq "$src" "$dest" >/dev/null 2>&1; then
      return 0
    fi
    mv "$dest" "$dest.bak.$stamp"
    echo "Backed up $dest -> $dest.bak.$stamp"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

place_configs() {
  local xdg_config app_config item skill
  xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [ "$os" = "darwin" ]; then
    app_config="$HOME/Library/Application Support"
  else
    app_config="$xdg_config"
  fi

  log "Placing configs"
  place "$repo/config/nvim" "$xdg_config/nvim"
  place "$repo/config/gitti/config.json" "$app_config/gitti/config.json"
  for item in koshi.kdl keybinding.kdl themes profile; do
    place "$repo/config/koshi/$item" "$app_config/koshi/$item"
  done
  place "$repo/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  place "$repo/config/claude/RTK.md" "$HOME/.claude/RTK.md"
  for skill in "$repo"/config/claude/skills/*; do
    place "$skill" "$HOME/.claude/skills/$(basename "$skill")"
  done
}

install_claude_plugins() {
  local name source commit location branch plugin
  log "Installing Claude Code plugins from the locked marketplace commits"
  awk '$1 == "marketplace" {print $2, $3, $4}' "$lock" >"$tmp_dir/marketplaces"
  awk '$1 == "plugin" {print $2}' "$lock" >"$tmp_dir/plugins"
  # The env var stops Claude from adding the latest official marketplace before the pinned one.
  # </dev/null keeps `claude` from reading the rest of the list as input.
  while read -r name source commit; do
    CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1 \
      claude plugin marketplace add "$source" </dev/null
    # A marketplace source takes a branch or tag, not a commit (code.claude.com/docs/en/plugins/
    # marketplace-reference), so move the clone to the locked commit as if it had been cloned
    # there: the branch and its upstream both point at the commit, and later updates fetch on.
    location="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["installLocation"])' \
      "$HOME/.claude/plugins/known_marketplaces.json" "$name")"
    # Claude may download a marketplace as an archive (its commit in .gcs-sha) instead of a
    # clone. Then git -C would act on the repo around it, so only check the commit.
    if [ "$(git -C "$location" rev-parse --show-toplevel 2>/dev/null)" != "$(cd "$location" && pwd -P)" ]; then
      if [ "$(cat "$location/.gcs-sha" 2>/dev/null)" != "$commit" ]; then
        die "Marketplace $name was downloaded at another commit than the locked $commit."
      fi
      continue
    fi
    if ! git -C "$location" cat-file -e "$commit^{commit}" 2>/dev/null; then
      git -C "$location" fetch --depth 1 origin "$commit" </dev/null
    fi
    branch="$(git -C "$location" symbolic-ref --short HEAD)"
    git -C "$location" reset --hard "$commit"
    git -C "$location" update-ref "refs/remotes/origin/$branch" "$commit"
  done <"$tmp_dir/marketplaces"
  while read -r plugin; do
    CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1 \
      claude plugin install "$plugin" </dev/null
  done <"$tmp_dir/plugins"
}

# Runs after plugin install: the caveman statusline path holds a per-install version directory.
place_claude_settings() {
  local statusline="" candidate
  for candidate in "$HOME"/.claude/plugins/cache/caveman/caveman/*/hooks/caveman-statusline.sh; do
    if [ -f "$candidate" ]; then
      statusline="$candidate"
    fi
  done
  if [ -z "$statusline" ] && grep -q 'caveman-statusline.sh' "$repo/config/claude/settings.json"; then
    die "settings.json uses the caveman statusline, but the caveman plugin has no statusline script."
  fi
  python3 - "$repo/config/claude/settings.json" "$HOME" "$statusline" >"$tmp_dir/settings.json" <<'PY'
import re, sys

source, home, statusline = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(source).read()
if statusline:
    pattern = r"__HOME__/\.claude/plugins/cache/caveman/caveman/[^/]*/hooks/caveman-statusline\.sh"
    # A function as the replacement inserts the path as-is, without escape processing.
    text = re.sub(pattern, lambda match: statusline, text)
sys.stdout.write(text.replace("__HOME__", home))
PY
  place "$tmp_dir/settings.json" "$HOME/.claude/settings.json"
}

bootstrap_neovim() {
  local registry packages mason_failed=0
  # The first start installs NvChad, and only then can lazy see the plugins NvChad imports. Lazy
  # writes lazy-lock.json after that install with only the plugins it knew (M.update in
  # lua/lazy/manage/lock.lua), then installs the rest at their latest commits. So put the
  # lockfile back and restore again, with every plugin known.
  log "Installing Neovim plugins at lazy-lock.json commits"
  nvim --headless "+Lazy! restore" +qa
  cp "$repo/config/nvim/lazy-lock.json" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json"
  nvim --headless "+Lazy! restore" +qa

  # install() runs async; :wait() blocks so headless nvim does not quit first. It compiles up to
  # 100 parsers at once by default (MAX_JOBS in install.lua), which runs a small machine out of
  # memory, so allow one compile per CPU. tree-sitter build compiles with cc-rs, which adds -Wall
  # only when CFLAGS is unset (try_get_compiler in cc-rs src/lib.rs). GCC 12 (Debian 12) never
  # finishes the gitcommit parser with -Wall (github.com/gbprod/tree-sitter-gitcommit/issues/89),
  # so set CFLAGS, empty.
  log "Installing the locked treesitter parsers"
  awk '$1 == "parser" {print $2}' "$lock" >"$tmp_dir/parsers"
  CFLAGS="" TS_PARSERS="$tmp_dir/parsers" nvim --headless "+Lazy! load nvim-treesitter" \
    "+lua require('nvim-treesitter').install(vim.fn.readfile(vim.env.TS_PARSERS), { max_jobs = vim.uv.available_parallelism() }):wait(3600000)" +qa

  # Headless :MasonInstall blocks, accepts name@version, and exits non-zero on any failure.
  # A failure does not stop setup here: verify.sh then lists every package that is missing.
  # Each package installs from the registry version the source Mac used for it: definitions
  # change between registry versions (jdtls's download URL holds a build timestamp that only the
  # registry of its release has). prepend() puts that version in place of the default registry
  # (LazySourceCollection in lua/mason-registry/sources/init.lua).
  log "Installing the locked Mason packages"
  for registry in $(awk -v gap="$mason_gap" '$1 == "mason" && $2 != gap {print $4}' "$lock" | sort -u); do
    packages="$(awk -v gap="$mason_gap" -v registry="$registry" \
      '$1 == "mason" && $2 != gap && $4 == registry {printf "%s@%s ", $2, $3}' "$lock")"
    if ! retry nvim --headless "+lua require('mason-registry').sources:prepend('$registry')" \
      "+MasonInstall $packages" +qa; then
      mason_failed=1
    fi
  done
  if [ "$mason_failed" -eq 1 ]; then
    log "Mason reported failures; verify.sh lists the affected packages"
  fi
}

if [ "$os" = "darwin" ]; then
  install_macos_base
else
  install_linux_base
fi
install_runtimes
write_env
install_tools
install_mason_gap
place_configs
install_claude_plugins
place_claude_settings
bootstrap_neovim

log "Verifying"
bash "$repo/verify.sh"

log "Done. Open a new shell, then run 'claude' to log in."
