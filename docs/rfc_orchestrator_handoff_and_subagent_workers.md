# RFC: Orchestrator Handoff and Subagent Workers

Status: PARTIALLY IMPLEMENTED (Part B: Work Items 8–10 implemented; Part A: Orchestrator Handoff Work Items 1–7, 11 proposed).

Scope: `garden` (owner), `rhizo` (new primitives), `vine` (documentation and one flag).

## 1. Goals

1. **Handoff.** An orchestrator transfers its role to a new session that has an empty context. No worker message is lost. The project always has one leader.
2. **Subagent workers.** The operator can select an execution mode in which the orchestrator starts a harness-internal subagent for each task. Each subagent obeys the full worker procedure: Rhizo identity, task claim, lock, strand, gate, submit, audit, acknowledge.

The two features depend on each other. Subagent results return into the orchestrator context, so that context fills faster. The handoff is the recovery path.

## 2. Measured Baseline

Each row was read from source on 2026-11-13. `R` is `rhizo/src/rhizo.nim`.

| Fact | Location |
|---|---|
| Garden has no `handoff`, `checkpoint`, or `resume` subcommand. | `garden/src/garden.nim:2154-2711` |
| Garden generates prompt cards for workers only. No orchestrator card generator exists. | `garden/src/garden.nim:699-930` |
| Garden reads `rhizo leader status`. It does not acquire the lease. | `garden/src/garden.nim:299-349` |
| The orchestrator `SWARM_RUNTIME_STATE` block exists in skill text only. No code writes it. | `garden/skills/orchestrate-swarm/SKILL.md:103-114` |
| `rhizo leader` has the actions `acquire`, `renew`, `resign`, `status`. There is no transfer. | `rhizo/scripts/leader.lua:26-142` |
| The leader lease default is 30 seconds. The help text says 7200. | `R:10523`, `R:7836` |
| `--to @orchestrator` resolves to the lease holder when the message is sent. | `R:1560-1625` |
| A direct send stores the message in `inbox:<name>` for 7 days, whether or not the recipient is alive. | `rhizo/scripts/send_o2o.lua:135-137` |
| `rhizo close` deletes `inbox:<name>`. It does not resign the leader lease. | `rhizo/scripts/unregister.lua:19-31` |
| Tag multicast reaches only agents that are alive when the message is sent. | `rhizo/scripts/multicast.lua:126-142` |
| The blackboard script supports an expected revision (OCC). The CLI does not pass it. | `rhizo/scripts/blackboard.lua:27-41`, `R:4689` |
| `task complete` by a non-owner is permitted only if the caller name contains `orchestrator`. | `rhizo/scripts/task.lua:274-278` |
| The audit ticket hash is recorded when a `STRAND_SUBMITTED` message is taken from an inbox. The key includes the name of the agent that took it. | `R:2404-2446` |
| Vine keeps strand state in Redis. A strand records `author`, `orchestrator`, and `created_by`. | `vine/src/strand.nim:215-259`, `vine/scripts/strand.lua:97-99` |
| Vine sends notifications to the recorded orchestrator if it is active. If not, it sends them to the elected leader. | `vine/src/notify.nim:237-257` |
| Vine rejects an audit when the auditor name equals the author name. The comparison is a string comparison. | `vine/src/gate.nim:1102-1110` |
| Vine does not examine who runs `vine weave`. | `vine/src/weave.nim:221-226` |
| The subagent prohibition is text only. No code and no test enforces it. | `garden/src/guide.nim:61-74`, `rhizo/src/guide.nim:55-97`, `vine/src/guide.nim:28-29` |
| Rhizo starts or injects into a session only for Antigravity (router) and for terminal windows (`poke`). It cannot start a Claude Code session. | `R:9384-9385`, `R:3022-3173`, `R:6349-6420` |

## 3. Part A: Orchestrator Handoff

### 3.1 Problems the handoff must solve

