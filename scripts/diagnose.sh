#!/usr/bin/env bash
# Self-diagnostic for the github-project skill.
#
# Checks each layer in order and reports status. Output is structured so
# Claude can parse it and decide what to fix:
#
#   [PASS] <component>: <message>
#   [WARN] <component>: <message>          # works but should be addressed
#   [FAIL] <component>: <message>          # blocks further use
#   [INFO] suggestion: <command to run>    # actionable next step
#
# Exit codes:
#   0 — all green
#   1 — at least one WARN, no FAIL
#   2 — at least one FAIL

set +e  # do not abort on the first failed check; we want a full picture
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/project-spec.sh"

EXIT_CODE=0
mark_warn() { [[ $EXIT_CODE -lt 1 ]] && EXIT_CODE=1; }
mark_fail() { EXIT_CODE=2; }

pass() { echo "[PASS] $1: $2"; }
warn() { echo "[WARN] $1: $2"; mark_warn; }
fail() { echo "[FAIL] $1: $2"; mark_fail; }
hint() { echo "[INFO] suggestion: $1"; }

# --- Required commands --------------------------------------------------------

for cmd in gh jq git python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "tools" "$cmd available"
    else
        fail "tools" "$cmd not found"
    fi
done

# Require gh >= 2.20 for the `gh project` subcommand.
if command -v gh >/dev/null 2>&1; then
    gh_ver=$(gh --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    gh_major=$(printf '%s' "$gh_ver" | cut -d. -f1)
    gh_minor=$(printf '%s' "$gh_ver" | cut -d. -f2)
    if [[ $gh_major -gt 2 || ($gh_major -eq 2 && $gh_minor -ge 20) ]]; then
        pass "tools" "gh $gh_ver has 'gh project' subcommand"
    else
        fail "tools" "gh $gh_ver is too old; need >= 2.20 for 'gh project' subcommand"
        hint "upgrade gh: https://cli.github.com"
    fi
fi

# --- gh auth ------------------------------------------------------------------

if gh auth status >/dev/null 2>&1; then
    pass "gh-auth" "authenticated"
else
    fail "gh-auth" "gh is not authenticated"
    hint "run: gh auth login"
fi

# --- Bot installation ---------------------------------------------------------

if [[ -d "$BOT_HOME" ]]; then
    pass "bot-dir" "$BOT_HOME exists"
else
    fail "bot-dir" "$BOT_HOME missing"
    hint "run: scripts/setup-bot.sh"
fi

if [[ -f "$BOT_CONFIG" ]]; then
    pass "bot-config" "$BOT_CONFIG present"
    # Sanity-check required keys.
    for key in app_id installation_id private_key_path bot_login; do
        val=$(jq -r ".$key // empty" "$BOT_CONFIG" 2>/dev/null)
        if [[ -z "$val" ]]; then
            warn "bot-config" "field '$key' is empty in config"
            hint "run: scripts/setup-bot.sh to repair"
        fi
    done
    key_path=$(jq -r '.private_key_path' "$BOT_CONFIG" 2>/dev/null)
    if [[ -n "$key_path" && -f "$key_path" ]]; then
        pass "bot-key" "private key present"
    else
        fail "bot-key" "private key missing at $key_path"
        hint "run: scripts/setup-bot.sh"
    fi
else
    fail "bot-config" "$BOT_CONFIG missing"
    hint "run: scripts/setup-bot.sh"
fi

if [[ -f "$BOT_TOKEN_SCRIPT" ]]; then
    pass "bot-script" "get_token.py installed"
    if ! cmp -s "$SCRIPT_DIR/get_token.py" "$BOT_TOKEN_SCRIPT"; then
        warn "bot-script" "installed get_token.py differs from skill version"
        hint "run: scripts/setup-bot.sh to refresh"
    fi
else
    fail "bot-script" "get_token.py missing in $BOT_HOME"
    hint "run: scripts/setup-bot.sh"
fi

# Try a real token call only if config + key + script all present.
if [[ -f "$BOT_CONFIG" && -f "$BOT_TOKEN_SCRIPT" ]]; then
    token_out=$(python3 "$BOT_TOKEN_SCRIPT" 2>&1)
    rc=$?
    if [[ $rc -eq 0 && -n "$token_out" ]]; then
        login=$(GH_TOKEN="$token_out" gh api user --jq '.login' 2>/dev/null)
        if [[ -n "$login" ]]; then
            pass "bot-token" "token issues correctly, identity: $login"
            expected=$(jq -r '.bot_login // empty' "$BOT_CONFIG")
            if [[ -n "$expected" && "$expected" != "$login" ]]; then
                warn "bot-token" "actual login '$login' != config bot_login '$expected'"
            fi
        else
            warn "bot-token" "token issued but identity check failed"
        fi
    else
        fail "bot-token" "token request failed (rc=$rc)"
        echo "$token_out" | sed 's/^/        /'
        hint "the App may not be installed on this repo, or installation_id is wrong"
        hint "fix at: https://github.com/settings/installations/$(jq -r '.installation_id // ""' "$BOT_CONFIG")"
    fi
fi

# --- Project config in repo ---------------------------------------------------

if project_config_exists; then
    pass "project-config" "$PROJECT_CONFIG_FILE present"
    owner=$(project_config_get '.owner')
    pnum=$(project_config_get '.project_number')
    if [[ -z "$owner" || -z "$pnum" ]]; then
        fail "project-config" "owner or project_number missing"
        hint "run: scripts/setup-project.sh"
    fi
else
    warn "project-config" "$PROJECT_CONFIG_FILE not found in repo root"
    hint "run: scripts/setup-project.sh"
fi

# --- Project state on GitHub --------------------------------------------------

if project_config_exists && command -v gh >/dev/null 2>&1; then
    owner=$(project_config_get '.owner')
    pnum=$(project_config_get '.project_number')

    view_json=$(gh project view "$pnum" --owner "$owner" --format json 2>/dev/null)
    pid=$(printf '%s' "$view_json" | jq -r '.id // empty')
    if [[ -z "$pid" ]]; then
        fail "project" "project #$pnum not accessible for $owner"
        hint "check that the project exists and gh has access"
    else
        pass "project" "project '$(printf '%s' "$view_json" | jq -r '.title')' resolved"
        fields_json=$(gh project field-list "$pnum" --owner "$owner" --format json 2>/dev/null)
        # Verify each managed field exists.
        for f in "${SPEC_CUSTOM_FIELDS[@]}"; do
            if printf '%s' "$fields_json" | jq -e --arg n "$f" \
                '.fields | any(.name == $n)' >/dev/null
            then
                pass "field-$f" "exists"
            else
                warn "field-$f" "missing"
                hint "run: scripts/setup-project.sh"
            fi
        done
        # Verify Status options.
        actual_status=$(printf '%s' "$fields_json" | jq -c \
            '.fields | map(select(.name == "Status")) | .[0].options // [] | map(.name)')
        spec_status=$(printf '%s\n' "$SPEC_STATUS_OPTIONS" | jq -Rcs \
            'split("\n") | map(select(length > 0)) | map(split("\t")[0])')
        if [[ "$actual_status" == "$spec_status" ]]; then
            pass "field-Status" "options match spec"
        else
            warn "field-Status" "options drift from spec"
            hint "fix in project UI; spec is: $(printf '%s' "$spec_status" | jq -r 'join(" → ")')"
        fi
    fi
fi

# --- Repo labels --------------------------------------------------------------

if repo_info=$(detect_repo 2>/dev/null); then
    owner=$(printf '%s' "$repo_info" | cut -f1)
    name=$(printf  '%s' "$repo_info" | cut -f2)
    existing=$(gh api "repos/$owner/$name/labels" --paginate --jq '.[].name' 2>/dev/null | sort -u)
    missing_count=0
    while IFS=$'\t' read -r lname _ _; do
        [[ -z "$lname" ]] && continue
        if printf '%s\n' "$existing" | grep -qx "$lname"; then
            pass "label-$lname" "exists"
        else
            warn "label-$lname" "missing"
            missing_count=$((missing_count + 1))
        fi
    done <<< "$SPEC_LABELS"
    if [[ $missing_count -gt 0 ]]; then
        hint "run: scripts/setup-project.sh to create missing labels"
    fi
else
    warn "repo" "not in a git repo with github remote"
fi

# --- Templates / CLAUDE.md ----------------------------------------------------

if [[ -f ".github/ISSUE_TEMPLATE/task.md" ]]; then
    if cmp -s "$SCRIPT_DIR/../templates/issue-task.md" ".github/ISSUE_TEMPLATE/task.md"; then
        pass "issue-template" "up to date"
    else
        warn "issue-template" "differs from skill version"
    fi
else
    warn "issue-template" ".github/ISSUE_TEMPLATE/task.md missing"
    hint "run: scripts/setup-project.sh"
fi

if [[ -f "CLAUDE.md" ]] && grep -qF "BEGIN github-project skill workflow" CLAUDE.md; then
    pass "claude-md" "workflow section present"
else
    warn "claude-md" "workflow section not in CLAUDE.md"
    hint "run: scripts/setup-project.sh"
fi

exit $EXIT_CODE
