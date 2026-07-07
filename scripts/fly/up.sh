#!/bin/bash

############################################################################
#
#    Agno Fly.io Setup (first-time provisioning)
#
#    Usage:     ./scripts/fly/up.sh
#    Redeploy:  ./scripts/fly/redeploy.sh
#    Sync env:  ./scripts/fly/env-sync.sh
#    Teardown:  ./scripts/fly/down.sh
#
#    Prerequisites:
#      - flyctl installed (https://fly.io/docs/flyctl/install/)
#      - Logged in via `fly auth login`
#      - OPENAI_API_KEY set in environment (or .env / .env.production)
#
#    Fly app names are global, so this generates `agentos-<suffix>` and
#    records it in fly.toml. The public URL is predictable pre-deploy
#    (https://<app>.fly.dev), so AGENTOS_URL is set before the first deploy.
#    Pauses for JWT_VERIFICATION_KEY/JWT_JWKS_FILE when production auth
#    would otherwise prevent the first deploy from serving.
#
#    Region defaults to iad (FLY_REGION=<region> to override); org defaults
#    to personal (FLY_ORG=<org> to override — app and Postgres share it).
#
############################################################################

set -e

# Colors
ORANGE='\033[38;5;208m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${ORANGE}"
cat << 'BANNER'
     █████╗  ██████╗ ███╗   ██╗ ██████╗
    ██╔══██╗██╔════╝ ████╗  ██║██╔═══██╗
    ███████║██║  ███╗██╔██╗ ██║██║   ██║
    ██╔══██║██║   ██║██║╚██╗██║██║   ██║
    ██║  ██║╚██████╔╝██║ ╚████║╚██████╔╝
    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝
BANNER
echo -e "${NC}"

# Persist a resolved single-line value back into the env file so it stays a
# faithful record of the deploy (and env-sync.sh keeps managing it). Replaces
# an existing commented-or-uncommented `KEY=` line in place; appends if the key
# is absent. Rewrites via the original file (not `mv`) so the file keeps its
# inode + permissions. The `|` sed delimiter avoids clashing with URL slashes.
# No-op when the file is missing.
persist_env_var() {
    local key="$1" value="$2" file="$3" tmp
    [[ -z "$file" || ! -f "$file" ]] && return
    if grep -qE "^[#[:space:]]*${key}=" "$file"; then
        tmp="$(mktemp)"
        if sed -E "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$file" > "$tmp"; then
            cat "$tmp" > "$file"
        fi
        rm -f "$tmp"
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$file"
    fi
}

# Persist a multi-line env value. Existing active KEY= blocks are removed before
# appending the new value; commented examples are left alone as documentation.
# Written quoted (KEY="...") — the form example.env documents so docker compose
# env_file parsing keeps the block as one value.
persist_multiline_env_var() {
    local key="$1" value="$2" file="$3" tmp line skipping=0 value_part
    [[ -z "$file" ]] && return
    if [[ ! -f "$file" ]]; then
        printf '%s="%s"\n' "$key" "$value" > "$file"
        return
    fi

    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$skipping" == 1 ]]; then
            [[ "$line" == *"-----END"* ]] && skipping=0
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*${key}= ]]; then
            value_part="${line#*=}"
            if [[ "$value_part" == *"-----BEGIN"* && "$value_part" != *"-----END"* ]]; then
                skipping=1
            fi
            continue
        fi

        printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    [[ -s "$tmp" ]] && printf '\n' >> "$tmp"
    printf '%s="%s"\n' "$key" "$value" >> "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

# Load env file — .env.production preferred, .env as fallback.
# Parsed line-by-line (not `source`d) so an unquoted multi-line PEM
# JWT_VERIFICATION_KEY isn't interpreted as shell. Mirrors the parser in
# env-sync.sh so both scripts read .env files identically. A function so
# the JWT pause below can re-read the file after the user edits it.
load_env_file() {
    local line current_key="" current_value=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$current_key" ]]; then
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        fi

        if [[ -z "$current_key" ]]; then
            current_key="${line%%=*}"
            current_value="${line#*=}"
        else
            current_value="${current_value}
${line}"
        fi

        # Still inside a PEM block — keep accumulating lines.
        if [[ "$current_value" == *"-----BEGIN"* && "$current_value" != *"-----END"* ]]; then
            continue
        fi

        # Strip surrounding quotes if present
        current_value="${current_value#\"}"
        current_value="${current_value%\"}"
        current_value="${current_value#\'}"
        current_value="${current_value%\'}"

        export "${current_key}=${current_value}"

        current_key=""
        current_value=""
    done < "$1"
}

