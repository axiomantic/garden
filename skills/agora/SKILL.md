---
name: agora
description: "Master entrypoint and end-to-end ceremony director for multi-agent swarms operating on top of Locu (transport) and Braid (workspace integrator). Guides the user and orchestrator session through the full lifecycle: persona selection with harness/model pairing, tmux worker fleet provisioning with live terminal viewer, 3-stage empirical dialectical pump (research, design, audit), master implementation planning with locking/strand schedules, and live swarm execution with Two-Key gate verification and fast-forward trunk weaving. Triggers: 'agora', 'run agora', 'swarm this project', 'orchestrate with agora', 'start agora swarm', 'run the full agora ceremony'."
---

# Agora: Multi-Agent Swarm Ceremony & Orchestration Engine

> **The Sovereign Orchestration Layer for Autonomous AI Swarms**  
> *Where `locu` is the transport nervous system and `braid` is the workspace integrator, `agora` is the institutional intellect, deliberation crucible, and master ceremony conductor.*

---

## 1. Architectural Architecture & Layering

Agora coordinates teams of heterogeneous AI coding assistants across terminals and machines:

```mermaid
flowchart TD
    subgraph Agora["Agora Layer (Methodology & Ceremonies)"]
        Phase1["Phase 1: choose-personas (Team Selection & Models)"]
        Phase2["Phase 2: launch-workers (tmux & Terminal Viewer)"]
        Phase3["Phase 3: dialectical-pump (Research ➔ Design ➔ Audit)"]
        Phase4["Phase 4: plan-implementation (Locking & Strands)"]
        Phase5["Phase 5: orchestrate-swarm (Dispatch & Braid Weaving)"]
    end

    subgraph Infrastructure["Coordination Infrastructure"]
        Locu["Locu (Redis Bus, Fencing Mutexes, Work Queues)"]
        Braid["Braid (APFS CoW Strands, Two-Key Gate, Weaving)"]
    end

    Phase1 --> Phase2 --> Phase3 --> Phase4 --> Phase5
    Phase2 -.-> Locu
    Phase3 -.-> Locu
    Phase4 -.-> Locu & Braid
    Phase5 -.-> Locu & Braid
```

---

## 2. The 5-Phase End-to-End Ceremony

When invoked, the Orchestrator (the primary conversation chat) executes these five phases sequentially. Never skip phases or invert the order.

```mermaid
sequenceDiagram
    autonumber
    actor User as Human Operator
    participant Orch as Main Chat (Orchestrator)
    participant Swarm as Tmux Worker Swarm
    participant Bus as Locu (Redis)
    participant Gate as Braid (Strands & Gate)

    User->>Orch: "agora: implement feature X"
    Note over Orch: Phase 1: Team Calibration
    Orch->>User: Suggests Persona Roster (Roles, Harnesses, Models) via ask_question
    User-->>Orch: Ratifies / Adjusts Roster

    Note over Orch: Phase 2: Fleet Provisioning
    Orch->>Swarm: Executes launch-workers (tmux panes + Ghostty/Terminal viewer)
    Swarm->>Bus: locu open + locu listen (Workers armed)

    Note over Orch: Phase 3: Empirical Dialectic
    Orch->>Swarm: Dispatches dialectical-pump
    Note over Swarm: 1. Research ➔ understanding.md ➔ Fact-Check Gate<br/>2. Architecture ➔ design.md<br/>3. Adversarial Audit ➔ audit_report.md ➔ Remediation
    Swarm-->>Orch: Ratified design.md & cleared audit report

    Note over Orch: Phase 4: Master Planning
    Orch->>Orch: Authors implementation_plan.md (Locks, Strands, To-Do list)

    Note over Orch: Phase 5: Swarm Execution & Weaving
    loop For Each Plan Task
        Orch->>Bus: Dispatch task (locu send / enqueue)
        Bus->>Swarm: Worker claims lease (locu claim)
        Swarm->>Gate: Creates strand (braid new)
        Swarm->>Swarm: Implements code + verifies tests
        Swarm->>Gate: Verifies Two-Key Gate (braid gate)
        Swarm->>Orch: Reports gate pass (locu reply)
        Orch->>Gate: Fast-forward merge (braid weave)
        Orch->>Orch: Updates plan checkbox & Harness To-Do
    end
    Orch->>User: Mission Accomplished Summary
```

