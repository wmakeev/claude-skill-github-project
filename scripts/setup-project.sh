#!/usr/bin/env bash
# Bring the GitHub Project for the current repo to match the spec.
#
# Idempotent: queries actual state, computes diff against spec in
# lib/project-spec.sh, prints what would change, asks for confirmation,
# applies. Re-running when nothing has drifted is a no-op.
#
# This script does NOT create the Project itself — that's a one-time UI
# step (https://github.com/users/<you>/projects -> New project -> Board).
# It also does NOT create issues; those are managed manually via the
# issue template.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/project-spec.sh"

require_cmd gh
require_cmd jq

# --- Step 1: ensure project config exists in the repo -------------------------

if ! project_config_exists; then
    log_info "No $PROJECT_CONFIG_FILE in this repo yet."
    repo_info=$(detect_repo)
    owner=$(printf '%s' "$repo_info" | cut -f1)
    repo=$(printf  '%s' "$repo_info" | cut -f2)

    cat <<EOF >&2

Repo detected: $owner/$repo

Before continuing, make sure a Project (Board template) exists for this repo.
If not: open https://github.com/users/$owner/projects → New project → Board.

EOF
    read -r -p "Project number (the integer in the project URL): " project_number </dev/tty
    [[ "$project_number" =~ ^[0-9]+$ ]] || { log_error "Not a number."; exit 1; }

    confirm "Create $PROJECT_CONFIG_FILE with owner=$owner, project=$project_number?" \
        || exit 1
    jq -n --arg o "$owner" --argjson n "$project_number" \
        '{owner: $o, project_number: $n}' > "$PROJECT_CONFIG_FILE"
    log_ok "Wrote $PROJECT_CONFIG_FILE."
fi

OWNER=$(project_config_get '.owner')
PROJECT_NUMBER=$(project_config_get '.project_number')

# --- Step 2: resolve project node ID and its current fields -------------------

log_info "Querying current project state..."
view_json=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null)
project_id=$(printf '%s' "$view_json" | jq -r '.id // empty')
if [[ -z "$project_id" ]]; then
    log_error "Project #$PROJECT_NUMBER not found for user $OWNER."
    log_error "Either the project number is wrong or you lack access."
    exit 1
fi
log_ok "Project: $(printf '%s' "$view_json" | jq -r '.title') ($project_id)"

fields_json=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json)

