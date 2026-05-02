#!/usr/bin/env bash
# Set up the GitHub bot account on this machine.
#
# This is a one-time setup per machine, not per repo. The bot config and
# private key live under ~/.config/claude-github-bot/ and are reused by every
# project that uses this skill.
#
# Re-running this script is safe: it detects an existing config and offers
# to update individual fields rather than wiping everything.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_cmd python3
require_cmd jq

# --- Ensure ~/.config/claude-github-bot/ exists --------------------------------------

mkdir -p "$BOT_HOME"
chmod 700 "$BOT_HOME"

# --- Check Python deps --------------------------------------------------------

if ! python3 -c "import jwt, requests" >/dev/null 2>&1; then
    log_warn "Python deps missing: PyJWT and/or requests."
    if confirm "Install them now via pip?"; then
        pip install --user PyJWT requests
    else
        log_error "Cannot continue without PyJWT and requests."
        exit 1
    fi
fi

# --- Copy the token script ----------------------------------------------------

if [[ ! -f "$BOT_TOKEN_SCRIPT" ]] || \
   ! cmp -s "$SCRIPT_DIR/get_token.py" "$BOT_TOKEN_SCRIPT"; then
    if [[ -f "$BOT_TOKEN_SCRIPT" ]]; then
        log_info "Token script differs from skill version."
        confirm "Overwrite $BOT_TOKEN_SCRIPT?" || exit 1
    fi
    cp "$SCRIPT_DIR/get_token.py" "$BOT_TOKEN_SCRIPT"
    chmod 700 "$BOT_TOKEN_SCRIPT"
    log_ok "Token script installed."
fi

# --- Collect config -----------------------------------------------------------
# If a config exists, we keep current values as defaults so the user can
# just press Enter past the ones that didn't change.

declare -A current=()
if [[ -f "$BOT_CONFIG" ]]; then
    log_info "Existing bot config found at $BOT_CONFIG"
    current[app_id]=$(jq -r '.app_id // ""' "$BOT_CONFIG")
    current[installation_id]=$(jq -r '.installation_id // ""' "$BOT_CONFIG")
    current[private_key_path]=$(jq -r '.private_key_path // ""' "$BOT_CONFIG")
    current[bot_login]=$(jq -r '.bot_login // ""' "$BOT_CONFIG")
fi

ask_field() {
    local key="$1" label="$2"
    local default="${current[$key]:-}"
    local prompt="$label"
    [[ -n "$default" ]] && prompt+=" [$default]"
    prompt+=": "
    local value
    read -r -p "$prompt" value </dev/tty
    [[ -z "$value" ]] && value="$default"
    if [[ -z "$value" ]]; then
        log_error "$label is required."
        return 1
    fi
    printf '%s' "$value"
}

cat <<'EOF' >&2

To set up the bot you need a GitHub App with Issues (read/write) and Pull
Requests (read/write) permissions, installed on the repo(s) you plan to use.

If you don't have one yet:
  1. GitHub → Settings → Developer Settings → GitHub Apps → New GitHub App
  2. Generate and download a private key (.pem)
  3. Install the App on your account; note the installation ID from the URL
     (https://github.com/settings/installations/<id>)

EOF

app_id=$(ask_field app_id "App ID")
installation_id=$(ask_field installation_id "Installation ID")
key_path=$(ask_field private_key_path "Absolute path to private key (.pem)")
key_path="${key_path/#\~/$HOME}"

if [[ ! -f "$key_path" ]]; then
    log_error "Private key file not found: $key_path"
    exit 1
fi
chmod 600 "$key_path" 2>/dev/null || true

# bot_login is verified via API after writing the config — no need to ask.

# --- Write config -------------------------------------------------------------

new_config=$(jq -n \
    --arg app_id "$app_id" \
    --arg installation_id "$installation_id" \
    --arg key "$key_path" \
    --arg login "${current[bot_login]:-}" \
    '{app_id: $app_id, installation_id: $installation_id,
      private_key_path: $key, bot_login: $login}')

if [[ -f "$BOT_CONFIG" ]] && [[ "$(cat "$BOT_CONFIG")" == "$new_config" ]]; then
    log_info "Config unchanged."
else
    if [[ -f "$BOT_CONFIG" ]]; then
        confirm "Update existing $BOT_CONFIG?" || exit 1
    fi
    printf '%s\n' "$new_config" > "$BOT_CONFIG"
    chmod 600 "$BOT_CONFIG"
    log_ok "Config written to $BOT_CONFIG"
fi

# --- Verify token works and capture bot login ---------------------------------

log_info "Requesting installation token..."
token=$(python3 "$BOT_TOKEN_SCRIPT") || {
    log_error "Token generation failed. Check the App is installed on at least one repo."
    exit 1
}

log_info "Verifying token..."
login=$(GH_TOKEN="$token" gh api user --jq '.login') || {
    log_error "Token verification failed."
    exit 1
}

# Persist the verified login for diagnostics.
jq --arg l "$login" '.bot_login = $l' "$BOT_CONFIG" > "$BOT_CONFIG.tmp" \
    && mv "$BOT_CONFIG.tmp" "$BOT_CONFIG"
chmod 600 "$BOT_CONFIG"

log_ok "Bot is set up and authenticated as: $login"
