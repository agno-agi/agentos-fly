# AgentOS: FastAPI for Agents

AgentOS turns your agents into a production API. One AI backend that serves every frontend.

1. **Your product.** Call the REST API from your app: run agents, stream responses, and manage sessions, memory, and knowledge.
2. **AgentOS UI.** Chat with agents, build new ones, and inspect sessions, traces, memory, and evals from the AgentOS UI at [os.agno.com](https://os.agno.com?utm_source=github&utm_medium=example-repo&utm_campaign=agentos-fly&utm_content=agentos-fly&utm_term=fly).
3. **Coding agents.** Manage the full agent development lifecycle (create, extend, improve, eval and review) using the skills in [`.agents/skills/`](.agents/skills/).
4. **AI apps.** MCP clients like Claude and ChatGPT can use your agents through the MCP server at `/mcp`.
5. **Chat interfaces.** Chat with your agents from Slack, WhatsApp, Telegram, and Discord.

<img width="3298" height="2412" alt="AgentOS" src="https://github.com/user-attachments/assets/40a53a42-d4d2-402b-8e92-742609207957" />

<p align="center"><em>Built on <a href="https://docs.agno.com">Agno</a>. Everything runs in your cloud, your data lives in your database.</em></p>

## Get Started

Copy this prompt into your favorite coding agent. It sets up the platform and builds your first agent with you:

```text
Help me set up my agent platform and build my first agent.

Clone https://github.com/agno-agi/agentos-fly into a folder called agent-platform, cd in, and run the setup-platform skill (in .agents/skills/).
```

Your coding agent drives the whole flow: it checks Docker, sets up `.env`, boots the platform, verifies the MCP endpoint, and builds your first agent with you. Prefer to drive yourself? See [Manual Setup](#manual-setup).

## Built for agents

This codebase comes with:

- **Two platform agents** that help you build and run the platform from your favorite AI apps like Claude and ChatGPT. **Agent Builder** creates agents, teams, and workflows using the AgentOS Studio. **Platform Manager** monitors and manages the platform: codebase questions, eval history, deployment checks, schedules.
- **Coding-agent skills** let Claude Code, Codex, Cursor, and other coding agents build, test, and improve the platform automatically — see [Using the platform](#using-the-platform).

Trace data, agent code, evals, and system logs are all available to coding agents, so the platform can inspect and improve itself end to end.

## Manual Setup

### Step 1: Run locally

> **Prerequisite:** [Docker](https://www.docker.com/get-started/) installed and running.

```sh
git clone https://github.com/agno-agi/agentos-fly agentos
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

## Run in production

You can run the platform anywhere that supports containerized images. This codebase comes with scripts to deploy the platform to [Fly.io](https://fly.io).

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

> **Heads up.** Live AgentOS Connections are a paid feature. Use `PLATFORM30` to get 1 month off. We are working on a free trial so you don't have to pay to try.

If you run non-interactively or skip the prompt, you can sync environment variables later with `./scripts/fly/env-sync.sh`.

### 4. Register your production AgentOS to MCP clients

Re-run `uvx agno connect`, this time pointed at your deployed domain, to connect Claude Code, Claude Desktop, Codex, and Cursor to your production platform:

```sh
uvx agno connect --url https://<your-app>.fly.dev
```

For **claude.ai and ChatGPT (web)**: add `https://<your-app>.fly.dev/mcp` as a custom connector in the chat app's connector settings. Leave the form's optional OAuth fields (client ID / client secret) empty. Click **Connect** and, on the consent page, enter the `MCP_CONNECT_SECRET` that `up.sh` generated during deploy (saved in `.env.production`).

### 5. Verify

You can check the logs on the Fly dashboard, or by running the following command (the app name comes from `fly.toml`):

```sh
fly logs
```

### 6. Redeploy after code changes

For updates from your machine, run the following command:

```sh
./scripts/fly/redeploy.sh
```

### 7. Sync environment variables

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

This platform is designed so that coding agents can drive the entire **create → improve → evaluate → maintain** lifecycle for you.

### Create

Open your coding agent of choice (Claude Code, Codex, Cursor) and run:

```
/create-new-agent
```

It asks a few questions, generates the agent file in `agents/`, registers it in `app/main.py`, adds its description and quick prompts to `app/config.yaml`, restarts the container, and smoke-tests it live.

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

## Connect more frontends (optional)

AgentOS comes with an MCP server at `/mcp` (enabled by setting `mcp_server=True` in [`app/main.py`](app/main.py)), so any MCP client can call your agents, teams, and workflows through tools like `run_agent`, `run_team`, and `run_workflow`.

Register your AgentOS with the MCP clients on your machine:

```sh
uvx agno connect
```

It auto-detects Claude Code, Claude Desktop, Codex, and Cursor and registers `http://localhost:8000/mcp`. After a successful connection, open one of these apps and ask:

```text
can you access my agentos mcp?
```

**claude.ai and ChatGPT (web).** Hosted AI apps reach your platform over the internet and need an OAuth login. Deploy to production (above), add `https://<domain>/mcp` as a remote connector, and approve the consent page with your connect secret.

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | yes | none | OpenAI key for models and embeddings. |
| `RUNTIME_ENV` | no | `prd` | `dev` disables JWT. Compose sets this to `dev` for local — never put `dev` in an env file that env-sync.sh pushes to Fly, or production serves unauthenticated. |
| `JWT_VERIFICATION_KEY` | prd | none | Public key from os.agno.com. Required when `RUNTIME_ENV=prd`, unless `JWT_JWKS_FILE` is set. |
| `JWT_JWKS_FILE` | prd | none | Path to a JWKS file; alternative to `JWT_VERIFICATION_KEY` for production JWT verification. |
| `AGENTOS_URL` | no | `http://127.0.0.1:8000` | Scheduler base URL. `scripts/fly/up.sh` sets it to `https://<app>.fly.dev` before the first deploy; set by hand only for a custom domain — re-running `up.sh` resets it to the generated fly.dev URL, so re-pin the domain (or re-run env-sync.sh) afterwards. Also the public origin OAuth metadata derives from when `MCP_CONNECT_SECRET` is set. |
| `MCP_CONNECT_SECRET` | no | none | If set (≥16 chars, e.g. `openssl rand -base64 32`), `/mcp` becomes its own OAuth 2.1 authorization server so claude.ai and ChatGPT (web) can connect; connecting asks for this secret on a consent page. Requires `AGENTOS_URL`. `scripts/fly/up.sh` auto-generates it on deploy. PAT and JWT bearers keep working alongside. |
| `AGENTOS_MCP_SIGNING_KEY` | no | none | Optional high-entropy signing-key material (≥32 chars) for OAuth tokens. Unset, a strong key is generated and persisted in the database. Rotating it invalidates outstanding tokens. |
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
