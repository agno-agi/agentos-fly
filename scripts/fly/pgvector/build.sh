#!/usr/bin/env bash
# Build and push a pgvector-enabled postgres-flex image to Fly's registry.
#
# Usage: scripts/fly/pgvector/build.sh <app-name> [pg-major]
#
# Prints the pushed image reference on stdout (and nothing else, so callers can
# capture it); progress goes to stderr.
#
# The image is pushed under the APP's repository, never the database app's:
# down.sh destroys the database app, and destroying a Fly app deletes the images
# in its registry namespace. An image parked there vanishes exactly when the next
# up.sh needs it, with a MANIFEST_UNKNOWN 404 at machine-provision time.
set -euo pipefail

APP_NAME="${1:?usage: build.sh <app-name> [pg-major]}"
PG_MAJOR="${2:-18}"
IMAGE_REF="registry.fly.io/${APP_NAME}:pgvector-${PG_MAJOR}"

if command -v flyctl &> /dev/null; then FLY=flyctl; else FLY=fly; fi

if ! docker info &> /dev/null; then
    echo "Docker is not running — needed to build the pgvector image." >&2
    exit 1
fi

echo "Building ${IMAGE_REF} (postgres-flex ${PG_MAJOR} + pgvector)" >&2

# --platform linux/amd64: Fly machines are x86_64, and an arm64 image built on
# Apple silicon provisions cleanly then fails to boot.
docker build \
    --platform linux/amd64 \
    --build-arg "FLY_PG_VERSION=${PG_MAJOR}" \
    -t "$IMAGE_REF" \
    "$(dirname "$0")" >&2

"$FLY" auth docker >&2
docker push "$IMAGE_REF" >&2

echo "$IMAGE_REF"