| # | Problem | Cause |
|---|---|---|
| A1 | Leader vacancy | `resign` then `acquire` leaves a period with no leader. `@orchestrator` sends fail or go to a tag holder. |
| A2 | Lost messages | Worker reports stay in `inbox:<old>`. `rhizo close` deletes them. |
| A3 | Wrong reply address | Worker cards contain the sovereign name of the orchestrator. |
| A4 | State written by hand | A snapshot that the model writes can be incomplete or wrong. Most of the state is in Redis already. |
| A5 | Successor start | Garden cannot make an orchestrator card or start a session. |
| A6 | Abandoned handoff | If the successor does not start, the project must not lose its leader. |

### 3.2 Protocol

The handoff has two phases. The outgoing orchestrator stays leader until the successor accepts.

```
OUTGOING                         REDIS                          SUCCESSOR
garden handoff prepare
  derive snapshot      ───────►  blackboard garden:<project>
  write intent note    ───────►    handoff:current
  reserve successor name ─────►  held_name:<successor>
  write orchestrator card (file)
  start session if the harness can
                                                                 rhizo open <successor>
                                                                 garden handoff accept
                                 leader transfer (atomic)  ◄────
                                 inbox move old → new      ◄────
                                 ORCHESTRATOR_CHANGED      ◄────  to project workers
garden handoff status
  sees ACCEPTED
rhizo close <old>
```

**Phase 1, `garden handoff prepare [--notes @file] [--successor <name>]`** (outgoing session):

1. Make sure that the caller holds `leader:orchestrator:<project>`. If not, stop with an error.
2. Derive the snapshot in code:
   - roster: `rhizo who --all --json`, filtered to the project and the unassigned pool;
   - strands: `vine list --json` and `vine collisions --json`;
   - tasks: all WISM tasks of the project that are not in a terminal state;
   - git: the commit of the canonical branch, and the commits of `design.md` and `implementation_plan.md`;
   - unread mail: the count of `inbox:<old>`.
3. Add the intent note. This is the only part that the model writes. It contains decisions, operator preferences, and the next actions. Garden rejects a note that is empty.
4. Write the result to the blackboard room `garden:<project>`, key `handoff:current`, with state `PREPARED` and the expected revision.
5. Reserve the successor name. Use `rhizo name` with a hold time that is long enough for a manual start.
6. Generate the orchestrator bootstrap card and write it to `/tmp/garden-<project>/orchestrator-<successor>.md`.
7. If the harness can start or inject into a session, do it. If not, print the path of the card.
8. Set `rhizo status busy "handoff prepared, waiting for <successor>"`. Dispatch no new tasks.

**Phase 2, `garden handoff accept`** (successor session):

1. Make sure that `handoff:current` has state `PREPARED` and that the caller is the reserved successor.
2. Call `rhizo leader transfer orchestrator:<project> --from <old> --to <new>`.
3. Call `rhizo inbox move <old> <new>`.
4. Send `ORCHESTRATOR_CHANGED` directly to each project worker in the roster. A direct send is durable. A tag multicast is not.
5. Set `handoff:current` to `ACCEPTED`.
6. Print the snapshot and the intent note. The successor continues from the next actions.

**Completion** (outgoing session): `garden handoff status` shows `ACCEPTED`. The outgoing session then runs `rhizo close <old>`. Its inbox is empty at this time.

**Abort.** `garden handoff abort` sets the state to `ABORTED` and releases the name hold. The outgoing session stays leader. A handoff that is `PREPARED` for longer than its hold time is aborted automatically on the next `prepare` or `status`.

### 3.3 New Rhizo primitives

| Primitive | Behaviour |
|---|---|
| `rhizo leader transfer <role> --from <a> --to <b> [--lease s]` | One Lua script. It fails if the holder is not `<a>`. It sets the holder to `<b>` with a new lease and publishes on `channel:leader:<role>`. No vacancy occurs. |
| `rhizo inbox move <old> <new>` | One Lua script. It moves all messages from `inbox:<old>` to `inbox:<new>` in the initial order and refreshes the expiry. |
| `rhizo blackboard set ... --expect-rev <n>` | Passes the expected revision to the script. Two sessions cannot both write `handoff:current`. |
| `rhizo leader acquire` default lease | One value in code and help text. The orchestrator must renew the lease. Garden does this on each `garden` command that the orchestrator runs. |