# Extract current fields as a JSON object: { name -> {id, options:[{id, name}]} }
current_fields=$(printf '%s' "$fields_json" | jq '
    .fields
    | map(select(.name != null))
    | map({(.name): {id: .id, options: ((.options // []) | map({id, name}))}})
    | add // {}
')

# --- Step 3: ensure custom fields match spec ----------------------------------

# Ensure a single-select field exists with the given options.
# Args: <field name> <spec TSV (name<TAB>color per line)> [optional: skip-options]
ensure_singleselect_field() {
    local field_name="$1"
    local spec_tsv="$2"
    local skip_options="${3:-no}"

    local field_json
    field_json=$(printf '%s' "$current_fields" | jq --arg n "$field_name" '.[$n] // empty')

    if [[ -z "$field_json" ]]; then
        log_info "Field '$field_name' is missing."
        confirm "Create field '$field_name'?" || return 0
        if [[ "$skip_options" == "yes" ]]; then
            gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
                --name "$field_name" --data-type "SINGLE_SELECT" \
                --single-select-options "(unset)" >/dev/null
            log_ok "Created '$field_name' (options managed in the UI)."
        else
            local options_csv
            options_csv=$(printf '%s\n' "$spec_tsv" | awk -F'\t' 'NF>0 && $1!="" {printf "%s%s", sep, $1; sep=","} END{print ""}')
            gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
                --name "$field_name" --data-type "SINGLE_SELECT" \
                --single-select-options "$options_csv" >/dev/null
            log_ok "Created '$field_name'."
            log_warn "Option colors must be set manually. Open the project → '$field_name' field in GitHub UI and apply:"
            while IFS=$'\t' read -r opt_name opt_color; do
                [[ -z "$opt_name" ]] && continue
                log_warn "  $opt_name → $opt_color"
            done <<< "$spec_tsv"
        fi
        return 0
    fi

    if [[ "$skip_options" == "yes" ]]; then
        log_ok "Field '$field_name' exists (options not enforced)."
        return 0
    fi

    # Compare option names. We do not auto-delete or rename options because that
    # would silently destroy user data on existing items. We only report drift.
    local current_opts desired_opts
    current_opts=$(printf '%s' "$field_json" | jq -c '.options | map(.name)')
    desired_opts=$(printf '%s\n' "$spec_tsv" | jq -Rcs '
        split("\n") | map(select(length > 0))
        | map(split("\t")[0])
    ')
    if [[ "$current_opts" == "$desired_opts" ]]; then
        log_ok "Field '$field_name' matches spec."
    else
        log_warn "Field '$field_name' options drift from spec:"
        diff <(printf '%s' "$current_opts" | jq .) <(printf '%s' "$desired_opts" | jq .) || true
        log_warn "Auto-fixing options is not supported (would risk losing data on existing items)."
        log_warn "Resolve manually in the project UI, then re-run this script."
    fi
}

ensure_singleselect_field "Impact"    "$SPEC_FIELD_IMPACT"
ensure_singleselect_field "Effort"    "$SPEC_FIELD_EFFORT"
ensure_singleselect_field "Direction" "" yes

# --- Step 4: ensure Status field has expected options -------------------------

status_json=$(printf '%s' "$current_fields" | jq '.Status // empty')
if [[ -z "$status_json" ]]; then
    log_warn "No Status field found. Was the project created from the Board template?"
    log_warn "Status is normally provided by GitHub. Skipping check."
else
    spec_status=$(printf '%s\n' "$SPEC_STATUS_OPTIONS" | jq -Rcs '
        split("\n") | map(select(length > 0))
        | map(split("\t") | {name: .[0]})
    ')
    actual_status=$(printf '%s' "$status_json" | jq -c '.options | map({name})')
    if [[ "$spec_status" == "$actual_status" ]]; then
        log_ok "Status field matches spec."
    else
        log_warn "Status options drift from spec (Backlog/Todo/In Progress/In Review/Done):"
        diff <(printf '%s' "$actual_status" | jq .) <(printf '%s' "$spec_status" | jq .) || true
    fi
fi

# --- Step 5: ensure repo labels exist -----------------------------------------

REPO_INFO=$(detect_repo)
REPO_OWNER=$(printf '%s' "$REPO_INFO" | cut -f1)
REPO_NAME=$(printf  '%s' "$REPO_INFO" | cut -f2)

log_info "Checking repo labels..."
existing_labels=$(gh api "repos/$REPO_OWNER/$REPO_NAME/labels" --paginate --jq '.[].name' \
    | sort -u)

while IFS=$'\t' read -r name color desc; do
    [[ -z "$name" ]] && continue
    if printf '%s\n' "$existing_labels" | grep -qx "$name"; then
        log_ok "Label '$name' exists."
    else
        log_info "Label '$name' is missing."
        if confirm "Create label '$name' (#$color)?"; then
            gh api "repos/$REPO_OWNER/$REPO_NAME/labels" -X POST \
                -f "name=$name" -f "color=$color" -f "description=$desc" \
                >/dev/null
            log_ok "Created '$name'."
        fi
    fi
done <<< "$SPEC_LABELS"

# --- Step 6: ensure issue template exists -------------------------------------

template_dir=".github/ISSUE_TEMPLATE"
template_file="$template_dir/task.md"
if [[ ! -f "$template_file" ]]; then
    if confirm "Create issue template at $template_file?"; then
        mkdir -p "$template_dir"
        cp "$SCRIPT_DIR/../templates/issue-task.md" "$template_file"
        log_ok "Created $template_file."
    fi
else
    if ! cmp -s "$SCRIPT_DIR/../templates/issue-task.md" "$template_file"; then
        log_info "Issue template differs from skill version."
        if confirm "Show diff?"; then
            diff "$template_file" "$SCRIPT_DIR/../templates/issue-task.md" || true
        fi
        if confirm "Overwrite with skill version?"; then
            cp "$SCRIPT_DIR/../templates/issue-task.md" "$template_file"
            log_ok "Updated."
        fi
    else
        log_ok "Issue template up to date."
    fi
fi

# --- Step 7: ensure CLAUDE.md has the workflow snippet ------------------------

CLAUDE_MD="CLAUDE.md"
SNIPPET_BEGIN="<!-- BEGIN github-project skill workflow -->"
SNIPPET_END="<!-- END github-project skill workflow -->"
SNIPPET_FILE="$SCRIPT_DIR/../templates/CLAUDE.md.snippet"

if [[ ! -f "$CLAUDE_MD" ]]; then
    if confirm "Create $CLAUDE_MD with workflow section?"; then
        {
            echo "# Project context for Claude Code"
            echo
            cat "$SNIPPET_FILE"
        } > "$CLAUDE_MD"
        log_ok "Created $CLAUDE_MD."
    fi
elif ! grep -qF "$SNIPPET_BEGIN" "$CLAUDE_MD"; then
    if confirm "Append workflow section to existing $CLAUDE_MD?"; then
        printf '\n' >> "$CLAUDE_MD"
        cat "$SNIPPET_FILE" >> "$CLAUDE_MD"
        log_ok "Appended workflow section."
    fi
else
    # Check if the snippet content is current.
    current_snippet=$(awk "/$SNIPPET_BEGIN/,/$SNIPPET_END/" "$CLAUDE_MD")
    spec_snippet=$(cat "$SNIPPET_FILE")
    if [[ "$current_snippet" != "$spec_snippet" ]]; then
        log_info "Workflow section in CLAUDE.md differs from skill version."
        if confirm "Show diff?"; then
            diff <(printf '%s\n' "$current_snippet") <(printf '%s\n' "$spec_snippet") || true
        fi
        if confirm "Replace with skill version?"; then
            # Use a temp file because in-place sed across markers is fiddly.
            awk -v begin="$SNIPPET_BEGIN" -v end="$SNIPPET_END" -v file="$SNIPPET_FILE" '
                $0 ~ begin { in_block=1; while ((getline line < file) > 0) print line; close(file); next }
                $0 ~ end   { in_block=0; next }
                !in_block  { print }
            ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
            log_ok "Updated workflow section."
        fi
    else
        log_ok "CLAUDE.md workflow section up to date."
    fi
fi

log_ok "Setup complete."
