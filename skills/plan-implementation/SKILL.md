---
name: plan-implementation
description: "Generates the ceremonial master implementation plan from a ratified design document. Maps exact task distributions across swarm personas, concurrency and distributed locking schedules using Rhizo monotonic fencing tokens, and workspace virtualization using Vine strands. Establishes dynamic progress tracking via markdown task checklists, synchronization with native coding harness To-Do tools, and the Emergent Design Addendum Protocol. Triggers: 'plan implementation', 'create implementation plan', 'schedule swarm work', 'build execution plan'."
---

# `plan-implementation`: Ceremonial Implementation Planning & Locking Schedules

> **Bridging the Architectural Spec to Synchronized Swarm Execution**  
> *A plan is not a wish list; it is a deterministic state machine. It dictates who works on what, what locks prevent collisions, which branches isolate code, and how progress is tracked in real time.*

---

## 1. Core Principles & Architecture

The Orchestrator authors `implementation_plan.md` adhering to four core invariants:

1. **Deterministic Assignment**: Every subtask has exactly one primary persona owner.
2. **Resource Fencing Before Mutation**: Any non-mergeable resource (e.g. database schemas, configuration files, migration scripts) must have an explicit `rhizo lock file:<path> --fencing` lease scheduled before modification begins.
3. **Workspace Isolation via Vine**: Complex, multi-file changes must occur in isolated Rift strands (`vine new <task_id>`). Strands cannot be woven until passing the Two-Key Gate (`vine gate`).
4. **Zero Silent Architectural Drift**: If an implementer encounters an unforeseen constraint during coding, it cannot unilaterally alter the architecture. It must submit a formal design addendum.

---

## 2. Structure of `implementation_plan.md`

The generated implementation plan must follow this exact template:

```markdown
# Implementation Plan: [Feature / Project Name]

## 1. Swarm Roster & Role Mapping
| Worker Name | Persona | Role | Assigned Subsystems |
| :--- | :--- | :--- | :--- |
| `architect` | Marcus Vance | Staff Systems Architect | Core data structures, API contracts |
| `auditor` | Caleb Thorne | Refactoring Purist | Unit tests, negative controls, linter |
| `implementer` | Elena Rostova | DevEx & Implementation Lead | CLI commands, adapters, docs |

---

## 2. Distributed Locking & Concurrency Schedule
Before modifying any shared or non-mergeable file, the designated worker must obtain an atomic lease:
- **Lock Target**: `file:src/config.nim`
  - *Owner*: `architect`
  - *Command*: `rhizo lock file:src/config.nim 600 --fencing`
  - *Monotonic Fencing Counter*: Record token in task execution log.
- **Lock Target**: `file:migrations/001_schema.sql`
  - *Owner*: `implementer`
  - *Command*: `rhizo lock file:migrations/001_schema.sql 300 --fencing`

---

## 3. Vine Strand Lifecycle & Verification Matrix
For all parallel development tracks:
1. **Provision Strand**:
   ```bash
   vine new <task_id> --branch strand/<task_id> --worktree
   ```
2. **Execute Work Inside Strand**:
   - Implement code changes.
   - Run local unit tests and formatters.
3. **Two-Key Gate Verification**:
   ```bash
   vine gate --json
   ```
   *Must verify exit code 0: Key 1 (in-memory merge-tree) PASS + Key 2 (compiler/test suite) PASS.*
4. **Trunk Weaving**:
   *Orchestrator fast-forwards verified branch into main:*
   ```bash
   vine weave
   ```

---

## 4. Phase-by-Phase Task Checklist

### Phase 1: Core Engine Primitives
- [ ] **Task 1.1: Core Data Structures** (`architect`)
  - *Strand*: `strand/task-core-ds`
  - *Lock*: `rhizo lock file:src/types.nim 300 --fencing`
  - *Actions*: Define AST node kinds and message serializers.
  - *Verification*: `nim c -r tests/test_types.nim`
  - *Weave*: `vine gate && vine weave && rhizo unlock file:src/types.nim`

- [ ] **Task 1.2: Test Harness & Negative Controls** (`auditor`)
  - *Strand*: `strand/task-test-harness`
  - *Actions*: Implement negative assertion tests for malformed JSON.
  - *Verification*: `pytest tests/test_harness.py`
  - *Weave*: `vine gate && vine weave`

### Phase 2: High-Level CLI & Integration
- [ ] **Task 2.1: CLI Subcommand Wiring** (`implementer`)
  - *Dependency*: Task 1.1, Task 1.2
  - *Strand*: `strand/task-cli-wiring`
  - *Actions*: Expose new subcommands in CLI parser.
  - *Verification*: `garden --help` and tripwire tests.
  - *Weave*: `vine gate && vine weave`

---

## 5. Dynamic Progress Tracking & Harness To-Do Protocol
1. **Markdown Checkboxes**:
   - As each task begins, the orchestrator updates status notes.
   - When verified woven, the orchestrator changes `- [ ]` to `- [x]`.
2. **Harness To-Do Synchronization**:
   - If the runtime harness provides native To-Do tools (e.g. `todo_write`, `manage_tasks`), the orchestrator mirrors the active phase tasks into the harness's To-Do list.
   - Mark items complete in the harness tool at the moment of `vine weave`.

---

## 6. Emergent Design Addendum Protocol
If a worker discovers that an assumption in `design.md` is flawed or impossible to implement:
1. **DO NOT silently diverge code from `design.md`**.
2. Draft an addendum document: `docs/addenda/addendum_<topic>.md`:
   - *Problem Statement*: Why the original design cannot work as specified.
   - *Proposed Deviation*: Exact technical changes.
   - *Tradeoff Analysis*: Performance, ergonomics, backwards compatibility.
3. Submit notification to Orchestrator via `rhizo send --to orchestrator --subject "Design Addendum: <topic>"`.
4. Orchestrator reviews and ratifies the addendum, updates `design.md`, updates `implementation_plan.md`, and replies with approval before implementation resumes.
```

---

## 3. Plan Review & Gate Clearance

Before handing off to [`orchestrate-swarm`](../orchestrate-swarm/SKILL.md):
1. Assert that every task names a concrete persona owner.
2. Assert that all shared files have fencing locks scheduled.
3. Assert that all tasks requiring branch isolation specify `vine new` and `vine gate`.
4. Save file to `implementation_plan.md` in the project root.
