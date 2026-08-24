# pgvector-enabled Fly Postgres
# =============================
#
# Fly's stock postgres-flex image does not ship pgvector, and AgentOS does not
# start without it: app/knowledge.py builds shared_knowledge at module scope, so
# Knowledge.__post_init__ runs CREATE EXTENSION vector during the import in
# app/main.py. Without the extension the process exits 1 before uvicorn binds —
# the machine crash-loops and nothing serves, sessions and memory included.
#
# Built and pushed by scripts/fly/pgvector/build.sh, which up.sh calls for you.
#
# FLY_PG_VERSION must match the postgres-flex major Fly provisions (18 today);
# the pgvector package is versioned per major, so a mismatch fails the build.

ARG FLY_PG_VERSION=18
FROM flyio/postgres-flex:${FLY_PG_VERSION}

ARG FLY_PG_VERSION=18
RUN apt-get update \
    && apt-get install -y --no-install-recommends "postgresql-${FLY_PG_VERSION}-pgvector" \
    && rm -rf /var/lib/apt/lists/*
