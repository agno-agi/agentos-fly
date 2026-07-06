#!/bin/bash

############################################################################
#
#    Agno Fly.io Teardown
#
#    Usage:
#      ./scripts/fly/down.sh          # asks before destroying
#      ./scripts/fly/down.sh --yes    # no prompt (CI / automation)
#
#    Destroys the Fly app AND its Postgres — all data in the database is
#    deleted. Run from the repo root (reads fly.toml). Verify afterwards
#    with `fly apps list`.
#
############################################################################

set -e

# Colors
DIM='\033[2m'
BOLD='\033[1m'
RED='\033[31m'
NC='\033[0m'

# Preflight
if command -v flyctl &> /dev/null; then
    FLY=flyctl
elif command -v fly &> /dev/null; then
    FLY=fly
else
    echo "flyctl not found. Install: https://fly.io/docs/flyctl/install/"
    exit 1
fi

if ! "$FLY" auth whoami &> /dev/null; then
    echo "Not logged in to Fly. Run: $FLY auth login"
    exit 1
fi

APP_NAME="$(sed -nE 's/^app = "(.*)"$/\1/p' fly.toml 2>/dev/null | head -1)"
if [[ -z "$APP_NAME" || "$APP_NAME" == "agentos" ]]; then
    echo "fly.toml doesn't carry a provisioned app name — nothing to tear down."
    exit 1
fi
PG_APP_NAME="${APP_NAME}-db"

echo ""
echo -e "${BOLD}This destroys:${NC}"
echo -e "  - app       ${APP_NAME}"
echo -e "  - postgres  ${PG_APP_NAME}  ${RED}(all data deleted)${NC}"
echo ""

if [[ "$1" != "--yes" ]]; then
    printf "Type the app name (%s) to confirm: " "$APP_NAME"
    IFS= read -r CONFIRM
    if [[ "$CONFIRM" != "$APP_NAME" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""
echo -e "${BOLD}Destroying ${APP_NAME}...${NC}"
"$FLY" apps destroy "$APP_NAME" --yes || echo -e "${DIM}Destroy returned non-zero — verifying below${NC}"

echo ""
echo -e "${BOLD}Destroying ${PG_APP_NAME}...${NC}"
"$FLY" apps destroy "$PG_APP_NAME" --yes || echo -e "${DIM}Destroy returned non-zero — verifying below${NC}"

# An app only counts as gone when Fly says so. `fly status` also exits
# non-zero on an expired token or network blip — treating that as "gone"
# would reset fly.toml while both apps are still alive.
app_confirmed_gone() {
    local app="$1" output
    if output="$("$FLY" status --app "$app" 2>&1)"; then
        return 1
    fi
    if grep -qi "could not find" <<< "$output"; then
        return 0
    fi
    echo ""
    echo -e "${BOLD}Couldn't verify ${app} is gone${NC} — fly status failed with:"
    echo -e "${DIM}${output}${NC}"
    echo -e "fly.toml keeps the app name so you can retry. Check: ${FLY} apps list"
    exit 1
}

# Only reset fly.toml once both apps are confirmed gone — resetting after a
# failed destroy (expired token, network blip) would orphan the generated
# name and leave the resources running with no record of them.
if ! app_confirmed_gone "$APP_NAME" || ! app_confirmed_gone "$PG_APP_NAME"; then
    echo ""
    echo -e "${BOLD}Teardown incomplete${NC} — at least one app still exists. fly.toml keeps"
    echo -e "the app name so you can retry. Check: ${FLY} apps list"
    exit 1
fi

# Reset fly.toml so a future up.sh provisions fresh
sed -i.bak -E "s|^app = .*|app = \"agentos\"|" fly.toml && rm -f fly.toml.bak
sed -i.bak -E "s|^primary_region = .*|primary_region = \"iad\"|" fly.toml && rm -f fly.toml.bak
sed -i.bak -E "s|^  AGENTOS_URL = .*|  AGENTOS_URL = \"https://agentos.fly.dev\"|" fly.toml && rm -f fly.toml.bak

echo ""
echo -e "${BOLD}Done.${NC} Both apps confirmed gone. Verify anytime with: ${FLY} apps list"
echo ""
