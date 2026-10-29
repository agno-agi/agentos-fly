# AgentOS: The self-driving agent platform

Build agents for your company, product, or customers. Run them as durable
services on AgentOS. Put them to work automating company operations.

- **Build** agents with the Agno, Claude Agent, or Codex SDKs. Combine agents into
  teams and workflows.
- **Run** agents as durable services with built-in API and MCP. AgentOS handles
  authentication, role-based access, human approvals, scheduling, and durable execution.
- **Automate** company operations with CompanyOS. Give agents responsibilities,
  organize work into projects and tasks, and configure recurring routines. People set
  direction and review results; agents own and execute.

Built with [Agno](https://github.com/agno-agi/agno), this template gives you a working
agent platform that you can run locally or deploy to Fly.io.

Use your agents in:

1. **Your product:** call them through the REST API.
2. **Claude and ChatGPT:** connect through the MCP server.
3. **Slack:** connect a Slack app to talk to OS Manager from your workspace.

Run your platform in your own cloud and keep your data in your own PostgreSQL database.
Use the [AgentOS UI](https://os.agno.com) to review conversations, inspect traces,
manage knowledge, and track your agents' work. Build agents with code, use Studio,
or chat with OS Manager.

## Get started

Give this prompt to your coding agent:

```text
Help me set up my agent platform and build my first agent.

Clone https://github.com/agno-agi/agentos-fly into a folder called agent-platform,
cd into it, and follow .agents/skills/setup-platform/SKILL.md.
```

It checks Docker, helps you add your API key, starts the platform, and walks you
through building your first agent. Already cloned the repo? Ask your coding agent
to run the `/setup-platform` skill.

## Coding agents

The platform includes **Claude Engineer** and **Codex Engineer**, disabled by default.
They can read code, make changes, and run commands. Enable them in `app/main.py`.
Follow the [harness setup guide](docs/harnesses.md) for the steps.

Once enabled, chat with a coding agent in AgentOS or ask OS Manager to use one:

> Ask Codex Engineer to review this project and suggest improvements. Don't change any files yet.

Without a sandbox, coding agents run on the API host with its file and credential
access. For isolation and checkpoint recovery, set up a
[Docker or AgentCore sandbox](docs/harnesses.md#sandboxes-and-checkpoints).

## Run locally

You'll need Git, Docker with Compose, and an OpenAI API key.
Make sure Docker is running, then run the commands below in your terminal.

### 1. Start the platform

```sh
git clone https://github.com/agno-agi/agentos-fly agent-platform
cd agent-platform
cp example.env .env
```

Open `.env` and set `OPENAI_API_KEY`, then start the platform:

```sh
docker compose up -d --build
```

The first build can take a few minutes. When it's ready, open
[http://localhost:8000/docs](http://localhost:8000/docs) to see the API.

Check that AI apps can connect through MCP:

```sh
./scripts/mcp_check.sh
```

The check should report `9 tools; required tools available`.

### 2. Connect the UI

1. Open [os.agno.com](https://os.agno.com) and sign in.
2. Choose **Connect OS**, select a local connection, and enter `http://localhost:8000`.
3. Name it **Local AgentOS**, then open the chat for **OS Manager**.

### 3. Build your first agent

Tell OS Manager what you want to build. For example:

> Help me build a daily briefing agent about the companies and topics I follow. Here's what I care about: …

Review what it proposes, then ask it to build and publish the agent.
Refresh the Agents list and try it out. You can chat with your new agent directly
or ask OS Manager to run it for you.

## Build and improve your agents

You can keep working through OS Manager, use Studio, or edit Python files in this repo.
The repo includes instructions, called skills, for common coding tasks.
Ask your coding agent to follow the relevant skill:

| What you want to do | Skill |
| --- | --- |
| Build an agent | [/create-agent](.agents/skills/create-agent/SKILL.md) |
| Add a tool, change behavior, or fix a bug | [/extend-agent](.agents/skills/extend-agent/SKILL.md) |
| Write tests for your agent's answers | [/create-evals](.agents/skills/create-evals/SKILL.md) |
| Harden an agent with simulations and targeted fixes | [/improve](.agents/skills/improve/SKILL.md) |
| Check the repo before sharing or releasing it | [/review-and-improve](.agents/skills/review-and-improve/SKILL.md) |

If you write an agent in Python, put it in `agents/` and add it to
[app/main.py](app/main.py) so the platform can run it. Set its description and
suggested prompts in [app/config.yaml](app/config.yaml). To make a tool or model
available in Studio, add it to [app/registry.py](app/registry.py).

You can give agents documents to search, a notebook to keep notes, and memory
to remember each user.

## Company

CompanyOS organizes the work you delegate to agents. A Product defines an ongoing
area of responsibility, a Project groups related work toward a goal, and a Task
describes a specific job to complete. Routines give agents instructions to carry
out on a schedule.

This template includes an `AgentOS` Product for improving the platform itself,
with a daily review Routine configured for 09:00 UTC and **disabled by default**.
Open Company in AgentOS, review its instructions and schedule, then enable it when
you want recurring reviews. Company Manager reads the code and Agno release notes,
then proposes up to three Tasks. Automatic acceptance is off; you choose what to
approve and implement.

Scheduled reviews use your model API keys and incur usage costs. Check the saved
schedule and run history in Company. Upgrading an existing platform preserves its
saved Routine state; pause it in the UI if you want to stop scheduled reviews.

[app/company.py](app/company.py) sets the initial review instructions and schedule.
Once they're saved in the database, update the saved Routine to change them;
editing the Python file alone won't change an existing Routine.

## Make it yours

To save your work in your own GitHub repository, create an empty private repo.
From a fresh clone of this template, run the commands below with your repo URL.
This makes `origin` your repo and keeps the original template as `upstream`:

```sh
git remote rename origin upstream
git remote add origin https://github.com/YOUR-ORG/YOUR-REPO.git
git push -u origin HEAD
```

Future pushes go to your repository. You can still fetch updates from `upstream`
and review them before merging.

If you use sandboxes, also set the repository URL and branch in
[the sandbox configuration](docs/harnesses.md#sandboxes-and-checkpoints).

<a id="deploy-in-production"></a>

## Deploy in production

Ask your coding agent to follow [deploy-platform](.agents/skills/deploy-platform/SKILL.md),
or use the steps below.

You'll need Fly CLI with `fly auth login` completed, OpenSSL, and Docker running.

### 1. Set your production settings

```sh
[ -f .env.production ] || cp example.env .env.production
```

Add `OPENAI_API_KEY` and any other model keys you use, such as `ANTHROPIC_API_KEY`
or `CLAUDE_CODE_OAUTH_TOKEN` for Claude Engineer. Keep `RUNTIME_ENV=prd` or leave
it unset. The scripts read `.env.production` before `.env` and upload its keys as
Fly secrets, except deploy settings that start with `FLY_`.

The stock Fly Postgres image lacks pgvector, and the API cannot start without it.
The setup script builds a PostgreSQL 18 image with pgvector, pushes it to the
app's Fly registry and creates the database from it. Set `FLY_PG_IMAGE` to use an
existing pgvector image instead, or `FLY_PG_VERSION` for another major version.

For a new deployment, leave the app name as `agentos` in [fly.toml](fly.toml).
The setup script creates a unique name and saves it there. To choose a region,
set `FLY_REGION` in `.env.production` (for example, `FLY_REGION=lhr`); the default
is `iad`. Later runs reuse the saved app name and region unless you set
`FLY_REGION`.

### 2. Deploy and set up authentication

Creates the app and a PostgreSQL service, uploads secrets, and deploys one always-on machine. Keep `--ha=false` when deploying so Fly does not create a second scheduler.

```sh
./scripts/fly/up.sh
```

This creates or uses billed resources. Start with one API instance; see the
[scaling guide](docs/scaling.md) for the optional multi-replica architecture. When the script shows the public URL and asks for a verification key:

1. Open [os.agno.com](https://os.agno.com), choose **Connect OS**, and select **Live**.
2. Enter the public URL and enable token-based authorization.
3. Copy the full public verification key into the script's prompt.

The script saves the key and connection settings in `.env.production`. If you
skipped the prompt, save the quoted `JWT_VERIFICATION_KEY` there and run
`./scripts/fly/env-sync.sh` to finish. Production requires a valid token
to access agents and data.

### 3. Check the deployment

Open `/health` and `/docs` on your public URL, then connect through the AgentOS UI.
Check that `/agents` rejects requests without a token and works with a valid token.

View logs with:

```sh
fly logs
```

### Connect your AI apps

Use your public URL followed by `/mcp` as the connector URL in an AI app.
When prompted, enter the `MCP_CONNECT_SECRET` saved in your production env file.
For a supported coding client, run:

```sh
uvx agno connect --url https://YOUR-DOMAIN
```

Try asking OS Manager about the platform to check that the connection works.

### Update or remove the deployment

| What you want to do | Command |
| --- | --- |
| Deploy code changes | `./scripts/fly/redeploy.sh` |
| Upload production settings | `./scripts/fly/env-sync.sh` |
| Remove a setting | `fly secrets unset NAME` |
| Remove the deployment | `./scripts/fly/down.sh` |

Removing a line from `.env.production` does not remove the Fly secret.
`down.sh` deletes the app, its PostgreSQL service and their volumes, and the
pgvector image in the app's registry. Review the resources listed before confirming deletion.

### Sandbox storage

The API service needs no attached disk. Conversations, memories and Company work
are stored in PostgreSQL. Without a sandbox, engineers run inside the API container;
their edited files and native sessions can be lost on redeploy or replacement.
Database conversation history does not reconstruct that working directory.

For durable, isolated engineering, configure [AWS AgentCore and S3](docs/harnesses.md#aws-agentcore-sandbox).
S3 stores the last saved workspace and native-session checkpoint. Recovery does
not preserve unfinished edits at the instant of a crash or replay external actions
safely. AWS is optional for getting started. Local Docker isolation is also
available in the [sandbox guide](docs/harnesses.md#local-docker-sandbox).

Before running multiple API instances, follow [Scaling](docs/scaling.md).

### Coding agent backend

`fly.toml` selects `SANDBOX_PROVIDER=agentcore`. Add the remaining host settings
from `scripts/aws.py status` to `.env.production`, then run `./scripts/fly/env-sync.sh`
and deploy code with `./scripts/fly/redeploy.sh`. Keep provisioning profiles local.

Enable coding agents and `SANDBOX_ENABLED` in code only after completing the
[harness setup](docs/harnesses.md); retain production JWT settings.

## Verify and develop

To check your Python code and test agent responses, install [uv](https://docs.astral.sh/uv/)
and run these commands from the project folder. Keep the local platform running.
If another Python environment is active, run `deactivate` first.

```sh
./scripts/venv_setup.sh
source .venv/bin/activate
./scripts/validate.sh
python -m evals --tag smoke
```

`validate.sh` checks Python formatting, lint rules, and types. The smoke tests ask
OS Manager to explain setup, check platform health, and explain agent memory.
They use your model API keys and save results in the database for review in the UI.
PostgreSQL must be running, even when you only want to list the tests.

Add your own cases in [evals/cases.py](evals/cases.py), or use
[/create-evals](.agents/skills/create-evals/SKILL.md). To save a report, add
`--json-output tmp/evals.json`. To run one case, use `--name CASE_NAME`.
Evals use your application's database and workspace; agents can call tools during a test.

Change dependencies in `pyproject.toml`, then run `./scripts/generate_requirements.sh`.
Commit the updated `requirements.txt` and rebuild the API and any sandbox image you use.
See [AGENTS.md](AGENTS.md) for the code layout and development conventions.

## Configuration

[example.env](example.env) shows the main settings. Start with `OPENAI_API_KEY`;
add the others when you need them. Use `.env` locally and `.env.production` for deployment.

| Setting | What it's for |
| --- | --- |
| `OPENAI_API_KEY` | OS Manager, embeddings, and Codex Engineer. |
| `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` | Claude Engineer. |
| `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` | Connect OS Manager to Slack. Set both. |
| `PARALLEL_API_KEY` | Optional web search key. Without it, search uses Parallel's MCP server without an API key. |
| `JWT_VERIFICATION_KEY` or `JWT_JWKS_FILE` | Check login tokens in production. A JWKS file must be available on the server. |
| `AGENTOS_URL` | Public URL used by scheduled jobs and MCP. Deployment scripts save it for you. |
| `MCP_CONNECT_SECRET` | Connect browser MCP clients. Deployment scripts generate it for you. |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_DATABASE` | PostgreSQL connection settings. Local Compose configures these for you. |
| `RUNTIME_ENV` | `prd` by default. Local Compose uses `dev`, which disables token checks. |

## Learn more

- [Agno documentation](https://docs.agno.com)
- [Agno on GitHub](https://github.com/agno-agi/agno)
- [AgentOS UI](https://os.agno.com)
