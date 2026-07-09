#!/bin/bash

############################################################################
#
#    Agno Fly.io Redeploy
#
#    Usage: ./scripts/fly/redeploy.sh
#
#    Redeploys the app to Fly after code changes. Run ./scripts/fly/up.sh
#    first for initial provisioning. Run from the repo root (reads fly.toml).
#
############################################################################

set -e

# Colors
ORANGE='\033[38;5;208m'
DIM='\033[2m'
BOLD='\033[1m'
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

APP_NAME="$(sed -nE 's/^app = "(.*)"$/\1/p' fly.toml 2>/dev/null | head -1)"
if [[ -z "$APP_NAME" || "$APP_NAME" == "agentos" ]]; then
    echo "fly.toml doesn't carry a provisioned app name. Run ./scripts/fly/up.sh first."
    exit 1
fi

echo ""
echo -e "${ORANGE}▸${NC} ${BOLD}Redeploying ${APP_NAME}${NC}"
echo ""
echo -e "${DIM}> ${FLY} deploy --ha=false${NC}"
echo ""
# --ha=false is load-bearing: the Fly default creates two machines, which
# doubles cost and runs two in-process schedulers double-firing every cron.
"$FLY" deploy --ha=false

echo ""
echo -e "${BOLD}Done.${NC}"
echo -e "${DIM}Logs: ${FLY} logs --app ${APP_NAME}${NC}"
echo ""
