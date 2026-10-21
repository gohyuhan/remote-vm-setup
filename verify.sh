#!/usr/bin/env bash
# Check that this machine matches the repo: every tool is at its locked version, every config
# is in place and identical, and Claude plugins, Neovim plugins, treesitter parsers, and Mason
# packages are installed at their locked versions. Prints one line per check; exits non-zero
# if any check fails. setup.sh runs it last.
set -uo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
lock="$repo/config/versions.lock"
env_file="$HOME/.config/remote-vm-setup/env.sh"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
if [ "$(uname -s)" = "Darwin" ]; then
  app_config="$HOME/Library/Application Support"
else
  app_config="$config_dir"
fi
failures=0

# Same table as setup.sh: Mason has no build of this package for this platform, so setup.sh
# installs it from the project's own release instead.
case "$(uname -s)-$(uname -m)" in
  Linux-aarch64 | Linux-arm64) mason_gap="clangd" ;;
  Darwin-x86_64) mason_gap="swiftlint" ;;
  *) mason_gap="" ;;
esac

# check NAME COMMAND...: pass when COMMAND exits 0; on failure, show its output.
check() {
  local name="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"
    printf '%s\n' "$output" | head -n 20 | sed 's/^/      /'
    failures=$((failures + 1))
  fi
}

# locked KIND NAME: the version column of that lock line.
locked() {
  awk -v kind="$1" -v name="$2" '$1 == kind && $2 == name {print $3}' "$lock"
}

# version_of COMMAND...: the first x.y[.z] number in the command's first output line, or nothing
# if the command fails (an error such as "GLIBC_2.38 not found" holds a number too).
version_of() {
  local output
  output="$("$@" 2>&1)" || return 1
  printf '%s\n' "$output" | sed -n 1p | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed -n 1p
}

# newer A B: true when version A is greater than version B.
newer() {
  python3 - "$1" "$2" <<'PY'
import sys

installed = [int(part) for part in sys.argv[1].split(".")]
locked = [int(part) for part in sys.argv[2].split(".")]
sys.exit(0 if installed > locked else 1)
PY
}

# version_matches NAME COMMAND...: the installed version equals the lock. Claude Code, gitti,
# and koshi update themselves, so a newer version of those passes too.
version_matches() {
  local name="$1" want got
  shift
  want="$(locked tool "$name")"
  got="$(version_of "$@")"
  if [ "$got" = "$want" ]; then
    return 0
  fi
  case "$name" in
    claude-code | gitti | koshi)
      if [ -n "$got" ] && newer "$got" "$want"; then
        return 0
      fi
      ;;
  esac
  echo "lock $want; $1 printed: $("$@" 2>&1 | sed -n 1p)"
  return 1
}

# mason_gap_matches: the upstream build of $mason_gap is on PATH at the locked Mason version.
mason_gap_matches() {
  local want got
  want="$(locked mason "$mason_gap")"
  case "$mason_gap" in
    clangd) got="$(version_of clangd --version)" ;;
    swiftlint) got="$(version_of swiftlint version)" ;;
  esac
  if [ "$got" != "$want" ]; then
    echo "installed ${got:-nothing}, lock $want"
    return 1
  fi
}

# all_present DIR SUFFIX LIST_FILE: fail and print each LIST_FILE entry with no DIR/<entry><SUFFIX>.
all_present() {
  local name missing=0
  while read -r name; do
    if [ ! -e "$1/$name$2" ]; then
      echo "missing: $name"
      missing=1
    fi
  done <"$3"
  return "$missing"
}

nvim_starts_clean() {
  local output
  output="$(nvim --headless +qa 2>&1)"
  if [ -n "$output" ]; then
    echo "$output"
    return 1
  fi
}

check "env file $env_file" test -f "$env_file"
. "$env_file"

echo "Tools:"
check "neovim $(locked tool neovim)" version_matches neovim nvim --version
check "go $(locked tool go)" version_matches go go version
check "node $(locked tool node)" version_matches node node --version
check "python3 $(locked tool python)" version_matches python python3 --version
check "rust $(locked tool rust)" version_matches rust rustc --version
check "ripgrep $(locked tool ripgrep)" version_matches ripgrep rg --version
check "fd $(locked tool fd)" version_matches fd fd --version
check "tree-sitter CLI $(locked tool tree-sitter-cli)" version_matches tree-sitter-cli tree-sitter --version
check "gopls $(locked tool gopls)" version_matches gopls gopls version
check "uv $(locked tool uv)" version_matches uv uv --version
check "rtk $(locked tool rtk)" version_matches rtk rtk --version
check "gitti $(locked tool gitti)" version_matches gitti gitti --version
check "koshi $(locked tool koshi)" version_matches koshi koshi --version
check "claude $(locked tool claude-code)" version_matches claude-code claude --version
check "pre-commit $(locked tool pre-commit)" version_matches pre-commit pre-commit --version
check "rust-analyzer" rust-analyzer --version
check "npm" npm --version
check "python3 venv" python3 -m venv --help
check "git" git --version
check "zsh at /bin/zsh (koshi default-shell)" /bin/zsh -c true

