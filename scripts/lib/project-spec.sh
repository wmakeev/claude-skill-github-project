# Project Specification
# ---------------------
# Single source of truth for the desired state of a GitHub Project
# managed by this skill. Setup and diagnose scripts read this file
# and bring the actual project to match.
#
# Format: each spec is a multi-line string with TSV records.
# Rationale: keeps everything in plain bash without YAML/JSON parsing
# dependencies; trivially editable.

# --- Status field options -----------------------------------------------------
# Status is created by GitHub when the project is initialised from the Board
# template. We do NOT recreate it; we only verify the expected options exist
# in the right order. If options differ, diagnose will report a drift.
#
# Format: name<TAB>color
SPEC_STATUS_OPTIONS=$(cat <<'EOF'
Backlog	GRAY
Todo	BLUE
In Progress	YELLOW
In Review	PURPLE
Done	GREEN
EOF
)

# --- Single-select custom fields ----------------------------------------------
# Format per field block:
#   <option_name>	<color>
#   ...
#
# Colors follow GitHub's enum: GRAY, BLUE, GREEN, YELLOW, ORANGE, RED, PINK, PURPLE.
# Colors are NOT applied programmatically (gh project field-create does not support
# per-option colors). They serve as a reference for manual UI configuration.
# Convention: Impact/Effort use traffic-light palette (red = highest/largest).

SPEC_FIELD_IMPACT=$(cat <<'EOF'
Very High	RED
High	ORANGE
Medium	YELLOW
Low	BLUE
EOF
)

SPEC_FIELD_EFFORT=$(cat <<'EOF'
Trivial	GREEN
Small	BLUE
Medium	YELLOW
Large	RED
EOF
)

# Direction is project-specific (depends on the codebase's domains).
# It must exist as a SINGLE_SELECT field, but its options are NOT enforced
# by the spec — they are managed manually via the GitHub UI as new
# directions emerge. Diagnose will only check that the field exists.
SPEC_FIELD_DIRECTION_NAME="Direction"

# Names of all custom fields managed by the spec, in creation order.
SPEC_CUSTOM_FIELDS=(Impact Effort Direction)

# --- Repository labels --------------------------------------------------------
# Labels describe what an issue *is*, not planning metadata.
# Format: name<TAB>color<TAB>description
# Color is a 6-char hex without '#'.
SPEC_LABELS=$(cat <<'EOF'
bug	d73a4a	Something is not working as intended
feature	a2eeef	New functionality
refactor	0052cc	Code restructuring without behaviour change
chore	c5def5	Tooling, build, dependencies, housekeeping
docs	0075ca	Documentation only
EOF
)
