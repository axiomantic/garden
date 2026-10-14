# Garden CLI Reference Manual

> **Complete Command-Line Interface Specification**  
> *A comprehensive reference for all commands, subcommands, flags, and options supported by the Garden CLI.*

---

## 1. Global Options

All `garden` commands accept the following global flags:

| Flag | Default | Description |
| :--- | :--- | :--- |
| `-c, --config <path>` | `garden.toml` | Path to project configuration file. |
| `--manifest <path>` | `garden-swarm.json` | Path to swarm manifest file. |
| `--json` | `false` | Emits output in machine-parseable JSON format. |
| `-v, --verbose` | `false` | Emits detailed diagnostic logs to stderr. |

---

## 2. Command Catalog

### `garden init`
Initializes a repository for Garden swarm coordination.
```bash
garden init [--harness <harness>] [--shape <shape>]
```
- Scaffolds canonical `garden.toml` and baseline `garden-swarm.json`.
- Installs the coordination guide blocks (`RHIZO GUIDE`, `VINE GUIDE`, `GARDEN GUIDE`) into `AGENTS.md`.
- Ensures `.gitignore_global` ignores ephemeral coordination metadata.

### `garden prompts`
Generates copy-pasteable bootstrap prompt cards for worker fleet sessions.
```bash
garden prompts [--output <dir>]
```
- Reads `garden-swarm.json`.
- Outputs distinct prompt cards wrapped in **10 backticks** (` ``````````markdown `) to prevent premature rendering or truncation across coding harnesses (Claude Code, OpenCode, Antigravity, Cursor, Pi).
- Configures agent identity (`rhizo open <name>`), single-shot listener discipline (`rhizo listen <name>`), and isolated Vine strand directories.

### `garden launch`
Validates cluster health and initiates Lead Orchestrator supervision.
```bash
garden launch
```
- Inspects Redis connectivity and agent registry (`rhizo who --json`).
- Verifies that 100% of defined swarm workers are online and listening.
- Registers orchestrator presence on Rhizo bus.

### `garden status`
Displays the real-time status of the swarm, active personas, task queues, and Two-Key gates.
```bash
garden status [--json]
```
*Output includes:*
- Active worker codenames and elapsed heartbeat times.
- Current WISM task states (`QUEUED`, `CLAIMED`, `IN_PROGRESS`, `READY_TO_WEAVE`).
- Active Vine APFS strands and uncommitted commit deltas.
- Open distributed lock leases.

### `garden teardown`
Gracefully halts swarm operations and cleans up coordination state.
```bash
garden teardown [--force]
```
- Closes all worker presences (`rhizo close <worker>`).
- Releases lingering distributed mutex locks.
- Prompts to prune merged Vine workspaces (`vine prune`).

### `garden guide install`
Installs or updates the canonical `GARDEN GUIDE` block in the repository's `AGENTS.md`.
```bash
garden guide install [--file <path>]
```
- Preserves custom repository invariants outside the managed guide blocks.
- Ensures cross-harness consistency across all team members.
