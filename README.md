# JidoClaw

[![Elixir](https://img.shields.io/badge/Elixir-1.17%2B-blueviolet?logo=elixir)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/OTP-27%2B-blue)](https://www.erlang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/robertohluna/jido_claw)](https://github.com/robertohluna/jido_claw/issues)
[![GitHub tag](https://img.shields.io/github/v/tag/robertohluna/jido_claw?label=version)](https://github.com/robertohluna/jido_claw/tags)
[![Tests](https://img.shields.io/github/actions/workflow/status/robertohluna/jido_claw/ci.yml?label=tests)](https://github.com/robertohluna/jido_claw/actions)
[![30 Tools](https://img.shields.io/badge/tools-30-orange)](docs/ARCHITECTURE.md)
[![8 Providers](https://img.shields.io/badge/providers-8-blue)](docs/ARCHITECTURE.md)
[![7 Skills](https://img.shields.io/badge/skills-7-green)](docs/ARCHITECTURE.md)

> Full-stack AI agent platform built on the Jido framework for Elixir/OTP — CLI, web dashboard, sandbox execution, workflow orchestration, GitHub automation, and desktop app

```
     ██╗██╗██████╗  ██████╗  ██████╗██╗      █████╗ ██╗    ██╗
     ██║██║██╔══██╗██╔═══██╗██╔════╝██║     ██╔══██╗██║    ██║
     ██║██║██║  ██║██║   ██║██║     ██║     ███████║██║ █╗ ██║
██   ██║██║██║  ██║██║   ██║██║     ██║     ██╔══██║██║███╗██║
╚█████╔╝██║██████╔╝╚██████╔╝╚██████╗███████╗██║  ██║╚███╔███╔╝
 ╚════╝ ╚═╝╚═════╝  ╚═════╝  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝
        自 動  ·  autonomous
```

JidoClaw is a full-stack AI agent orchestration platform built natively on the [Jido](https://github.com/agentjido/jido) framework for Elixir/OTP. It combines a CLI REPL, LiveView web dashboard, sandboxed code execution (Forge), persistent workflow orchestration with approval gates, a hierarchical GitHub issue bot, GTD task management, encrypted secret storage, and desktop app packaging — all in one Elixir application.

## Platform Overview

| Layer | What It Does |
|-------|-------------|
| **CLI REPL** | Interactive terminal agent with 30 tools, swarm orchestration, live display |
| **Web Dashboard** | LiveView UI — dashboard, forge terminal, workflows, agents, projects, settings, GTD |
| **Forge** | Sandboxed code execution engine with 4 runner types (shell, claude_code, workflow, custom) |
| **Orchestration** | Persistent workflow engine with state machine, approval gates, retry lineage |
| **GitHub Bot** | Hierarchical multi-agent pipeline — triage → parallel research → PR generation |
| **Folio GTD** | Getting Things Done task management — inbox capture, context/energy tracking |
| **Security** | AES-256-GCM encryption at rest, multi-layer secret redaction (logs, prompts, UI, PubSub) |
| **Desktop App** | Tauri + Burrito packaging — native binary with embedded Phoenix server |
| **Data Layer** | Ash Framework 3.0 + PostgreSQL — resources, authentication, admin panel |

## Why JidoClaw?

- **BEAM-native**: Lightweight processes, fault tolerance, hot code reload — no Kubernetes required for multi-agent workloads
- **Full-stack**: CLI, REST API, WebSocket, LiveView dashboard, desktop app — one codebase, every interface
- **Multi-provider**: Ollama (local + cloud), Anthropic, OpenAI, Google, Groq, xAI, OpenRouter — 8 providers, 35+ models
- **Sandboxed execution**: Forge runs code in isolated sprite containers with session lifecycle, concurrency limits, and streaming output
- **Workflow orchestration**: Persistent state machine with approval gates — human-in-the-loop for critical operations
- **GitHub automation**: Hierarchical agent pipeline processes issues end-to-end — triage, research, patch, PR
- **Security-first**: Encrypted secrets at rest, redaction filters on every output channel, API key authentication
- **Multi-tenant**: Per-tenant supervision trees isolate resources and prevent cascading failures
- **Swarm orchestration**: The LLM decides when to spawn child agents — `spawn_agent`, `list_agents`, `send_to_agent` are first-class tools
- **30 built-in tools**: File ops, git, shell, code search, memory, solution caching, network sharing, swarm, reasoning, scheduling
- **8 reasoning strategies**: ReAct, CoT, CoD, ToT, GoT, AoT, TRM, Adaptive — switchable per-session
- **Observable**: 20+ telemetry events, Phoenix LiveDashboard, structured logging

## Quick Start

### Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)
- Git

### Setup

```bash
git clone https://github.com/robertohluna/jido_claw.git
cd jido_claw
mix deps.get && mix compile

# Create and migrate the database
mix ash.setup

# Start with CLI + web dashboard
JIDOCLAW_MODE=both mix jidoclaw
```

The web dashboard is available at `http://localhost:4000`. On first launch, the setup wizard checks prerequisites and guides you through provider/model configuration.

### CLI Only

```bash
mix jidoclaw
```

### First Boot

```
  v0.4.0 · elixir 1.17.3 · otp 27

  ⚙  workspace   my-project
  ⚙  provider    ollama cloud
  ⚙  model       nemotron-3-super:cloud
  ⚙  strategy    react
  ⚙  tools       30 loaded
  ✓  skills      7 loaded
  ✓  database    connected
  ✓  forge       ready (50 slots)

  Type a message to start. /help for commands. Ctrl+C to quit.

jidoclaw>
```

## Data Layer — Ash Framework + PostgreSQL

JidoClaw uses [Ash Framework 3.0](https://ash-hq.org) as its resource layer, backed by PostgreSQL via AshPostgres.

### Domains & Resources

| Domain | Resources | Purpose |
|--------|-----------|---------|
| **Accounts** | User, Token, ApiKey | Authentication (password + magic link), API key management |
| **Projects** | Project | Project registry with GitHub repo linking |
| **Security** | SecretRef | Encrypted secret storage (AES-256-GCM via Cloak) |
| **Forge** | Session, ExecSession, Checkpoint, Event | Sandbox session audit trail |
| **Orchestration** | WorkflowRun, WorkflowStep, ApprovalGate | Persistent workflow state machine |
| **GitHub** | IssueAnalysis | Issue triage and analysis records |
| **Folio** | InboxItem, Action, Project | GTD task management |

### Authentication

Built on AshAuthentication with two strategies:

- **Password**: Email/password with hashed credentials, token-based sign-in
- **Magic Link**: Passwordless email authentication

API endpoints are protected via Bearer token or `x-api-key` header, validated against the ApiKey resource.

### Admin Panel

AshAdmin is mounted at `/admin` — browse and manage all resources through a web interface.

## Forge — Sandbox Execution Engine

Forge is a generic parallel sandbox execution engine that runs code in isolated sprite containers.

### Runner Types

| Runner | Purpose | Concurrency Limit |
|--------|---------|-------------------|
| `shell` | Shell command execution | 20 |
| `claude_code` | Claude CLI with `--output-format stream-json` | 10 |
| `workflow` | Data-driven step engine with variable interpolation | 10 |
| `custom` | User-defined function runner | 10 |

**Total capacity: 50 concurrent sessions**

### Session Lifecycle

```
starting → bootstrapping → initializing → ready → running → stopping
                                            ↓
                                      needs_input
```

Sessions are tracked via OTP Registry, monitored for crashes, and persisted to PostgreSQL for audit.

### Usage

```elixir
# Start a shell session
{:ok, handle} = JidoClaw.Forge.start_session("my-task", runner: :shell)

# Execute commands
{:ok, output} = JidoClaw.Forge.exec(handle, "echo hello")

# Run a workflow
{:ok, handle} = JidoClaw.Forge.start_session("deploy", runner: :workflow, config: %{
  steps: [
    %{type: :exec, command: "mix test"},
    %{type: :exec, command: "mix release"},
    %{type: :prompt, message: "Deploy to production?"}
  ]
})
```

### Sprite Client

Forge abstracts container management through a SpriteClient behaviour:

- **Live**: Real sprite containers for production
- **Fake**: Temp directory + `System.cmd` for dev/test — no containers needed

### Streaming

Output is coalesced at 50ms intervals with a 64KB buffer (1MB max) to prevent UI flooding.

## Orchestration — Workflow Engine

Persistent workflow engine with state machine lifecycle and human-in-the-loop approval gates.

### Workflow States

```
pending → running → completed
              ↓
        awaiting_approval → completed
              ↓                ↓
           cancelled        failed
```

### Approval Gates

Critical workflow steps can require human approval before proceeding:

```elixir
# Workflow pauses at approval gate
# Approver reviews and decides
Ash.update!(gate, %{decision: :approved, approver_id: user.id})
# Workflow resumes
```

### Retry Lineage

Failed workflows can be retried — each retry links back to the original via `retry_of_id`, maintaining full lineage.

### Step Handlers

| Handler | Purpose |
|---------|---------|
| `CommitAndPR` | Git commit + pull request creation |
| `ForgeExec` | Delegates to Forge for sandboxed execution |
| `AgentTask` | Delegates to Jido agent runtime |

## GitHub Issue Bot

Hierarchical multi-agent pipeline that processes GitHub issues end-to-end.

### Pipeline

```
Webhook (issues.opened) → Coordinator Agent
  ├── Triage Agent (keyword + label classification)
  ├── Research Coordinator (4 parallel agents)
  │   ├── Code Search Agent
  │   ├── Reproduction Agent
  │   ├── Root Cause Agent
  │   └── PR Search Agent
  └── PR Coordinator (3-attempt retry with quality gate)
      ├── Patch Agent (generates fix)
      ├── Quality Agent (reviews patch)
      └── PR Submit Agent (creates PR)
```

### Webhook Setup

Configure your GitHub App to send `issues` and `issue_comment` events to `/webhooks/github`. Payloads are verified via HMAC-SHA256.

```bash
export GITHUB_WEBHOOK_SECRET=your-webhook-secret
export GITHUB_APP_PRIVATE_KEY=...
```

## Folio — GTD Task Management

Getting Things Done workflow with inbox capture, clarification, and context-aware action tracking.

### GTD Flow

```
Capture → Inbox → Clarify → Actionable?
                              ├── Yes → Action (next, waiting, someday)
                              └── No  → Discard / Reference
```

### Action Tracking

Actions support context (`@phone`, `@computer`, `@office`), energy level (`low`, `normal`, `high`), time estimates, and due dates.

### Access

Available through the LiveView UI at `/folio` and as AI agent tools for natural language task management.

## Security

### Encrypted Secrets

Secrets are encrypted at rest using AES-256-GCM via Cloak Vault:

```elixir
# Store an encrypted secret
Ash.create!(JidoClaw.Security.SecretRef, %{
  name: "github_token",
  encrypted_value: "ghp_xxxxxxxxxxxx",
  scope: "project:my-app"
})
```

### Multi-Layer Redaction

Every output channel is filtered for secrets:

| Layer | What It Catches |
|-------|----------------|
| **Log Redactor** | Logger filter strips secrets before they hit log files |
| **Prompt Redaction** | Strips secrets before sending to LLM providers |
| **Channel Redaction** | PubSub messages are sanitized |
| **UI Redaction** | Display output is filtered |

### Pattern Detection

9 regex patterns detect: API keys (OpenAI, Anthropic, AWS), Bearer tokens, JWTs, GitHub PATs, generic secrets, private keys, and connection strings.

## Web Dashboard

LiveView-powered dark-themed web interface at `http://localhost:4000`.

### Pages

| Route | Page | Purpose |
|-------|------|---------|
| `/` | Dashboard | Agent status, recent runs, platform stats |
| `/forge` | Forge Terminal | Interactive sandbox terminal (xterm.js) |
| `/workflows` | Workflows | Workflow runs, step status, approval UI |
| `/agents` | Agents | Agent configuration, templates, issue bot toggle |
| `/projects` | Projects | Project list, GitHub repo linking |
| `/settings` | Settings | User settings, API key management |
| `/folio` | Folio | GTD inbox, actions, projects |
| `/setup` | Setup Wizard | Prerequisite checks, credential validation |
| `/sign-in` | Sign In | Authentication |
| `/admin` | Admin Panel | AshAdmin resource browser |
| `/live-dashboard` | LiveDashboard | Phoenix telemetry metrics |

### Authentication

Session-based auth with `on_mount` hooks:

- `:live_user_required` — redirects unauthenticated users to sign-in
- `:live_user_optional` — allows anonymous access
- `:live_no_user` — sign-in/setup pages only

## Desktop App

JidoClaw can be packaged as a native desktop application using Tauri (frontend shell) + Burrito (Elixir binary packaging).

### How It Works

1. Burrito compiles JidoClaw into a self-contained native binary
2. On launch, the sidecar detects `BURRITO_TARGET` or `JIDOCLAW_DESKTOP=true`
3. An available port is found via `:gen_tcp.listen(0, ...)`
4. Phoenix starts as an embedded server with `check_origin: false`
5. Tauri opens a webview pointing at `localhost:{port}`

```bash
# Build native binary
mix release

# Or set env for development
JIDOCLAW_DESKTOP=true mix phx.server
```

## Setup Wizard

On first launch (or at `/setup`), the wizard checks:

| Check | What | Required |
|-------|------|----------|
| Elixir | Version ≥ 1.17 | Yes |
| PostgreSQL | Running, accessible | Yes |
| Git | Installed | Yes |
| Node.js | Version ≥ 18 | Yes |
| Ollama | Running locally | No (cloud providers available) |
| API Keys | Valid format, reachable | At least one provider |

## Live Swarm Display

JidoClaw renders a fully live terminal UI as your agent works — no external TUI library, just pure ANSI escape codes.

### Status Bar

```
 ⚕ qwen3-coder:32b │ ollama │ 24.1K/128K │ [██████░░░░] 19% │ $0.00 │ 3m │ 3 agents
```

### Swarm Box

```
 ┌─ SWARM ─────────────────────────────────────────────────┐
 │  3 agents  │  2 running  1 done  │  8.2K tokens  $0.00  │
 └────────────────────────────────────────────────────────┘
  ✓ @test-runner-1 [test_runner] done │ 3.1K │ $0.00 │ 4 calls │ run_command, read_file
  ● @reviewer-1 [reviewer] running │ 2.8K │ $0.00 │ 3 calls │ git_diff, read_file
  ● @refactorer-1 [refactorer] running │ 2.3K │ $0.00 │ 2 calls │ search_code, read_file
```

## Interfaces

### CLI REPL

Interactive terminal with 30 tools, swarm orchestration, and live display.

```
jidoclaw> explain the authentication flow in this codebase
  (◕‿◕) thinking...
  ⟳ search_code query="auth"
  ✓ search_code
  ⟳ read_file path="lib/auth/guardian.ex"
  ✓ read_file

  The authentication flow uses Guardian for JWT...

jidoclaw> /agents      # list running child agents
jidoclaw> /skills      # list available skills
jidoclaw> /models      # list models for current provider
jidoclaw> /strategy    # show current reasoning strategy
jidoclaw> /status      # show config and stats
jidoclaw> /setup       # reconfigure provider/model
jidoclaw> /help        # full command list
```

### REST API (OpenAI-compatible)

```bash
# Health check
curl http://localhost:4000/health

# Chat completion (API key required)
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

### WebSocket RPC

Connect to `ws://localhost:4000/ws` and join `rpc:lobby`:

```json
{"topic": "rpc:lobby", "event": "gateway.status", "payload": {}}
{"topic": "rpc:lobby", "event": "sessions.create", "payload": {"tenant_id": "default", "session_id": "my-session"}}
{"topic": "rpc:lobby", "event": "sessions.sendMessage", "payload": {"tenant_id": "default", "session_id": "my-session", "content": "Hello!"}}
```

## Supported Providers & Models

JidoClaw supports 8 LLM providers via [req_llm](https://hex.pm/packages/req_llm). Run `/setup` to switch providers.

### Ollama (Local)

| Model | Size | Context | Notes |
|-------|------|---------|-------|
| **`nemotron-3-super:latest`** | **120B MoE (12B active)** | **256K** | **Default — best accuracy/efficiency** |
| `qwen3.5:35b` | 35B | 128K | Lightweight local model |
| `qwen3-coder-next:latest` | — | 128K | Code-focused |
| `devstral-small-2:24b` | 24B | 128K | Code-focused, efficient |

### Ollama Cloud

| Model | Size | Context | Notes |
|-------|------|---------|-------|
| **`nemotron-3-super:cloud`** | **120B MoE (12B active)** | **256K** | **Recommended** |
| `qwen3-coder:480b` | 480B | 256K | Massive code model |
| `deepseek-v3.1:671b` | 671B | 128K | Largest available |
| `llama4-maverick:latest` | MoE | 1M | Million-token context |

### Cloud Providers

| Provider | API Key | Top Models | Context |
|----------|---------|------------|---------|
| **Anthropic** | `ANTHROPIC_API_KEY` | Claude Sonnet 4, Opus 4.6, Haiku 4.5 | 200K |
| **OpenAI** | `OPENAI_API_KEY` | GPT-4.1, o3, o4-mini | 200K–1M |
| **Google** | `GOOGLE_API_KEY` | Gemini 2.5 Flash, Gemini 2.5 Pro | 1M |
| **Groq** | `GROQ_API_KEY` | Llama 3.3 70B | 128K |
| **xAI** | `XAI_API_KEY` | Grok 3, Grok 3 Mini | 131K |
| **OpenRouter** | `OPENROUTER_API_KEY` | 200+ models | varies |

## Architecture

```
JidoClaw.Supervisor
├── JidoClaw.Repo (PostgreSQL via AshPostgres)
├── JidoClaw.Security.Vault (AES-256-GCM encryption)
├── Registry (SessionRegistry, TenantRegistry)
├── Phoenix.PubSub
├── Finch (HTTP pools)
├── Jido.Signal.Bus (jido_claw.* events)
├── JidoClaw.Telemetry (20+ metrics)
├── JidoClaw.Stats (session counters)
├── JidoClaw.BackgroundProcess.Registry
├── JidoClaw.Tool.Approval
├── JidoClaw.Messaging (rooms, agents, bridges)
│
├── Forge Engine
│   ├── Registry (SessionRegistry)
│   ├── SpriteSupervisor (DynamicSupervisor)
│   ├── ExecSessionSupervisor (DynamicSupervisor)
│   ├── Forge.Manager (GenServer — concurrency control)
│   └── SpriteClient.Fake (dev/test sprite stub)
│
├── Orchestration
│   └── RunSummaryFeed (GenServer — workflow status aggregator)
│
├── Code Server
│   ├── Registry (RuntimeRegistry)
│   └── RuntimeSupervisor (DynamicSupervisor)
│
├── JidoClaw.SessionSupervisor (DynamicSupervisor)
├── JidoClaw.Jido (agent runtime)
├── JidoClaw.Tenant.Supervisor
│   └── per tenant:
│       ├── Session.Supervisor
│       ├── Channel.Supervisor
│       ├── Cron.Supervisor
│       └── Tool.Supervisor
├── JidoClaw.Tenant.Manager
├── JidoClaw.Solutions.Store + Reputation
├── JidoClaw.Memory (ETS + JSON)
├── JidoClaw.Skills (cached registry)
├── JidoClaw.Shell.SessionManager
├── JidoClaw.Network.Supervisor
├── JidoClaw.Web.Endpoint (Phoenix — port 4000)
└── Cluster.Supervisor (libcluster, optional)
```

### Ash Domains

| Domain | Module | Resources |
|--------|--------|-----------|
| Accounts | `JidoClaw.Accounts` | User, Token, ApiKey |
| Projects | `JidoClaw.Projects` | Project |
| Security | `JidoClaw.Security` | SecretRef |
| Forge | `JidoClaw.Forge.Domain` | Session, ExecSession, Checkpoint, Event |
| Orchestration | `JidoClaw.Orchestration` | WorkflowRun, WorkflowStep, ApprovalGate |
| GitHub | `JidoClaw.GitHub` | IssueAnalysis |
| Folio | `JidoClaw.Folio` | InboxItem, Action, Project |

## Tools (30)

| Category | Tools |
|----------|-------|
| **File Ops** | `read_file`, `write_file`, `edit_file`, `list_directory`, `search_code`, `project_info` |
| **Git** | `git_status`, `git_diff`, `git_commit` |
| **Shell** | `run_command` (persistent sessions via jido_shell) |
| **Swarm** | `spawn_agent`, `get_agent_result`, `list_agents`, `send_to_agent`, `kill_agent` |
| **Skills** | `run_skill` (sequential FSM or parallel DAG) |
| **Memory** | `remember`, `recall` |
| **Solutions** | `store_solution`, `find_solution` |
| **Network** | `network_share`, `network_status` |
| **Scheduling** | `schedule_task`, `unschedule_task`, `list_scheduled_tasks` |
| **Reasoning** | `reason` (8 strategies: react, cot, cod, tot, got, aot, trm, adaptive) |
| **Browser** | `browse` |

File tools support VFS URI schemes: `github://owner/repo/path`, `s3://bucket/key`, `git://repo/path`.

## Swarm Orchestration

Agent spawning is a first-class tool — the LLM calls `spawn_agent` when it decides it needs parallel workers.

### Agent Templates

| Template | Capabilities | Max Iterations | Use Case |
|----------|-------------|----------------|----------|
| `coder` | Full R/W + commands | 25 | Coding, bug fixes, features |
| `test_runner` | Read + run_command | 15 | Test execution |
| `reviewer` | Read + git | 15 | Code review |
| `docs_writer` | Read + write | 15 | Documentation |
| `researcher` | Read-only | 15 | Codebase analysis |
| `refactorer` | Full R/W + commands | 25 | Refactoring |

### Custom Agents (`.jido/agents/`)

```yaml
name: security_auditor
description: Finds OWASP Top 10 vulnerabilities
template: reviewer
model: :capable
max_iterations: 20
system_prompt: |
  You are a security auditor. Focus on injection, auth bypass,
  hardcoded secrets, SSRF, path traversal...
tools:
  - read_file
  - search_code
  - git_diff
```

### Skills (`.jido/skills/`)

| Skill | Execution | Steps | Purpose |
|-------|-----------|-------|---------|
| `full_review` | **DAG** | test_runner + reviewer (parallel) → synthesize | Test + review concurrently |
| `refactor_safe` | Sequential | reviewer → refactorer → test_runner | Review, refactor, verify |
| `implement_feature` | **DAG** | research → implement → test + review (parallel) → synthesize | Full feature lifecycle |
| `debug_issue` | Sequential | researcher → test_runner → coder → test_runner | Systematic debugging |
| `security_audit` | Sequential | researcher → reviewer | Vulnerability scanning |

## Reasoning Strategies

8 AI reasoning strategies from `jido_ai`, switchable per-session via `/strategy <name>`:

| Strategy | Best For |
|----------|----------|
| **`react`** (default) | Tool-using agents — observe, think, act loop |
| `cot` | Step-by-step logical reasoning |
| `cod` | Iterative draft refinement |
| `tot` | Branching exploration of solution paths |
| `got` | Non-linear reasoning with cross-connections |
| `aot` | Atomic decomposition of complex problems |
| `trm` | Task-oriented reasoning with planning |
| `adaptive` | Auto-selects strategy based on task type |

## Virtual Filesystem (VFS)

File tools transparently support remote paths via `jido_vfs`:

| Scheme | Auth |
|--------|------|
| `github://owner/repo[@ref]/path` | `GITHUB_TOKEN` |
| `s3://bucket/key` | AWS credentials |
| `git://repo-path//file-path` | Local access |

## Platform Features

### Multi-Tenancy

Each tenant gets an isolated supervision subtree with its own session, channel, cron, and tool supervisors.

```elixir
{:ok, tenant} = JidoClaw.create_tenant(name: "acme")
{:ok, response} = JidoClaw.chat("acme", "session_1", "Hello!")
```

### Channel Adapters

Connect your agent to Discord and Telegram. Adapters implement `JidoClaw.Channel.Behaviour` — add Slack, IRC, or any platform by implementing 5 callbacks.

### Cron Scheduling

```elixir
JidoClaw.Cron.Scheduler.schedule("default",
  schedule: {:cron, "0 9 * * MON"},
  task: "Generate weekly code review report",
  mode: :isolated
)
```

Auto-disables after 3 consecutive failures. Stuck detection at 2 hours.

### Persistent Memory

Cross-session knowledge stored in `.jido/memory.json`:

```
jidoclaw> /memory                     # list all memories
jidoclaw> /memory search auth         # search by keyword
jidoclaw> /memory save "pattern" ...  # save a memory
```

### Clustering

Optional multi-node support via libcluster:

```elixir
config :jido_claw,
  cluster_enabled: true,
  cluster_strategy: :gossip  # :gossip | :kubernetes | :epmd
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `JIDOCLAW_MODE` | Runtime mode: `cli`, `gateway`, or `both` |
| `JIDOCLAW_ENCRYPTION_KEY` | 32-byte hex key for Cloak Vault (AES-256-GCM) |
| `JIDOCLAW_DESKTOP` | Set to `true` for desktop sidecar mode |
| `JIDOCLAW_PORT` | Override port for desktop mode |
| `GITHUB_WEBHOOK_SECRET` | HMAC secret for GitHub webhook verification |
| `OLLAMA_API_KEY` | Ollama Cloud API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_API_KEY` | Google Gemini API key |
| `GROQ_API_KEY` | Groq API key |
| `XAI_API_KEY` | xAI Grok API key |
| `OPENROUTER_API_KEY` | OpenRouter API key |
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token |
| `GITHUB_TOKEN` | GitHub API token (for VFS) |

## Project Structure

```
lib/jido_claw/
├── application.ex              # OTP supervision tree
├── repo.ex                     # AshPostgres.Repo
├── accounts.ex                 # Ash.Domain — users, auth, API keys
├── accounts/
│   ├── user.ex                 # User resource (password + magic link auth)
│   ├── token.ex                # AshAuthentication token resource
│   ├── api_key.ex              # API key resource
│   └── secrets.ex              # Auth secret provider
├── projects.ex                 # Ash.Domain — project registry
├── projects/
│   └── project.ex              # Project resource
├── security.ex                 # Ash.Domain — encrypted secrets
├── security/
│   ├── vault.ex                # Cloak.Vault (AES-256-GCM)
│   ├── secret_ref.ex           # Encrypted secret resource (AshCloak)
│   └── redaction/              # 4 redaction filters (log, prompt, channel, UI)
├── forge.ex                    # Forge facade
├── forge/
│   ├── manager.ex              # Concurrency control GenServer
│   ├── sprite_session.ex       # Per-session state machine GenServer
│   ├── runner.ex               # Runner behaviour
│   ├── runners/                # shell, claude_code, workflow, custom
│   ├── sprite_client/          # Container abstraction (live, fake)
│   ├── domain.ex               # Ash.Domain — session audit
│   ├── resources/              # Session, ExecSession, Checkpoint, Event
│   ├── bootstrap.ex            # Sprite initialization
│   ├── persistence.ex          # Fire-and-forget Ash persistence
│   ├── pubsub.ex               # Redaction-gated PubSub
│   └── error.ex                # Typed exceptions
├── orchestration.ex            # Ash.Domain — workflows
├── orchestration/
│   ├── workflow_run.ex         # 6-state workflow lifecycle
│   ├── workflow_step.ex        # Step status and output
│   ├── approval_gate.ex        # Human approval resource
│   ├── run_pubsub.ex           # Workflow event broadcasting
│   └── run_summary_feed.ex     # Status aggregator GenServer
├── github.ex                   # Ash.Domain — issue analysis
├── github/
│   ├── webhook_signature.ex    # HMAC-SHA256 verification
│   ├── webhook_pipeline.ex     # Event routing
│   ├── issue_comment_client.ex # GitHub API client
│   └── agents/                 # Coordinator, Triage, Research (4), PR (3)
├── folio.ex                    # Ash.Domain — GTD
├── folio/
│   ├── inbox_item.ex           # Capture/process/discard
│   ├── action.ex               # Next/waiting/someday with context
│   └── project.ex              # GTD projects
├── code_server.ex              # Project runtime facade
├── code_server/
│   └── runtime.ex              # Per-project GenServer
├── setup/
│   ├── prerequisite_checker.ex # System requirement checks
│   ├── credential_validator.ex # API key validation
│   └── wizard.ex               # Setup orchestrator
├── desktop/
│   ├── sidecar.ex              # Burrito/Tauri detection
│   └── port_finder.ex          # Available port detection
├── agent/                      # Jido agent (30 tools)
├── cli/                        # CLI REPL, commands, branding
├── platform/                   # Sessions, channels, cron, tenants
├── tools/                      # Tool implementations
├── web/
│   ├── endpoint.ex             # Phoenix endpoint
│   ├── router.ex               # API + webhook + LiveView routes
│   ├── live_user_auth.ex       # LiveView auth hooks
│   ├── components/             # Core components, layouts
│   ├── live/                   # 8 LiveView pages
│   ├── controllers/            # Health, Chat, Webhook
│   ├── channels/               # WebSocket RPC
│   └── plugs/                  # API key auth
└── ...
```

## Canopy Workspace Integration

JidoClaw works as an agent runtime inside [Canopy](https://github.com/Miosa-osa/canopy) workspaces — the open-source workspace agent harness protocol. Canopy integration is opt-in.

## Agent Harness Compatibility

JidoClaw's OpenAI-compatible REST API (`/v1/chat/completions`) works with any tool that speaks the OpenAI chat API — [JidoHarness](https://github.com/agentjido/jido_harness), [PaperClip](https://github.com/nicholasgasior/paperclip), or custom clients.

## Development

```bash
mix deps.get          # Install dependencies
mix compile           # Compile
mix ash.setup         # Create database + run migrations
mix test              # Run tests
mix format            # Format code
iex -S mix            # IEx with app loaded
JIDOCLAW_MODE=both iex -S mix   # Dev with gateway + dashboard
```

## Dependencies

| Category | Package | Purpose |
|----------|---------|---------|
| **Data layer** | `ash`, `ash_postgres`, `ash_authentication`, `ash_admin`, `ash_json_api`, `ash_cloak`, `ash_state_machine` | Resource framework, persistence, auth, admin |
| **Database** | `ecto_sql`, `postgrex` | PostgreSQL adapter |
| **Encryption** | `cloak` | AES-256-GCM encryption at rest |
| **Agent engine** | `jido`, `jido_ai`, `jido_action`, `jido_signal` | Agent runtime, AI reasoning, tools, events |
| **Ecosystem** | `jido_shell`, `jido_vfs`, `jido_memory`, `jido_mcp`, `jido_browser`, `jido_skill`, `jido_composer`, `jido_messaging` | Shell, VFS, memory, MCP, browser, skills, workflows, messaging |
| **LLM providers** | `req_llm` | Ollama, Anthropic, OpenAI, Google, Groq, xAI, OpenRouter |
| **Web** | `phoenix`, `phoenix_live_view`, `bandit` | HTTP/WS/LiveView |
| **Observability** | `telemetry`, `phoenix_live_dashboard` | Metrics and dashboard |

## Built on Jido

JidoClaw is powered by the [Jido](https://github.com/agentjido/jido) autonomous agent framework for Elixir/OTP, created by [Mike Hostetler](https://github.com/agentjido). Jido (自動 — Japanese for "automatic/autonomous") provides the foundational agent runtime, action system, signal routing, and AI reasoning strategies.

## License

MIT
