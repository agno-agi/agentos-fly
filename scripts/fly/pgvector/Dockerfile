# pgvector-enabled Fly Postgres
# =============================
#
# Fly's stock postgres-flex image does not ship pgvector, and AgentOS does not
# start without it: app/registry.py builds shared_knowledge at import, and
# Knowledge runs CREATE EXTENSION vector while it initializes. Without the
# extension the API exits before uvicorn binds and the machine crash-loops.
#
# Built and pushed by scripts/fly/pgvector/build.sh, which up.sh calls for you.
#
# FLY_PG_VERSION selects the postgres-flex major (default 18). The pgvector
# package is versioned per major, so the two must match.

ARG FLY_PG_VERSION=18
FROM flyio/postgres-flex:${FLY_PG_VERSION}

ARG FLY_PG_VERSION=18
RUN apt-get update \
    && apt-get install -y --no-install-recommends "postgresql-${FLY_PG_VERSION}-pgvector" \
    && rm -rf /var/lib/apt/lists/*
