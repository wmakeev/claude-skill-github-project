#!/usr/bin/env bash
# Common helpers for github-project skill scripts.
# Source this file: `source "$(dirname "$0")/lib/common.sh"`

set -euo pipefail

# --- Paths --------------------------------------------------------------------

BOT_HOME="${HOME}/.config/claude-github-bot"
BOT_CONFIG="${BOT_HOME}/config.json"
BOT_TOKEN_SCRIPT="${BOT_HOME}/get_token.py"

# Project config in the repo root. Single file with everything Claude needs
# to talk to a specific project: owner, project number. Project node ID and
# all field/option IDs are resolved on the fly to avoid stale-cache problems.
PROJECT_CONFIG_FILE="claude-project.json"

# --- Logging ------------------------------------------------------------------

log_info()  { printf '\033[0;36m[info]\033[0m  %s\n' "$*" >&2; }
log_warn()  { printf '\033[0;33m[warn]\033[0m  %s\n' "$*" >&2; }
log_error() { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }
log_ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$*" >&2; }

# --- TTY detection ------------------------------------------------------------

# is_tty — true if /dev/tty is readable (interactive terminal available).
is_tty() { [[ -r /dev/tty ]]; }

# --- Confirmation prompt (interactive) ----------------------------------------
# Used before every modifying action. Defaults to "no" — requires explicit yes.
# Bypass with NONINTERACTIVE=1 (e.g. for tests; not recommended in normal use).

confirm() {
    local prompt="${1:-Proceed?}"
    [[ "${NONINTERACTIVE:-0}" == "1" ]] && return 0
    if ! is_tty; then
        log_error "No TTY available and NONINTERACTIVE=1 not set; refusing to prompt for: $prompt"
        return 1
    fi
    local reply
    read -r -p "$prompt [y/N] " reply </dev/tty
    [[ "$reply" =~ ^[Yy]$ ]]
}

# --- Tool checks --------------------------------------------------------------

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

# --- Repo detection -----------------------------------------------------------

# Read owner/name of the current repo from git remote.
# Outputs "<owner>\t<name>" on stdout.
detect_repo() {
    local url
    url=$(git config --get remote.origin.url 2>/dev/null) || {
        log_error "Not a git repository or no 'origin' remote configured."
        return 1
    }
    # Normalise both ssh (git@github.com:owner/repo.git) and https forms.
    local path="${url#*github.com[:/]}"
    path="${path%.git}"
    local owner="${path%%/*}"
    local name="${path##*/}"
    if [[ -z "$owner" || -z "$name" || "$owner" == "$path" ]]; then
        log_error "Could not parse owner/repo from remote: $url"
        return 1
    fi
    printf '%s\t%s\n' "$owner" "$name"
}

# --- Bot config / token -------------------------------------------------------

bot_is_installed() {
    [[ -f "$BOT_CONFIG" && -f "$BOT_TOKEN_SCRIPT" ]]
}

# Read a value from bot config (jq path, e.g. .app_id).
bot_config_get() {
    local path="$1"
    jq -r "$path" "$BOT_CONFIG"
}

# Issue an installation token for the current repo.
# Prints token on stdout. Caches per-script invocation.
_BOT_TOKEN_CACHE=""
bot_token() {
    if [[ -n "$_BOT_TOKEN_CACHE" ]]; then
        printf '%s\n' "$_BOT_TOKEN_CACHE"
        return 0
    fi
    if ! bot_is_installed; then
        log_error "Bot is not installed. Run: scripts/setup-bot.sh"
        return 1
    fi
    _BOT_TOKEN_CACHE=$(python3 "$BOT_TOKEN_SCRIPT") || {
        log_error "Failed to get bot token. Check $BOT_CONFIG and key file."
        return 1
    }
    printf '%s\n' "$_BOT_TOKEN_CACHE"
}

# --- Project config (in-repo) -------------------------------------------------

project_config_exists() {
    [[ -f "$PROJECT_CONFIG_FILE" ]]
}

project_config_get() {
    local path="$1"
    jq -r "$path" "$PROJECT_CONFIG_FILE"
}