echo "Configs:"
check "nvim config" diff -r "$repo/config/nvim" "$config_dir/nvim"
check "gitti config" diff "$repo/config/gitti/config.json" "$app_config/gitti/config.json"
for item in koshi.kdl keybinding.kdl themes profile; do
  check "koshi $item" diff -r "$repo/config/koshi/$item" "$app_config/koshi/$item"
done
check "koshi config check" koshi config check
check "claude CLAUDE.md" diff "$repo/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
check "claude RTK.md" diff "$repo/config/claude/RTK.md" "$HOME/.claude/RTK.md"
for skill in "$repo"/config/claude/skills/*; do
  check "claude skill $(basename "$skill")" diff -r "$skill" "$HOME/.claude/skills/$(basename "$skill")"
done
check "claude settings.json: valid, every hook/statusline path exists" \
  python3 - "$HOME/.claude/settings.json" <<'PY'
import json, os, shlex, shutil, sys

text = open(sys.argv[1]).read()
settings = json.loads(text)
if "__HOME__" in text:
    sys.exit("__HOME__ placeholder left in settings.json")
commands = []
if "statusLine" in settings:
    commands.append(settings["statusLine"]["command"])
for groups in settings.get("hooks", {}).values():
    for group in groups:
        for hook in group["hooks"]:
            commands.append(hook["command"])
for command in commands:
    words = shlex.split(command)
    if not shutil.which(words[0]):
        sys.exit("program not found: " + words[0])
    for word in words[1:]:
        if word.startswith("/") and not os.path.exists(word):
            sys.exit("file not found: " + word)
PY

echo "Plugins:"
# A plugin from a marketplace with autoUpdate on may already be newer than the lock.
check "claude plugins at locked versions" \
  python3 - "$lock" "$HOME/.claude/plugins/installed_plugins.json" "$repo/config/claude/settings.json" <<'PY'
import json, os, sys

installed = json.load(open(sys.argv[2]))["plugins"]
marketplaces = json.load(open(sys.argv[3])).get("extraKnownMarketplaces", {})
wrong = []
for line in open(sys.argv[1]):
    parts = line.split()
    if len(parts) != 4 or parts[0] != "plugin":
        continue
    plugin, version = parts[1], parts[2]
    entries = installed.get(plugin)
    if not entries or not os.path.isdir(entries[0]["installPath"]):
        wrong.append(plugin + " (missing)")
        continue
    auto_update = marketplaces.get(plugin.split("@")[1], {}).get("autoUpdate", False)
    if entries[0]["version"] != version and not auto_update:
        wrong.append("%s (%s, lock %s)" % (plugin, entries[0]["version"], version))
if wrong:
    sys.exit("wrong: " + ", ".join(wrong))
PY
check "nvim plugins at lazy-lock.json commits" \
  python3 - "$repo/config/nvim/lazy-lock.json" "$data_dir/lazy" <<'PY'
import json, subprocess, sys

wrong = []
for name, info in json.load(open(sys.argv[1])).items():
    result = subprocess.run(["git", "-C", sys.argv[2] + "/" + name, "rev-parse", "HEAD"],
                            capture_output=True, text=True)
    if result.stdout.strip() != info["commit"]:
        wrong.append(name)
if wrong:
    sys.exit("missing or wrong commit: " + ", ".join(wrong))
PY
parsers="$(mktemp)"
awk '$1 == "parser" {print $2}' "$lock" >"$parsers"
check "treesitter parsers" all_present "$data_dir/site/parser" .so "$parsers"
rm -f "$parsers"
check "mason packages at locked versions" \
  python3 - "$lock" "$data_dir/mason/packages" "$mason_gap" <<'PY'
import json, sys

wrong = []
for line in open(sys.argv[1]):
    parts = line.split()
    if len(parts) != 4 or parts[0] != "mason" or parts[1] == sys.argv[3]:
        continue
    name, version = parts[1], parts[2]
    try:
        receipt = json.load(open("%s/%s/mason-receipt.json" % (sys.argv[2], name)))
        installed = receipt["source"]["id"].rsplit("@", 1)[1]
    except OSError:
        installed = "missing"
    if installed != version:
        wrong.append("%s (%s, lock %s)" % (name, installed, version))
if wrong:
    sys.exit("wrong: " + ", ".join(wrong))
PY
if [ -n "$mason_gap" ] && [ -n "$(locked mason "$mason_gap")" ]; then
  check "$mason_gap $(locked mason "$mason_gap") (upstream release; Mason has no build here)" mason_gap_matches
fi
check "nvim starts with no errors" nvim_starts_clean

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
