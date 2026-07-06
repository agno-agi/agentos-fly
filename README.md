# AgentOS: the agent backend for every frontend

AgentOS is a high-performance runtime that gives you one agent server for every client. Build your agents, teams, and workflows once; use the same system across every surface:

1. **Your product.** Add agents to your own application: AgentOS serves a full REST API with 80+ endpoints — runs, sessions, memory, knowledge, and evals.
2. **Chat interfaces.** Chat with your agents through Slack, WhatsApp, Telegram, Discord. Slack is set up; for the rest, see [interfaces](https://docs.agno.com/agent-os/interfaces/overview).
3. **AI apps.** Let Claude, ChatGPT, Cursor, and Claude Code use your AgentOS through the MCP server at `/mcp`.
4. **Coding agents.** Claude Code, Codex, and Cursor drive the full agent development lifecycle with the skills in [`.agents/skills/`](.agents/skills/).
5. **AgentOS UI.** The control plane for your agent-platform at [os.agno.com](https://os.agno.com?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly). Chat with agents, inspect sessions, traces, memory, and evals.

<img width="3298" height="2412" alt="AgentOS" src="https://github.com/user-attachments/assets/40a53a42-d4d2-402b-8e92-742609207957" />

Built on [Agno](https://docs.agno.com). Everything runs in your cloud, your data lives in your database.

## Built for agents

This codebase comes with:

- **Two flagship agents** that help you run the platform from your favorite AI Apps like Claude and ChatGPT. **Agent Builder** creates agents, teams, and workflows using the AgentOS Studio. **Platform Manager** understands, monitors, and explains the platform: codebase questions, eval history, deployment checks, schedules.
- **Coding-agent skills** let Claude Code, Codex, Cursor, and other coding agents build, test, and improve the platform automatically — see [Using the platform](#using-the-platform).

Trace data, agent code, evals, and system logs are all available to coding agents, so the platform can inspect and improve itself end to end.

## Get Started

The fastest way to get started is using a coding agent. Copy the prompt below into Claude Code, Cursor or Codex and it'll take you from zero to a running platform.

```text
Help me set up an AgentOS on this machine. Work step by step and verify each step before moving to the next. When a step needs me (an API key, a Docker install, a sign-in), stop, tell me exactly what to do, and wait for my input. Never read or print secrets.

1. Clone https://github.com/agno-agi/agentos-fly.git and cd in. Then read AGENTS.md end to end — it is the source of truth for how this platform works and answers most questions you'll hit along the way.
2. Run `cp example.env .env`, open .env in my favorite editor, and ask me to set the OPENAI_API_KEY.
3. Confirm docker is installed, running and `docker info` succeeds. If Docker is missing, ask me to install Docker Desktop and wait until it's running.
4. Start the platform with `docker compose up -d --build`, then poll http://localhost:8000/docs until it returns 200 (first build takes a few minutes). If it never comes up, read `docker compose logs agentos-api` and fix what you find.
5. Prove it end to end with ./scripts/mcp_check.sh — it should print "MCP OK" and a real agent answer. Show me that answer: it's my platform talking.
6. Ask me which frontends I want connected, then set up the ones I pick:
   - Coding agents (including you): run `uvx agno connect` — it registers http://localhost:8000/mcp in Claude Code, Claude Desktop, Codex, and Cursor, and verifies with a real handshake. Use the default user scope, not --project (that would write a token into the repo).
   - The AgentOS web UI: walk me through os.agno.com → Connect OS → http://localhost:8000, named "Local AgentOS".
   - Claude and ChatGPT apps (web or desktop): their sessions run in the cloud and can't reach localhost, so work with me on deploying to production first using ./scripts/fly/up.sh (needs flyctl installed and `fly auth login` done; the script pauses while I mint a JWT key at os.agno.com). Then I add https://<app>.fly.dev/mcp as a custom connector in the chat app's connector settings.
7. Finish with a short summary of what's running and where, plus a few first prompts to try — start with asking Agent Builder to "Build an agent that tracks AI news and writes a daily brief".
```

## Manual Setup

### Step 1: Run locally

> **Prerequisite:** [Docker](https://www.docker.com/get-started/) installed and running.

```sh
git clone https://github.com/agno-agi/agentos-fly.git agentos
cd agentos

# Configure credentials
cp example.env .env
# Open .env and set OPENAI_API_KEY

# Run the platform on docker
docker compose up -d --build
```

Confirm your AgentOS is running at [http://localhost:8000/docs](http://localhost:8000/docs).

### Step 2: Connect the AgentOS UI

1. Open [os.agno.com](https://os.agno.com?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly) and sign in.
2. Click **Connect OS**, enter `http://localhost:8000` as the URL, name it **Local AgentOS**, and connect.

### Step 3: Build your first agent

1. Click **Chat** under the **Agent Builder** agent and try the first prompt: "Build an agent that tracks AI news and writes a daily brief". Go through the agent development process.
2. Once created, click the **Refresh** button on the top right. You should now see the "Daily AI News Brief" agent in the **Agents** dropdown. Click the newly created agent.
3. Ask: "What's new with Anthropic?"

### Step 4: Check platform health

Click **Chat** under **Platform Manager** and ask: "How healthy is the platform?" It answers from the codebase and runtime data — eval history, deployment checks, schedules, and the component you just built.

## Use your platform from Claude Code and chat apps

AgentOS comes with an MCP server at `/mcp` (enabled by setting `enable_mcp_server=True` in [`app/main.py`](app/main.py)), so any MCP client can call your agents, teams, and workflows through tools like `run_agent`, `run_team`, and `run_workflow`.

**Coding agents.** Register the AgentOS with coding agents on your machine:

```sh
uvx agno connect
```

It auto-detects Claude Code, Claude Desktop, Codex, and Cursor, registers `http://localhost:8000/mcp`, and verifies the connection. Coding agents run on your machine, which is why `localhost` works for them. Hosted chat apps (like Claude and ChatGPT) need a deployed URL. The manual command for Claude Code is `claude mcp add --transport http agentos http://localhost:8000/mcp`; other MCP-capable tools use the same URL.

**Chat apps.** The Claude and ChatGPT apps can't reach `localhost` because their sessions run in hosted environments, not on your machine. For them, we need to deploy first, then add our platform as a connector. In claude.ai: **Settings → Connectors → Add custom connector** → `https://<your-app>.fly.dev/mcp`. Same URL in ChatGPT's connector settings. Follow the [Run in production](#run-in-production) section to get set up.

## Run in production

You can run the platform anywhere that supports containerized images. For the lightest lift, the codebase comes with scripts to deploy the platform to [Fly.io](https://fly.io).

> **Prerequisite:** [flyctl](https://fly.io/docs/flyctl/install/) installed and `fly auth login` completed.

### 1. Set up your production env

Create a new `.env.production` file for production credentials.

```sh
cp .env .env.production          # or cp example.env .env.production
# Edit .env.production with production values
```

Keeping a separate `.env.production` lets us use different values for local and production: different OpenAI keys, production-only credentials, a different Slack workspace.

### 2. Deploy

```sh
./scripts/fly/up.sh
```

This provisions the app and an unmanaged Fly Postgres on the same private network, pushes your credentials as Fly secrets, and deploys a single always-on machine. Deploys use `fly deploy --ha=false` on purpose: the Fly default creates two machines, which doubles cost and runs two in-process schedulers double-firing every cron. The script pauses and asks for a JWT verification key for authentication (see next section).

> **Cost note.** Default sizing is `shared-cpu-2x` with 4 GB (~$21/mo) plus a small Postgres machine (~$4/mo). `performance-2x` (~$62/mo) is the dedicated-CPU option — edit [`fly.toml`](fly.toml).

> **pgvector.** Fly's stock `postgres-flex` image does **not** ship pgvector: sessions and memory work out of the box, but knowledge bases (RAG) need the extension. Set `FLY_PG_IMAGE` to a postgres-flex derivative with pgvector installed before running `up.sh` — the image is a two-line Dockerfile (`FROM flyio/postgres-flex:17` + `apt-get install -y postgresql-17-pgvector`). Without it, `up.sh` prints a warning and everything except knowledge bases works.

### 3. Production Auth

Token-Based Authorization is on by default. Without a `JWT_VERIFICATION_KEY` or `JWT_JWKS_FILE`, the app refuses to serve traffic in production. The platform's job is to keep your data private, so the safe default is "refuse to start" without an authentication token.

Token-Based Auth gives you three things:

1. **No public access.** The server rejects requests without a valid token.
2. **Per-request identity.** Middleware parses the token and extracts the `user_id`, `session_id`, and custom claims. Each request is tied to a user and session, giving you auditability and traceability.
3. **Granular permissions.** User tokens can run an agent and view their own sessions. Admin tokens read everyone's sessions and test any agent.

During `./scripts/fly/up.sh`, the app URL (`https://<app>.fly.dev`) is known before the first deploy, and the script pauses so you can mint the key before the app starts.

1. Open [os.agno.com](https://os.agno.com?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly), click **Connect OS** → **Live**, enter your Fly URL, and connect.
2. Name it **Live AgentOS**.
3. Go to **Settings** → **OS & Security**.
4. Turn **Token-Based Authorization (JWT)** on.
5. Copy the public key.
6. Paste the full public key into the `up.sh` prompt. The script saves it into your env file for future syncs:

```sh
JWT_VERIFICATION_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkq...
-----END PUBLIC KEY-----"
```

The value is quoted so every parser — docker compose `env_file` included — reads the multi-line PEM as one variable.

> **Heads up.** Live AgentOS Connections are a paid feature. Use `PLATFORM30` to get 1 month off. We are working on a free trial so you don't have to pay to try.

If you run non-interactively or skip the prompt, you can sync environment variables later with `./scripts/fly/env-sync.sh`.

### 4. Verify

You can check the logs on the Fly dashboard, or by running the following command (the app name comes from `fly.toml`):

```sh
fly logs
```

### 5. Redeploy after code changes

For updates from your machine, run the following command:

```sh
./scripts/fly/redeploy.sh
```

### 6. Sync environment variables

To re-sync environment variables, run the following command:

```sh
./scripts/fly/env-sync.sh
```

It reads `.env.production` by default (pass another file as an argument, e.g. `.env`) and pushes every variable as Fly secrets in one call — a single restart, no matter how many variables changed.

### Tear down

```sh
./scripts/fly/down.sh
```

Destroys the app **and** its Postgres — including all data in the database.

### Opting out of JWT (not recommended)

Set `authorization=False` in [`app/main.py`](app/main.py) and redeploy. Use this only inside a private network behind another auth layer. Without it, anyone who guesses your Fly URL can access your platform.

## Using the platform

This platform is designed so that coding agents can drive the entire **create → improve → evaluate → maintain** lifecycle.

### Create

Open your coding agent of choice (Claude Code, Codex, Cursor) and run:

```
/create-new-agent
```

It asks a few questions, generates the agent file in `agents/`, registers it in `app/main.py`, adds quick prompts to `app/config.yaml`, restarts the container, and smoke-tests it live.

### Improve

Improve your agents by running the following skills:

- **`/extend-agent`** — Add a tool, add a capability, refine the instructions, fix a known bug.
- **`/improve-agent`** — Claude simulates scenarios from the agent's `INSTRUCTIONS`, runs them against the live container, judges the responses, and edits until they pass.

### Evaluate

Run the eval suite to check for regressions. The evals live in [`evals/cases.py`](evals/cases.py), and run history shows up at os.agno.com next to your sessions and traces.

The evals run on the host machine, so set up the venv with `./scripts/venv_setup.sh && source .venv/bin/activate`, then:

```sh
python -m evals --tag smoke      # fast checks of the self-driving surfaces
python -m evals --tag release    # broader pre-release confidence
python -m evals --name <case>    # one case while iterating
python -m evals -v               # stream the full run with rich panels
```

If a case fails, run **`/eval-and-improve`** — it diagnoses each failure, fixes what's in scope, and loops until green.

### Maintain

Because the repo is managed by coding agents, it moves fast. Run `/review-and-improve` before a release or after a refactor: it sweeps for drift between docs, code, and config, auto-fixes mechanical drift like stale paths and missing env vars, and flags anything bigger.

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | yes | none | OpenAI key for models and embeddings. |
| `RUNTIME_ENV` | no | `prd` | `dev` disables JWT. Compose sets this to `dev` for local — never put `dev` in an env file that env-sync.sh pushes to Fly, or production serves unauthenticated. |
| `JWT_VERIFICATION_KEY` | prd | none | Public key from os.agno.com. Required when `RUNTIME_ENV=prd`, unless `JWT_JWKS_FILE` is set. |
| `JWT_JWKS_FILE` | prd | none | Path to a JWKS file; alternative to `JWT_VERIFICATION_KEY` for production JWT verification. |
| `AGENTOS_URL` | no | `http://127.0.0.1:8000` | Scheduler base URL. `scripts/fly/up.sh` sets it to `https://<app>.fly.dev` before the first deploy; set by hand only for a custom domain. |
| `ENABLE_DEPLOY_CHECK` | no | `True` | The reference deployment-check cron runs daily by default. Set `False` to disable; the workflow is runnable on demand regardless. |
| `ENABLE_SCHEDULED_EVALS` | no | `False` | If `True`, schedules the run-evals workflow daily. Off by default because it uses model calls. |
| `EVALS_TAG` | no | `smoke` | Eval tag run by the run-evals workflow. |
| `EVALS_CASE_TIMEOUT_SECONDS` | no | `90` | Default per-case timeout for run-evals runs; applies only to cases that don't set their own `timeout_seconds`. |
| `EVALS_SUITE_TIMEOUT_SECONDS` | no | `900` | Whole-suite timeout for run-evals runs; per-case timeouts are the granular limit. The default bounds the `smoke` tag's worst case (incl. builder-case teardown). |
| `PARALLEL_API_KEY` | no | none | Authenticates the WebSearch Agent's Parallel SDK / MCP connection. |
| `SLACK_BOT_TOKEN` / `SLACK_SIGNING_SECRET` | no | none | Both must be set to enable the Slack interface. |
| `DB_HOST` / `DB_PORT` / `DB_USER` / `DB_PASS` / `DB_DATABASE` | no | matches compose | Postgres connection. |
| `DB_DRIVER` | no | `postgresql+psycopg` | SQLAlchemy driver. |
| `AGNO_DEBUG` | no | `False` | If `True`, Agno emits verbose debug logs. Compose sets this for dev. |
| `WAIT_FOR_DB` | no | `False` | If `True`, the entrypoint blocks on the DB before starting. Compose sets this. |

## Learn more

- [Agno documentation](https://docs.agno.com?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly)
- [AgentOS introduction](https://docs.agno.com/agent-os/introduction?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly)
- [Agno on GitHub](https://github.com/agno-agi/agno). Drop a star if this is useful.
