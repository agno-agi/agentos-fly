---
name: deploy-platform
description: Deploy this AgentOS to Fly.io with scripts/fly, configure JWT verification, and verify the public service. Use for first deployment, redeployment, or production configuration changes on Fly.
---

# Deploy the Platform to Fly.io

Read `AGENTS.md`, the [README deployment section](../../../README.md#deploy-in-production),
`fly.toml` and `scripts/fly/`. The deploy layer is four scripts: `up.sh` provisions
and deploys, `redeploy.sh` ships code, `env-sync.sh` uploads settings and `down.sh`
tears everything down. Never print credentials, `DB_PASS` or `MCP_CONNECT_SECRET`.
The JWT verification key is public and may be shared.

## 1. Prepare

- `fly version` and `fly auth whoami` must succeed. Logging in is interactive:
  ask the user to run `fly auth login` in their own terminal.
- `docker info` must succeed. `up.sh` builds the pgvector Postgres image locally
  unless `FLY_PG_IMAGE` is set or the database already exists.
- Confirm the Fly organization (`FLY_ORG`, default `personal`) and region
  (`FLY_REGION`, default `iad`). The app and Postgres share both.
- Create `.env.production` from `example.env` only if it is absent. Have the user
  add `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` for
  Claude Engineer, in their editor. Check keys are set without reading values back.
  Leave `RUNTIME_ENV` unset; never deploy `dev`.
- `FLY_*` lines in the env file are deploy settings for `up.sh`; `env-sync.sh`
  does not upload them.
- Sandboxes: Fly machines have no Docker daemon, so the Docker sandbox cannot run
  there. For hosted isolation, enable `SANDBOX_ENABLED` and set the repository in
  `app/sandbox.py`; `fly.toml` selects AgentCore. Configure its ARN and S3 settings per
  the [sandbox guide](../../../docs/harnesses.md#aws-agentcore-sandbox) and add
  AWS credentials to the env file. `AWS_PROFILE` is host-only and is not uploaded.
  Never put secret values in source.

## 2. Find an existing deployment

`app` in `fly.toml` records the deployment. `agentos` is the unprovisioned
placeholder; `agentos-<suffix>` was written by `up.sh`. The placeholder alone does
not prove nothing exists: `down.sh` resets it, but so does switching branches or
discarding local changes. Run `fly apps list` and look for `agentos-*` and
`agentos-*-db` apps first. If one exists, restore its name, `primary_region` and
`AGENTOS_URL` in `fly.toml` instead of provisioning a second deployment.

- **Existing deployment:** use `redeploy.sh` for code and `env-sync.sh` for
  settings (step 5). Do not run `up.sh` to recover from a failed deploy unless it
  is resuming the same app name; it reuses the app, the database and its password.
- **New deployment:** before running anything, tell the user what `up.sh`
  creates and what it costs: the app `agentos-<suffix>` (shared-cpu-2x, 4 GB,
  about $21/mo), the Postgres app `agentos-<suffix>-db` (10 GB volume, about $4/mo)
  and the pgvector image in the app's registry. `down.sh` deletes all three,
  including the database data.

## 3. Run up.sh

`up.sh` generates the app name and writes `app`, `primary_region` and `AGENTOS_URL`
into `fly.toml`. It creates the app, builds and pushes
`registry.fly.io/<app>:pgvector-18`, creates Postgres from that image, stages
secrets, then deploys one machine with `--ha=false`. In the template repository,
leave the rewritten `fly.toml` uncommitted; in the user's own repository, commit
it so later commands target the app.

The script pauses for the JWT key only when it has a terminal. From a coding agent
there is no terminal: it skips the prompt and deploys without a key, and the
machine exits at startup until the key arrives. Choose one:

- **Preferred:** ask the user to run `./scripts/fly/up.sh` in their own terminal
  and complete the prompt (step 4).
- **Agent-run:** tell the user first that the machine will restart repeatedly until
  the key is added, run `up.sh`, confirm in `fly logs --no-tail` that the only
  startup error is the missing JWT configuration, then complete step 4 and run
  `./scripts/fly/env-sync.sh`.

If the pgvector build fails, `up.sh` stops before creating Postgres. Fix Docker or
set `FLY_PG_IMAGE`, then re-run; it reuses the saved app name. `FLY_PG_VERSION`
affects new clusters only. Major versions do not upgrade in place: an existing
cluster keeps its version until it is recreated or migrated deliberately.

## 4. Configure JWT verification

The URL is `https://<app>.fly.dev`. Have the user open
[os.agno.com](https://os.agno.com/?ref=fly-template), choose **Connect OS** →
**Live**, enter the URL, turn on token-based authorization (JWT) and copy the
public key. Live connections are a paid feature. The key goes into the script's
prompt, or into `.env.production` as a quoted multi-line `JWT_VERIFICATION_KEY`
followed by `./scripts/fly/env-sync.sh`.

## 5. Update settings and code

| Change | Command |
| --- | --- |
| Code | `./scripts/fly/redeploy.sh` (always `--ha=false`; never run plain `fly deploy`) |
| Settings | `./scripts/fly/env-sync.sh` (one restart for all keys) |
| Remove a setting | `fly secrets unset NAME` (deleting the env-file line does not remove it) |

`fly secrets list` marks values that are set but not yet deployed as staged. Never
raise the machine count with `fly scale count` or enable HA: each machine runs the
scheduler, so every cron would fire twice. Follow [docs/scaling.md](../../../docs/scaling.md)
before adding replicas. Rotating the database password is separate from `env-sync.sh`.

## 6. Verify and hand over

A finished deploy command is not a working service. Check:

- `fly status`: one machine, `started`, in the chosen region.
- `fly logs --no-tail`: `Application startup complete`, the JWT middleware, and no
  `vector`, JWT or database errors.
- `fly secrets list`: nothing left staged.
- Over HTTPS: `/health` returns 200; unauthenticated `/agents` and MCP initialize
  POSTs are rejected, and the POST's `WWW-Authenticate` header carries the Bearer
  challenge. A plain `GET /mcp` may return public metadata and proves nothing.
- An authenticated request with an existing token, and the Live OS in the UI.

A new `*.fly.dev` name can take minutes to resolve, and resolvers on public or
captive Wi-Fi can intercept DNS and keep a stale miss. Before suspecting the app,
test it directly: `curl --resolve <app>.fly.dev:443:<ipv4 from fly ips list> https://<app>.fly.dev/health`,
or resolve with `curl --doh-url https://cloudflare-dns.com/dns-query`. Do not
release or reallocate IPs to fix slow DNS. Check the Fly status page for
platform incidents when results don't add up.

Model prompts spend calls; report exactly what ran. Coding agent HTTP runs, delegation
and Company Task completion need separate verification before claiming they work.

Hand over the URL, the results above and the commands in step 5, plus
`fly logs` and `./scripts/fly/down.sh`. For browser MCP, use `<AGENTOS_URL>/mcp`
and tell the user to enter `MCP_CONNECT_SECRET` from `.env.production` on the
consent page; do not print it. For coding clients, use
`uvx agno connect --url <AGENTOS_URL>`.
