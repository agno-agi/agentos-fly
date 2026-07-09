#!/bin/bash

############################################################################
#
#    Agno Fly.io Environment Sync
#
#    Usage:
#      ./scripts/fly/env-sync.sh             # syncs .env.production
#      ./scripts/fly/env-sync.sh .env        # syncs .env instead
#
#    Reads the file and pushes every variable to the Fly app as secrets in
#    one call — a single restart, no matter how many variables changed.
#    Multi-line values (e.g. PEM-formatted JWT_VERIFICATION_KEY) are
#    handled correctly. Run from the repo root (reads fly.toml).
#
############################################################################

set -e

# Colors
ORANGE='\033[38;5;208m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

ENV_FILE="${1:-.env.production}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "File not found: $ENV_FILE"
    echo "Usage: $0 [path/to/env] (default: .env.production)"
    exit 1
fi

if command -v flyctl &> /dev/null; then
    FLY=flyctl
elif command -v fly &> /dev/null; then
    FLY=fly
else
    echo "flyctl not found. Install: https://fly.io/docs/flyctl/install/"
    exit 1
fi

APP_NAME="$(sed -nE 's/^app = "(.*)"$/\1/p' fly.toml 2>/dev/null | head -1)"
if [[ -z "$APP_NAME" || "$APP_NAME" == "agentos" ]]; then
    echo "fly.toml doesn't carry a provisioned app name. Run ./scripts/fly/up.sh first."
    exit 1
fi

echo ""
echo -e "${ORANGE}▸${NC} ${BOLD}Syncing env vars${NC}"
echo ""
echo -e "${DIM}> ${ENV_FILE} -> Fly app ${APP_NAME}${NC}"
echo ""

# Parse the env file, treating PEM blocks (and other multiline values)
# as a single variable. Collect everything into one `fly secrets set`
# call so the app restarts once.
SECRET_ARGS=()
current_key=""
current_value=""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments (only when not inside a multiline value)
    if [[ -z "$current_key" ]]; then
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    fi

    if [[ -z "$current_key" ]]; then
        # Start of a new variable
        current_key="${line%%=*}"
        current_value="${line#*=}"
    else
        # Continuation of a multiline value
        current_value="${current_value}
${line}"
    fi

    # Check if the value is complete (not in the middle of a PEM block)
    if [[ "$current_value" == *"-----BEGIN"* && "$current_value" != *"-----END"* ]]; then
        continue
    fi

    # Strip surrounding quotes if present
    current_value="${current_value#\"}"
    current_value="${current_value%\"}"
    current_value="${current_value#\'}"
    current_value="${current_value%\'}"

    echo -e "${DIM}  Staging ${current_key}${NC}"
    SECRET_ARGS+=("${current_key}=${current_value}")

    current_key=""
    current_value=""
done < "$ENV_FILE"

if [[ ${#SECRET_ARGS[@]} -eq 0 ]]; then
    echo "Nothing to sync."
    exit 0
fi

"$FLY" secrets set --app "$APP_NAME" "${SECRET_ARGS[@]}"

echo ""
echo -e "${BOLD}Done.${NC} Synced ${#SECRET_ARGS[@]} variable(s) to ${APP_NAME}."
echo -e "${DIM}Fly restarts the machine once with the new values.${NC}"
echo ""