---

## 3. Phase Transition Protocols & Quality Gates

### Gate 1 $\to$ 2: Persona Ratification Gate
- **Condition**: Operator has confirmed the roster via `ask_question`.
- **Artifact**: `agora-swarm.json` persisted in the project directory.
- **Action**: Call `launch-workers`.

### Gate 2 $\to$ 3: Cluster Readiness Gate
- **Condition**: All worker panes booted, heartbeats active in Redis.
- **Verification**: `locu who --json` confirms 100% of agents online and tagged.
- **Action**: Call `dialectical-pump`.

### Gate 3 $\to$ 4: Design Audit Clearance Gate
- **Condition**:
  1. `understanding.md` passed the Fact-Check Gate (zero ungrounded claims).
  2. `design.md` authored and debated by the triadic pump.
  3. `audit_report.md` contains 0 open `CRIT` or `BLOCKER` defects.
- **Action**: Call `plan-implementation`.

### Gate 4 $\to$ 5: Plan Alignment Gate
- **Condition**: `implementation_plan.md` complete with task matrix, locking schedule, braid strand lifecycles, and emergent design addendum protocol.
- **Action**: Call `orchestrate-swarm`.

---

## 4. Sub-Skill Reference Map

When executing Agora, invoke the sub-skills at their designated phases:

| Phase | Skill Name | Description | Primary Artifacts |
| :--- | :--- | :--- | :--- |
| **Phase 1** | [`choose-personas`](../choose-personas/SKILL.md) | Analyzes task, formulates 3 balanced personas with suggested **coding harness** and **model**, and confirms with operator. | `agora-swarm.json` |
| **Phase 2** | [`launch-workers`](../launch-workers/SKILL.md) | Provisions tmux session with worker panes, registers `locu open`, arms listeners, and launches OS terminal viewer (Ghostty / Terminal.app). | Live tmux session, visible terminal |
| **Phase 3** | [`dialectical-pump`](../dialectical-pump/SKILL.md) | Drives empirical multi-persona debate grounded in tool calls (file reading, test running, AST inspecting). Produces research, design, and audit docs. | `understanding.md`, `design.md`, `audit_report.md` |
| **Phase 4** | [`plan-implementation`](../plan-implementation/SKILL.md) | Authors master implementation plan detailing task assignments, `locu` locks (`--fencing`), `braid` strands, dynamic checkboxes, and To-Do tracking. | `implementation_plan.md` |
| **Phase 5** | [`orchestrate-swarm`](../orchestrate-swarm/SKILL.md) | Main-chat governor: dispatches tasks over Redis, tracks heartbeats, approves emergent design addenda, and executes `braid weave` upon Two-Key gate pass. | Completed code, woven trunk, git commits |

---

## 5. Invariants & Rules of Engagement

1. **The Supreme Orchestrator Invariant**:
   The primary conversation session acts as the Supreme Orchestrator. It coordinates, plans, reviews, and merges. It delegates intensive multi-file edits to the worker fleet.
2. **Zero Theatrical Dialogue**:
   In dialectical deliberations, every assertion must be backed by empirical evidence (line citations, test execution outputs, compiler errors).
3. **No Unmanaged Daemons / Zero Dirty Commits**:
   All coordination metadata (`.locutus.*`, `.braid.*`, `*.lock`) must remain in `.gitignore`. Workers must adhere to the Two-Key Gate before any code touches the canonical trunk.
