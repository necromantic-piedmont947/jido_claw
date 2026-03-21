# JidoClaw Roadmap

## Current State: v0.2-alpha

Single-agent and swarm runtime working. 24 tools, REPL with boot sequence, multi-provider LLM support, persistent sessions, DAG-based skills, solutions engine, agent-to-agent networking, multi-tenancy scaffolding, MCP server mode.

Shell sessions now use jido_shell with a custom `BackendHost` for real host command execution with CWD/env persistence.

---

## v0.2 — Stabilization & Polish

**Status: In Progress**

- [x] Codebase reorganization (cli/, agent/, core/, platform/, tools/)
- [x] System prompt externalized to `.jido/system_prompt.md`
- [x] jido_shell integration via `BackendHost` (real host commands + persistent sessions)
- [x] Swarm runtime (spawn_agent, list_agents, get_agent_result, send_to_agent, kill_agent)
- [x] Skills system (YAML-defined, DAG + sequential workflows)
- [x] Live swarm display (AgentTracker + Display GenServers)
- [ ] Full test suite green (RunCommand passing, others TBD)
- [ ] Session persistence end-to-end verification
- [ ] MCP server mode validation with Claude Code

---

## v0.3 — jido_ecto + Persistent Storage

**Status: Planned**

### Why

Current persistence is ETS + JSON files. Works for single-node CLI usage but doesn't scale to:
- Multi-tenant server deployments with data isolation
- Solution repositories with thousands of entries needing search
- Agent state recovery across restarts
- Audit trails for compliance

### Integration Plan

**Dependency:** `{:jido_ecto, github: "agentjido/jido_ecto"}`

#### Phase 1: Memory Backend Swap

Replace `JidoClaw.Memory` (ETS + `.jido/memory.json`) with jido_ecto-backed storage.

```
Before: Memory GenServer → ETS table → JSON file
After:  Memory GenServer → Jido.Ecto.Repo → PostgreSQL/SQLite
```

- Migrate memory schema to Ecto changesets
- Full-text search via PostgreSQL FTS (replaces naive string matching)
- Cross-session memory with timestamps and types

#### Phase 2: Solutions Store Migration

Replace `JidoClaw.Solutions.Store` (ETS + `.jido/solutions.json`) with database-backed store.

- Solution fingerprint indexing via composite indexes
- BM25-style search as a SQL query instead of in-memory scan
- Reputation ledger with atomic increments
- Trust score history (trending, not just current value)

#### Phase 3: Session & Agent State Persistence

- Session history in database (replace JSONL files)
- Agent checkpoint/resume across restarts
- Append-only audit log of all tool calls and decisions

#### Phase 4: Multi-Tenant Data Isolation

- Per-tenant database schemas or row-level security
- Tenant-scoped queries via Ecto query composition
- Migration management per tenant

### Decision Criteria

Migrate when ANY of these become true:
- Solution store exceeds 10K entries
- Multi-tenant deployment with 100+ concurrent tenants
- Compliance requires immutable audit trails
- Cluster deployment needs shared state across nodes

### Fallback

Keep JSON file persistence as the default for CLI-only usage. jido_ecto becomes opt-in for server deployments via config:

```yaml
# .jido/config.yaml
persistence:
  backend: ecto  # or "file" (default)
  database_url: "postgres://..."
```

---

## v0.4 — VFS Integration for File Tools

**Status: Planned**

Mount the project directory into jido_shell's VFS so file tools (`ReadFile`, `WriteFile`, `ListDirectory`) can work through the unified VFS layer. Enables:

- Same shell session handles both file ops and command execution
- Multi-mount workspaces:
  ```
  /project   → Jido.VFS.Adapter.Local (real filesystem)
  /scratch   → Jido.VFS.Adapter.InMemory (temp workspace)
  /upstream  → Jido.VFS.Adapter.GitHub (upstream repo)
  /artifacts → Jido.VFS.Adapter.S3 (build outputs)
  ```
- Agent can `cat /project/mix.exs` and `cat /upstream/mix.exs` in the same workflow
- VFS-aware diffing across adapters

---

## v0.5 — Burrito Packaging

**Status: Planned**

Single native binary distribution. Replaces escript (which has tzdata/runtime issues).

```elixir
# mix.exs
releases: [
  jido: [
    steps: [:assemble, &Burrito.wrap/1],
    burrito: [targets: [
      macos_aarch64: [os: :darwin, cpu: :aarch64],
      macos_x86_64: [os: :darwin, cpu: :x86_64],
      linux_x86_64: [os: :linux, cpu: :x86_64]
    ]]
  ]
]
```

- Cross-compile for macOS arm64/x86_64, Linux x86_64
- Self-contained — no Elixir/Erlang installation required
- Auto-update mechanism via GitHub releases

---

## v0.6 — Advanced Shell Integration

**Status: Planned**

Build on the jido_shell `BackendHost` foundation:

- **Custom command registry**: Register JidoClaw-specific commands (e.g., `jido status`, `jido memory search`) as jido_shell commands, accessible from the persistent session
- **SSH backend support**: Remote command execution on dev/staging servers via `Backend.SSH`
- **Streaming output to display**: Wire jido_shell transport events directly into Display for real-time output rendering during long-running commands
- **Environment profiles**: Named env var sets (dev, staging, prod) that can be switched per session

---

## v0.7 — Reasoning & Strategy Improvements

**Status: Planned**

- Strategy auto-selection based on task complexity analysis
- Strategy composition (e.g., CoT for planning + ReAct for execution)
- Strategy performance tracking (which strategies work best for which task types)
- User-defined strategy configurations in `.jido/strategies/`

---

## Future Considerations

### jido_ecto Specific Opportunities

| Capability | Current | With jido_ecto |
|---|---|---|
| Memory persistence | JSON file, FTS via string matching | PostgreSQL FTS, indexed queries |
| Solution search | In-memory Jaccard + BM25 | SQL-based BM25, composite indexes |
| Multi-tenant isolation | Process-level (ETS per tenant) | Database-level (schemas/RLS) |
| Audit trail | None (telemetry is volatile) | Append-only event log |
| Agent state recovery | No persistence | Checkpoint/resume via Ecto |
| Reputation tracking | JSON file | Atomic DB operations, history |
| Cluster coordination | `:pg` only | Shared DB state, distributed locks |
| Session history | JSONL files | Structured DB with search |

### Other Jido Ecosystem Libraries to Watch

| Library | Status | Potential Use |
|---|---|---|
| **jido_ecto** | Beta | Persistent storage backend (see v0.3 above) |
| **jido_discovery** | TBD | Agent/service discovery in distributed deployments |
| **jido_workflow** | TBD | Advanced workflow patterns beyond current Composer FSM |

---

## Build Order

```
v0.2 (current) → v0.3 (jido_ecto) → v0.4 (VFS) → v0.5 (Burrito) → v0.6 (Shell) → v0.7 (Reasoning)
                          ↑
                  Gate: scale requirements met
```

v0.3 is gated on actual need — don't add database complexity until the file-based approach is a proven bottleneck.