# shellcheck disable=SC2034
capture_pasted_jwt_verification_key() {
    local first_line="$1" line pasted="$1"

    pasted="${pasted#export JWT_VERIFICATION_KEY=}"
    pasted="${pasted#JWT_VERIFICATION_KEY=}"
    [[ "$pasted" != *"-----BEGIN"* ]] && return 1

    while [[ "$pasted" != *"-----END"* ]]; do
        if ! IFS= read -r line; then
            break
        fi
        pasted="${pasted}
${line}"
    done

    [[ "$pasted" != *"-----BEGIN"* || "$pasted" != *"-----END"* ]] && return 1

    pasted="${pasted#\"}"
    pasted="${pasted%\"}"
    pasted="${pasted#\'}"
    pasted="${pasted%\'}"

    JWT_VERIFICATION_KEY="$pasted"
    export JWT_VERIFICATION_KEY
}

ENV_FILE=""
[[ -f .env.production ]] && ENV_FILE=".env.production"
[[ -z "$ENV_FILE" && -f .env ]] && ENV_FILE=".env"

if [[ -n "$ENV_FILE" ]]; then
    load_env_file "$ENV_FILE"
    echo -e "${DIM}Loaded ${ENV_FILE}${NC}"
fi

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

if [[ -z "$OPENAI_API_KEY" ]]; then
    echo "OPENAI_API_KEY not set. Add to .env (or .env.production) or export it."
    exit 1
fi

if [[ ! -f fly.toml ]]; then
    echo "fly.toml not found. Run this script from the repo root: ./scripts/fly/up.sh"
    exit 1
fi

REGION="${FLY_REGION:-iad}"
# App and Postgres must live in the SAME org or the private .flycast network
# between them doesn't exist. Default is the personal org; team accounts set
# FLY_ORG.
FLY_ORG="${FLY_ORG:-personal}"

# App name — global namespace, so generate a unique suffix and record it in
# fly.toml. If fly.toml already carries a generated name (previous run),
# reuse it so the script stays idempotent.
EXISTING_APP="$(sed -nE 's/^app = "(.*)"$/\1/p' fly.toml | head -1)"
if [[ "$EXISTING_APP" == agentos-* ]]; then
    APP_NAME="$EXISTING_APP"
    echo -e "${DIM}Reusing app name from fly.toml: ${APP_NAME}${NC}"
    # On reuse, keep the region fly.toml already carries — defaulting back to
    # iad here would rewrite primary_region away from the existing Postgres's
    # region, silently splitting app and DB. An explicit FLY_REGION still wins.
    if [[ -z "$FLY_REGION" ]]; then
        EXISTING_REGION="$(sed -nE 's/^primary_region = "(.*)"$/\1/p' fly.toml | head -1)"
        [[ -n "$EXISTING_REGION" ]] && REGION="$EXISTING_REGION"
    fi
elif [[ -n "$EXISTING_APP" && "$EXISTING_APP" != "agentos" ]]; then
    # A name this script didn't generate — continuing would overwrite fly.toml
    # and silently abandon that app.
    echo -e "${BOLD}fly.toml carries an app name this script doesn't manage: ${EXISTING_APP}${NC}"
    echo -e "Restore the ${BOLD}agentos${NC} placeholder (or an agentos-* name from a previous run)"
    echo -e "in fly.toml, or tear the app down first: ./scripts/fly/down.sh"
    exit 1
else
    SUFFIX="$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
    APP_NAME="agentos-${SUFFIX}"
fi
PG_APP_NAME="${APP_NAME}-db"

echo ""
echo -e "${BOLD}Creating app ${APP_NAME} (region ${REGION})...${NC}"
echo ""
"$FLY" apps create "$APP_NAME" --org "$FLY_ORG" || echo -e "${DIM}App already exists or name taken — continuing${NC}"

# Record the app name in fly.toml so every later fly command (deploy, logs,
# secrets) targets it without --app. Rewrite via sed -i.bak for BSD/GNU
# portability.
sed -i.bak -E "s|^app = .*|app = \"${APP_NAME}\"|" fly.toml && rm -f fly.toml.bak
# Pin app machines to the same region as Postgres: without primary_region,
# fly deploy places the machine in the region closest to whoever runs this
# script, silently splitting app and DB across regions.
sed -i.bak -E "s|^primary_region = .*|primary_region = \"${REGION}\"|" fly.toml && rm -f fly.toml.bak

