---
name: garden
description: "Master entrypoint and end-to-end ceremony director for multi-agent swarms operating on top of Rhizo (transport) and Vine (workspace integrator). Guides the user and orchestrator session through the full lifecycle: persona selection with harness/model pairing, tmux worker fleet provisioning with live terminal viewer, 3-stage empirical dialectical pump (research, design, audit), master implementation planning with locking/strand schedules, and live swarm execution with Two-Key gate verification and fast-forward trunk weaving. Triggers: 'garden', 'run garden', 'swarm this project', 'orchestrate with garden', 'start garden swarm', 'run the full garden ceremony'."
---

# Garden: Multi-Agent Swarm Ceremony & Orchestration Engine

## 0. Prerequisite & Automatic Bootstrapping

All swarm ceremonies require `garden`, `rhizo`, `vine`, and `rift`. If missing, install globally:
```bash
npm install -g @axiomantic/rhizo @axiomantic/vine @axiomantic/garden rift-snapshot
```

> [!TIP]
> **Zero-Install Fallback (`npx`)**: In restricted environments where global installation is prohibited, prefix commands with `npx -y @axiomantic/garden <command>`.

---

## 1. Architecture & Layering

Garden directs multi-agent swarms using Rhizo for transport and Vine for workspace virtualization:

```mermaid
flowchart TD
    subgraph Garden["Garden Layer (Methodology & Ceremonies)"]
        Phase1["Phase 1: choose-personas (Team Selection & Models)"]
        Phase2["Phase 2: launch-workers (tmux & Terminal Viewer)"]
        Phase3["Phase 3: dialectical-pump (Research ➔ Design ➔ Audit)"]
        Phase4["Phase 4: plan-implementation (Locking & Strands)"]
        Phase5["Phase 5: orchestrate-swarm (Dispatch & Vine Weaving)"]
    end

    subgraph Infrastructure["Coordination Infrastructure"]
        Rhizo["Rhizo (Redis Bus, Fencing Mutexes, Work Queues)"]
        Vine["Vine (Rift Strands, Two-Key Gate, Weaving)"]
    end

    Phase1 --> Phase2 --> Phase3 --> Phase4 --> Phase5
    Phase2 -.-> Rhizo
    Phase3 -.-> Rhizo
    Phase4 -.-> Rhizo & Vine
    Phase5 -.-> Rhizo & Vine
```

---

## 2. The 5-Phase End-to-End Ceremony

Execute all five phases sequentially. Never skip phases or invert the order.

| Phase | Sub-Skill | Action | Quality Gate to Proceed |
| :--- | :--- | :--- | :--- |
| **Phase 1** | [`choose-personas`](../choose-personas/SKILL.md) | Formulate 3 balanced personas with harness/model pairings. | Operator ratifies `garden-swarm.json`. |
| **Phase 2** | [`launch-workers`](../launch-workers/SKILL.md) | Provision tmux session, register agents, launch viewer. | `rhizo who --json` confirms 100% of workers active. |
| **Phase 3** | [`dialectical-pump`](../dialectical-pump/SKILL.md) | Grounded triadic deliberation: research, design, adversarial audit. | Zero open `CRIT` or `BLOCKER` defects in `audit_report.md`. |
| **Phase 4** | [`plan-implementation`](../plan-implementation/SKILL.md) | Author master implementation plan with locking schedules and strands. | Complete `implementation_plan.md` with task-locking matrix. |
| **Phase 5** | [`orchestrate-swarm`](../orchestrate-swarm/SKILL.md) | Main-chat governor: task dispatch, heartbeat monitoring, trunk weaving. | All plan tasks woven via `vine weave` after passing Two-Key Gate. |

---

## 3. Core Operational Invariants

<CRITICAL>
The primary conversation session acts as the Supreme Orchestrator. The orchestrator directs, reviews, and weaves; it never performs large multi-file implementation edits directly when a worker fleet is active.
</CRITICAL>

<INVARIANT>
Zero Theatrical Dialogue: Every dialectical assertion must be substantiated with empirical evidence obtained through tool calls (file reading, test executions, benchmarks, or AST inspections). Theoretical roleplay without evidence is rejected.
</INVARIANT>

<INVARIANT>
Never merge code into the canonical trunk without a verified Two-Key Gate pass ('vine gate' exit code 0) inside an isolated Rift strand.
</INVARIANT>

<FORBIDDEN>
Never stage coordination metadata (*.lock, .rhizo.*, .vine.json, workspaces/) into Git. Keep all agent state ignored.
</FORBIDDEN>