Garden must also acquire the lease when a session becomes orchestrator. Today that step is skill text.

### 3.4 Reply address

Worker cards and `SWARM_RUNTIME_STATE` will say `ORCHESTRATOR: @orchestrator`, not a sovereign name. The address then follows the lease. `ORCHESTRATOR_CHANGED` is still sent, because a worker can hold the old name in its context.

### 3.5 Successor start

| Harness | Method |
|---|---|
| Antigravity | The Rhizo router injects the card into a new conversation. |
| Terminal harnesses with a window that `poke` can find | `poke` types the bootstrap command. |
| All others, including the Claude desktop application | Garden prints the card path. The operator pastes the card into a new session. |

The card is always written, so the manual method always works.

### 3.6 Name-coupled behaviour

`task complete` examines the caller name for the text `orchestrator`. That is a guess from a name. The handoff replaces it with a check against the lease holder of `orchestrator:<project>`.

### 3.7 Handoff when subagents are active

A subagent stops when its parent session stops. `garden handoff prepare` lists the tasks that have a live subagent. The outgoing orchestrator waits for them, or it records them in the snapshot as `ORPHANED`. The successor dispatches an `ORPHANED` task again into the same strand. Strand state and task state are in Redis, so no work on disk is lost.

## 4. Part B: Capability-Aware Subagent & Tmux Workers

### 4.1 Operator Selection & Capability-Aware Harness Defaults

The cold-start intake and `garden.toml` `[swarm].execution_mode` support `"auto"` (default) as well as explicit overrides:

| Harness | Can Drill Into & Chat? | Default (`execution_mode = "auto"`) | Secondary / Opt-In |
| :--- | :---: | :--- | :--- |
| **Antigravity IDE** | **Yes** (`conversation://<id>` & Swarm UI) | `subagents` (`invoke_subagent` + `send_message` + clickable `conversation://` pills) | `prompts` (top-level Rhizo windows) |
| **OpenCode Desktop** | **Yes** (Sidebar child session tree) | `subagents` (persistent child sessions) | `prompts` (top-level Rhizo windows) |
| **OpenCode CLI (TUI)** | **Partial** (Keybind session cycling) | `subagents` | `tmux` / `prompts` |
| **Codex Desktop** | **No** (Top-level threads) | `prompts` (10-backtick Prompt Cards + existing Rhizo pool) | — |
| **Codex CLI (Text)** | **No** | `tmux` (when `tmux` is available) -> else `prompts` | `prompts` |
| **Claude Code CLI / Generic** | **No** (`Task` is opaque) | `tmux` (when in `$TMUX` / `--tmux`) -> else `prompts` | `prompts` |

The selection is stored in `garden.toml` as `execution_mode` (`"auto"`, `"subagents"`, `"tmux"`, or `"prompts"`), not text in a skill only.

### 4.2 Procedure

A subagent obeys the same procedure as a top-level worker. The source of the procedure is `generateSubagentBrief` alongside `generateWorkerPrompt` in `garden`.

`garden prompts --subagent --role <role> --task <task_id>` emits a task brief and writes `/tmp/garden-<project>/subagent-<worker>.md`. The brief contains:

1. `rhizo name` and `rhizo open <name>`. The name is given on each subsequent command as `--agent`, because a subagent shell does not keep environment variables between commands.
2. `rhizo task claim <task_id> --lease <s>` and `rhizo lock <resource> --fencing`.
3. `vine new <task_id> --worker <name>`, the work, `vine changelog`, `vine gate`, `vine submit`.
4. A `STRAND_SUBMITTED` message to `@orchestrator`.
5. `rhizo ack`, lock release, `rhizo close <name>`.
6. A return envelope with a fixed shape: status, strand, gate result, files changed, items not verified.