# URL is predictable pre-deploy — set AGENTOS_URL before the first deploy so
# the scheduler is reachable from boot. Without it the scheduler defaults to
# http://127.0.0.1:8000 and scheduled jobs silently never fire in prod.
APP_URL="https://${APP_NAME}.fly.dev"
sed -i.bak -E "s|^  AGENTOS_URL = .*|  AGENTOS_URL = \"${APP_URL}\"|" fly.toml && rm -f fly.toml.bak
persist_env_var AGENTOS_URL "$APP_URL" "$ENV_FILE"
echo -e "${DIM}Set AGENTOS_URL=${APP_URL} (fly.toml${ENV_FILE:+ + ${ENV_FILE}})${NC}"

echo ""
echo -e "${BOLD}Creating Postgres (${PG_APP_NAME})...${NC}"
# pgvector: the stock postgres-flex image does NOT ship pgvector. Sessions and
# memory work without it; knowledge bases (RAG) need it. Point FLY_PG_IMAGE at
# a postgres-flex derivative with pgvector installed for full functionality
# (Dockerfile: FROM flyio/postgres-flex:17 + apt-get install -y
# postgresql-17-pgvector) — see "Deploying to Fly.io" in AGENTS.md.
PG_IMAGE_ARGS=()
if [[ -n "$FLY_PG_IMAGE" ]]; then
    PG_IMAGE_ARGS=(--image-ref "$FLY_PG_IMAGE")
    echo -e "${DIM}Unmanaged Fly Postgres from FLY_PG_IMAGE=${FLY_PG_IMAGE}${NC}"
else
    echo -e "${DIM}Unmanaged Fly Postgres (stock postgres-flex image).${NC}"
    echo -e "${BOLD}Note:${NC} stock postgres-flex has no pgvector — sessions/memory work, knowledge"
    echo -e "bases won't until you recreate with FLY_PG_IMAGE set to a pgvector-enabled image."
fi
echo ""
if "$FLY" status --app "$PG_APP_NAME" &> /dev/null; then
    # Re-run: the cluster already exists. Keep its password — regenerating
    # here would push a DB_PASS secret that no longer matches the database.
    echo -e "${DIM}Postgres app ${PG_APP_NAME} already exists — reusing (DB_PASS secret unchanged)${NC}"
    DB_PASSWORD=""
else
    DB_PASSWORD="$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 24)"
    # Persist immediately — between here and `fly secrets set` the password
    # exists only in shell memory, and a crash in that window makes it
    # unrecoverable (a re-run reuses the cluster with DB_PASSWORD empty).
    ENV_FILE="${ENV_FILE:-.env.production}"
    [[ -f "$ENV_FILE" ]] || touch "$ENV_FILE"
    persist_env_var DB_PASS "$DB_PASSWORD" "$ENV_FILE"
    "$FLY" postgres create \
        --name "$PG_APP_NAME" \
        --org "$FLY_ORG" \
        --region "$REGION" \
        --initial-cluster-size 1 \
        --vm-size shared-cpu-1x \
        --volume-size 10 \
        --password "$DB_PASSWORD" \
        "${PG_IMAGE_ARGS[@]}"
fi

# The app reads discrete DB_* vars (db/url.py builds the URL from them — it
# never parses DATABASE_URL, so `fly pg attach` is deliberately not used).
# <pg-app>.flycast is the private, always-on address for the Postgres app.
DB_HOST="${PG_APP_NAME}.flycast"

echo ""
echo -e "${BOLD}Setting secrets...${NC}"
SECRET_ARGS=(
    "OPENAI_API_KEY=${OPENAI_API_KEY}"
    "DB_HOST=${DB_HOST}"
    "DB_PORT=5432"
    "DB_USER=postgres"
    "DB_DATABASE=postgres"
    "DB_DRIVER=postgresql+psycopg"
)
# Only set DB_PASS when this run created the cluster; on reuse the existing
# secret already matches the database.
[[ -n "$DB_PASSWORD" ]] && SECRET_ARGS+=("DB_PASS=${DB_PASSWORD}")
[[ -n "$PARALLEL_API_KEY" ]] && SECRET_ARGS+=("PARALLEL_API_KEY=${PARALLEL_API_KEY}")
[[ -n "$RUNTIME_ENV" ]] && SECRET_ARGS+=("RUNTIME_ENV=${RUNTIME_ENV}")
[[ -n "$JWT_JWKS_FILE" ]] && SECRET_ARGS+=("JWT_JWKS_FILE=${JWT_JWKS_FILE}")
[[ -n "$SLACK_BOT_TOKEN" ]] && SECRET_ARGS+=("SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}")
[[ -n "$SLACK_SIGNING_SECRET" ]] && SECRET_ARGS+=("SLACK_SIGNING_SECRET=${SLACK_SIGNING_SECRET}")
# --stage: queue the values without a restart; the deploy below picks them up.
"$FLY" secrets set --app "$APP_NAME" --stage "${SECRET_ARGS[@]}" > /dev/null
echo -e "${DIM}Staged ${#SECRET_ARGS[@]} secrets${NC}"

