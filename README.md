<div align="center">

# Agora

**Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies on top of Locu & Braid**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![tmux](https://img.shields.io/badge/tmux-3.0%2B-green.svg)](https://github.com/tmux/tmux)
[![Locu](https://img.shields.io/badge/Locu-0.1.3%2B-red.svg)](https://github.com/axiomantic/locu)
[![Braid](https://img.shields.io/badge/Braid-0.1.0%2B-purple.svg)](https://github.com/axiomantic/braid)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](README.md)

*Where `locu` provides inter-agent transport and `braid` provides workspace virtualization, `agora` provides the institutional intellect, empirical deliberation, and synchronized swarm execution.*

</div>

---

## What is Agora?

**Agora** is an agentic engineering framework and skill library for orchestrating heterogeneous teams of AI coding assistants (Claude Code, OpenCode, Antigravity, Cursor, Codex).

Instead of treating AI agents as isolated single-turn chatbots, Agora provisions **coordinated worker swarms** inside multiplexed `tmux` sessions, balances specialized personas with designated foundation models and harnesses, drives **empirically grounded dialectical deliberation**, schedules distributed fencing mutexes, and integrates code through isolated APFS Copy-on-Write strands verified by Braid's Two-Key Gate.

```mermaid
flowchart TD
    subgraph Layer3["Layer 3: Agora (Methodology, Ceremonies & Swarms)"]
        direction TB
        AgoraSkill["agora (Master Entrypoint)"]
        P1["choose-personas (Team & Models)"]
        P2["launch-workers (tmux & Terminal Viewer)"]
        P3["dialectical-pump (Research ➔ Design ➔ Audit)"]
        P4["plan-implementation (Locks & Strands)"]
        P5["orchestrate-swarm (Dispatch & Weave)"]
        AgoraSkill --> P1 --> P2 --> P3 --> P4 --> P5
    end

    subgraph Layer2["Layer 2: Braid (Workstream Integrator)"]
        Strands["APFS CoW Strands (Sub-second isolated workspaces)"]
        TwoKey["Two-Key Gate (Mechanical merge-tree + semantic test suite)"]
        Weave["Trunk Weaving (Fast-forward verified branches)"]
    end

    subgraph Layer1["Layer 1: Locu (Inter-Agent Transport)"]
        Bus["Redis Message Bus (O2O, Multicast, RPC)"]
        Locks["Distributed Mutexes & Monotonic Fencing Tokens"]
        Queues["Worker Queues with Leases & Dead-Letter Escalation"]
    end

    Layer3 --> Layer2
    Layer3 --> Layer1
    Layer2 -.-> Layer1
```

---

## The 5 Core Skills (+ Master Entrypoint)

Agora is organized into a clean, batteries-included catalog of self-explanatory skills:

| Skill | Role | Description |
| :--- | :--- | :--- |
| **[`agora`](skills/agora/SKILL.md)** | **Master Entrypoint** | The sovereign ceremony director. Guides orchestrator and operator step-by-step across all phases from initial task to woven code. |
| **[`choose-personas`](skills/choose-personas/SKILL.md)** | **Team Calibration** | Formulates a balanced triad of specialized personas (e.g. Architect, Auditor, DevEx Lead) with explicitly recommended **coding harnesses** and **model tiers**, confirmed interactively with the operator. |
| **[`launch-workers`](skills/launch-workers/SKILL.md)** | **Fleet Provisioning** | Boots a structured `tmux` session with named worker panes, injects environment variables, registers identities via `locu open`, arms listeners, and pops open your preferred OS terminal viewer (Ghostty / Terminal.app). |
| **[`dialectical-pump`](skills/dialectical-pump/SKILL.md)** | **Empirical Deliberation** | Drives multi-perspective thesis/antithesis/synthesis debates. Strictly prohibits theatrical roleplay: every turn requires tool execution (reading files, running tests, checking ASTs). Produces `understanding.md`, `design.md`, and `audit_report.md`. |
| **[`plan-implementation`](skills/plan-implementation/SKILL.md)** | **Master Scheduling** | Authors `implementation_plan.md` defining task assignment matrices, `locu` distributed fencing locks, `braid` strand workflows, dynamic markdown checkboxes, harness To-Do integration, and emergent design addenda. |
| **[`orchestrate-swarm`](skills/orchestrate-swarm/SKILL.md)** | **Main-Chat Governor** | Governs execution from the primary chat session: dispatches tasks over Redis, tracks heartbeats, ratifies emergent design addenda, verifies Two-Key gate passes, and triggers `braid weave`. |

---

## System Prerequisites

1. **`tmux`** (3.0+):
   ```bash
   brew install tmux
   ```
2. **`locu`** (Locutus Coordination Engine):
   ```bash
   npm install -g @axiomantic/locu
   ```
3. **`braid`** (Workspace Virtualization Engine):
   ```bash
   npm install -g @axiomantic/braid
   ```
4. **Redis or Valkey** (local or remote):
   ```bash
   brew install redis && brew services start redis
   ```

---

## 30-Second Quickstart

### 1. Launch Agora on Any Task
In your primary AI coding assistant (Antigravity, Claude Code, OpenCode):

```text
User: "agora: Implement high-throughput batch claim leases with Redis pipeline support"
```

### 2. Interactive Team Calibration (`choose-personas`)
Agora inspects your repository and suggests a balanced persona roster with recommended harnesses and models:
- **Marcus Vance** (Staff Systems Architect) $\to$ **OpenCode Desktop** | **Claude 3.5 Sonnet**
- **Caleb Thorne** (Refactoring & Code Quality Purist) $\to$ **Claude Code CLI** | **Claude 3 Opus**
- **Elena Rostova** (DevEx & API Lead) $\to$ **Antigravity** | **Claude 3.5 Sonnet**

Confirm or adjust the roster with a single click.

### 3. Automatic Fleet Provisioning (`launch-workers`)
Agora executes [`scripts/launch_tmux_swarm.sh`](scripts/launch_tmux_swarm.sh):
- Creates tmux session `agora-<project>` with dedicated panes for each worker.
- Sets environment variables and registers each agent via `locu open`.
- Arms background listeners (`locu listen`).
- Automatically pops open a visible **Ghostty** or **Terminal.app** window on macOS so you can watch the swarm running live.

### 4. The Dialectical Pump (`dialectical-pump`)
The personas deliberate across three empirical stages:
1. **Research**: Workers read code and run tests $\to$ synthesize `understanding.md` $\to$ verify against automated **Fact-Check Gate**.
2. **Architecture**: Triad debates trade-offs $\to$ produces ratified `design.md`.
3. **Audit**: Auditor generates `audit_report.md` $\to$ triad resolves every finding before coding begins.

### 5. Ceremonial Planning (`plan-implementation`)
Agora authors `implementation_plan.md`:
- Schedules distributed fencing locks (`locu lock file:<path> --fencing`).
- Assigns tasks and defines APFS CoW strands (`braid new <task_id> --worktree`).
- Sets up dynamic progress checkboxes and harness To-Do tracking.

### 6. Live Orchestration & Trunk Weaving (`orchestrate-swarm`)
The main chat orchestrator dispatches work over Redis. Workers code in isolated strands, run unit tests, and verify the Two-Key Gate (`braid gate`). When passed, the orchestrator executes `braid weave` to fast-forward verified code into `main` with zero merge conflicts!

---

## Core Invariants

1. **The Supreme Orchestrator Invariant**:
   The main chat session coordinates, reviews, and integrates. Intensive multi-file edits are executed by the worker fleet in isolated strands.
2. **Empirical Grounding Protocol (Zero Theatrical Dialogue)**:
   Dialectical deliberations must cite hard evidence from real tool calls (line citations, test outputs, compiler errors). Theatrical roleplay is strictly banned.
3. **Two-Key Gate Verification**:
   No code is merged into the trunk without passing both Key 1 (in-memory `git merge-tree` mechanical check) and Key 2 (live semantic compiler and test suite run).
4. **Zero Dirty Commits**:
   All agent identity files, session state, and temporary lockfiles are strictly ignored in `.gitignore`.

---

## License

MIT © Axiomantic / Agora Contributors