The brief does not contain a listener step. The orchestrator starts the subagent directly, and the result returns as the tool result.

### 4.3 Audit

Key 3 stays independent:

1. The orchestrator starts a second subagent with the audit profile and a different name.
2. The orchestrator sends the `STRAND_SUBMITTED` message to that name.
3. The auditor takes the message with a synchronous `rhizo drain`. This records the audit ticket hash for that auditor name.
4. The auditor runs `vine audit inspect`, then `vine audit approve --ticket ...` or `vine audit reject`.
5. The orchestrator runs `vine weave`.

Vine rejects an audit when the auditor name equals the author name. The orchestrator must never start one subagent for both roles.

### 4.4 Reuse

The default is a new subagent for each task. The orchestrator can continue an existing subagent when the next task uses the same strand or the same files, for example a fix after an audit rejection. A continued subagent keeps its Rhizo name.

### 4.5 Limits

| Limit | Mitigation |
|---|---|
| The subagent stops with the orchestrator session. | Section 3.7. |
| Each result adds to the orchestrator context. | The fixed return envelope. Handoff when the context is near its limit. |
| A subagent cannot start more subagents. | The orchestrator starts the implementer and the auditor. |
| Names of stopped subagents can stay in the roster after a crash. | `rhizo sweep` removes them. The successor orchestrator runs it during `accept`. |
| The harness must have a subagent tool. | Garden offers the mode only for a harness that has one. |

### 4.6 Text that must change

The prohibition changes from "subagents are never workers" to "subagents are workers only in Subagent Fleet mode, and they obey the full worker procedure".

| Repository | Locations |
|---|---|
| garden | `src/guide.nim:61-74` (guide version changes, `tests/test_garden.nim:80-81`), `src/garden.nim:707`, `skills/orchestrate-swarm/SKILL.md:29-30`, `skills/launch-workers/SKILL.md:40-43`, `skills/choose-personas/SKILL.md:57-59` and `133-137`, `SKILL.md` and `skills/garden/SKILL.md` at `192-204`, `371`, `375`, `README.md:176-180`, `docs/ceremony_lifecycle.md:41-49`, `AGENTS.md:435-436` |
| rhizo | `src/guide.nim:55-97`, `SKILL.md:91,118` |
| vine | `src/guide.nim:28-29`, `SKILL.md:57` |
| spellbook | `rules/20-orchestration.md`, skill `dispatching-parallel-agents` |

The guide blocks in each `AGENTS.md` are generated. `guide install` updates them after the templates change.

## 5. Work Items

| # | Repository | Item | Depends on |
|---|---|---|---|
| 1 | rhizo | `leader transfer`, one lease default, lease renewal | none |
| 2 | rhizo | `inbox move` | none |
| 3 | rhizo | `blackboard set --expect-rev` | none |
| 4 | rhizo | `task complete` checks the lease holder | 1 |
| 5 | garden | Acquire and renew the leader lease | 1 |
| 6 | garden | `handoff prepare`, `accept`, `status`, `abort`, and the orchestrator card | 1, 2, 3, 5 |
| 7 | garden | Skill `garden-handoff` that calls the commands | 6 |
| 8 | garden | `execution_mode` in `garden.toml` and the intake option | none |
| 9 | garden | `prompts --subagent` and the audit dispatch procedure | 8 |
| 10 | all | Guide and skill text for Subagent Fleet mode | 9 |
| 11 | garden | Handoff with active subagents (`ORPHANED` tasks) | 6, 9 |

Rhizo items 1 to 4 must be released before Garden item 6 can use them.

## 6. Open Questions

1. Hold time for the successor name. `rhizo name` holds a name for 600 seconds by default. A manual paste can take longer.
2. Should the orchestrator start a handoff automatically at a context threshold, or only on an operator command?
3. Maximum number of subagents that run at the same time. Each one has a strand and a lock.