AUTH_REQUIRES_JWT=1
[[ "${RUNTIME_ENV:-prd}" == "dev" ]] && AUTH_REQUIRES_JWT=""

# JWT auth is on in prd and the app refuses to serve without either a PEM
# verification key or a JWKS file. The URL already exists, so the user can
# mint the key, save it, and have this first deploy come up serving.
if [[ -n "$AUTH_REQUIRES_JWT" && -z "$JWT_VERIFICATION_KEY" && -z "$JWT_JWKS_FILE" && -t 0 ]]; then
    echo ""
    echo -e "${BOLD}JWT_VERIFICATION_KEY not set${NC} — AgentOS won't serve production traffic without auth."
    echo -e "  1. Open ${BOLD}https://os.agno.com${NC} -> Connect OS -> Live -> enter ${APP_URL}"
    echo -e "  2. Name it ${BOLD}Live AgentOS${NC}"
    echo -e "  3. Note: Live AgentOS Connections are a paid feature; use ${BOLD}PLATFORM30${NC} to get 1 month off"
    echo -e "  4. Go to Settings -> OS & Security -> turn ${BOLD}Token-Based Authorization (JWT)${NC} on"
    echo -e "  5. Copy the public key"
    echo -e "  6. Paste the full PEM block at the prompt below, or save it in ${ENV_FILE:-.env.production}"
    echo -e "     Or set JWT_JWKS_FILE if you mount a JWKS file in the image."
    echo ""
    echo -e "  Paste JWT_VERIFICATION_KEY now, or press Enter after saving it:"
    JWT_INPUT=""
    IFS= read -r JWT_INPUT || true
    if [[ -n "$JWT_INPUT" ]]; then
        if capture_pasted_jwt_verification_key "$JWT_INPUT"; then
            ENV_FILE="${ENV_FILE:-.env.production}"
            persist_multiline_env_var JWT_VERIFICATION_KEY "$JWT_VERIFICATION_KEY" "$ENV_FILE"
            echo -e "${DIM}  Saved JWT_VERIFICATION_KEY to ${ENV_FILE}${NC}"
        else
            echo -e "${BOLD}Warning:${NC} couldn't parse the pasted JWT_VERIFICATION_KEY."
            echo -e "${DIM}  Save it to ${ENV_FILE:-.env.production} and run ./scripts/fly/env-sync.sh if auth is still missing.${NC}"
        fi
    else
        [[ -f .env.production ]] && ENV_FILE=".env.production"
        [[ -z "$ENV_FILE" && -f .env ]] && ENV_FILE=".env"
    fi
    [[ -n "$ENV_FILE" ]] && load_env_file "$ENV_FILE"
fi

if [[ -n "$JWT_VERIFICATION_KEY" ]]; then
    echo ""
    echo -e "${DIM}Setting JWT_VERIFICATION_KEY${NC}"
    "$FLY" secrets set --app "$APP_NAME" --stage "JWT_VERIFICATION_KEY=${JWT_VERIFICATION_KEY}" > /dev/null
elif [[ -n "$AUTH_REQUIRES_JWT" && -z "$JWT_JWKS_FILE" ]]; then
    echo ""
    echo -e "${DIM}Deploying without JWT auth config — the app will refuse traffic until${NC}"
    echo -e "${DIM}you add JWT_VERIFICATION_KEY or JWT_JWKS_FILE to ${ENV_FILE:-.env.production} and run ./scripts/fly/env-sync.sh.${NC}"
fi

echo ""
echo -e "${BOLD}Deploying application...${NC}"
echo -e "${DIM}--ha=false is load-bearing: the Fly default creates two machines, which${NC}"
echo -e "${DIM}doubles cost and runs two in-process schedulers double-firing every cron.${NC}"
echo ""
"$FLY" deploy --ha=false

echo ""
echo -e "${BOLD}Done.${NC}"
echo -e "${DIM}URL:            ${APP_URL}${NC}"
echo -e "${DIM}Logs:           ${FLY} logs --app ${APP_NAME}${NC}"
echo -e "${DIM}Sync env vars:  ./scripts/fly/env-sync.sh  (defaults to .env.production)${NC}"
echo -e "${DIM}Teardown:       ./scripts/fly/down.sh${NC}"
echo -e "${DIM}Cost:           ~\$21/mo app (shared-cpu-2x/4GB) + ~\$4/mo Postgres — single${NC}"
echo -e "${DIM}                machine by design; see the README cost note before enabling HA.${NC}"
echo ""
