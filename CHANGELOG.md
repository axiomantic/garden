# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.5] - 2026-10-07

### Added
- **Worker Autonomous Execution Prompt Cards (GVR-017)**:
  - Updated `generateWorkerPrompt` in `src/garden.nim` and `skills/launch-workers/SKILL.md` with the Worker Autonomous Execution Invariant: workers must never remain passive chatbots upon receiving a task, but immediately claim, execute in an isolated Vine strand, verify the Two-Key Gate, and re-arm listeners.
  - Added auto-installation instructions for native Codex turn-end lifecycle hooks (`rhizo hook install --codex`).
- **4-Step Scheduled Watchdog & Health Check Protocol (GVR-017)**:
  - Upgraded scheduled listener health check prompt template to mandate:
    1. Inspecting completed background subagent tasks first to extract and act upon any delivered task payloads sitting unprocessed in task logs.
    2. Inspecting active harness tasks to ensure a single-shot `rhizo listen` is running; rearming if absent.
    3. Probing Redis listener and inbox state via `rhizo probe` and draining backlog.
    4. Staying quiet only when an active listener is running AND zero unprocessed task outputs exist.
- **Codex Turn-End Hook Auto-Scaffolding**:
  - `garden init` now automatically scaffolds `.codex/hooks.json` with the `Stop` event interlock.
- **Garden Coordination Guide v1.6**:
  - Codified the Worker Autonomous Execution Invariant in Section 2 of `src/guide.nim` and synchronized `AGENTS.md` across repositories.

## [0.2.4] - 2026-10-07

### Added
- **Watchdog Stepped Backoff & 4-Strike Cap Protocol (GVR-015)**:
  - Documented stepped backoff schedule (Base 15m $\rightarrow$ 30m $\rightarrow$ 60m $\rightarrow$ 120m $\rightarrow$ Stand Down) and 4-strike cap in `garden` and `orchestrate-swarm` skills.
  - Codified stand-down invariant: after 4 quiescent checks where the listener remains continuously healthy and zero tasks arrive, the orchestrator stands down without scheduling further timers while remaining reactive on Redis `BRPOP`.
  - Enforced immediate streak and cadence reset upon activity, unread inbox messages, or listener rearming.
- **Orchestrator Intake Gate & Non-Implementation Invariant (GVR-016)**:
  - Codified the mandatory intake gate in `orchestrate-swarm` and `garden` skills: when presented with a task, the Lead Orchestrator must prompt via `ask_question` with options to enqueue to cluster queue, dispatch to worker, or run inline.
  - Upgraded Garden Coordination Guide to `[v1.5]` with Orchestrator Non-Implementation Invariant in `src/guide.nim` and `AGENTS.md` across repositories.
  - Updated `SWARM_RUNTIME_STATE` template to explicitly encode `AGENT_ROLE: Lead Orchestrator (NON-IMPLEMENTING CONDUCTOR)` and `INTAKE_GATE: MANDATORY_ASK`.

## [0.2.3] - 2026-10-07

### Added
- **Delegation Precedence Invariant**:
  - Codified cluster worker priority in Section 3 and `orchestrate-swarm`: orchestrators must dispatch work to active workers via Rhizo rather than spawning harness-internal subagents unless explicitly requested by name.
- **Post-Compaction Ceremony Restoration Invariant (GVR-010)**:
  - Codified mandatory post-compaction ceremony restoration instruction requiring resurrected agents to re-read coordination skills (`garden`, `orchestrate-swarm`, `rhizo`, `vine`) before running tools.
- **Garden Coordination Guide v1.4**:
  - Upgraded canonical guide in `src/guide.nim` and `AGENTS.md` across repositories to include delegation precedence (v1.3) and post-compaction restoration (v1.4).

## [0.2.2] - 2026-10-06

### Added
- **Phase 0 Interactive Intake Interview**: Codified the 4-question interactive interview (`ask_question`) into Garden's entrypoint, allowing operators to calibrate team topology (Triad vs Duo vs Custom), coding harnesses, and model pairings/fallbacks without guessing.
- **Numbered Operator Setup Guidance**: Formatted prompt generator output with explicit, numbered terminal tab instructions (Tab 1, Tab 2, Tab 3) and reiterated harness-agnostic flexibility.
- **Automatic Multi-Agent Activation in Develop**: Updated `/develop` gate in ISO standard plain English to offer "Coordinated Multi-Agent Team (Garden + Rhizo + Vine)" on any code development request, detailing what it is, what it means, and what it entails.
- **Garden Coordination Guide v1.2**: Updated the canonical guide in `src/guide.nim` and `AGENTS.md` across projects to reflect the intake interview and prompt-bootstrapped sessions.

### Changed
- **Lead Orchestrator Terminology**: Replaced all occurrences of "Supreme Orchestrator" with "Lead Orchestrator" across all guides, READMEs, and skills for professional, ISO standard plain English alignment.
- **Skill Instruction Cleanliness**: Removed human-facing quickstart callouts from skill files to optimize LLM prompt contexts, preserving them exclusively in project READMEs.

## [0.2.1] - 2026-10-06

### Added
- **Environment Variable Overrides & Precedence**:
  - Added support for `GARDEN_SWARM_FILE` to override local `garden-swarm.json` discovery.
  - Added support for `GARDEN_CONFIG` to specify custom paths to `garden.toml`.
  - Added support for `GARDEN_PROJECT_DIR` to override git/root project directory resolution.
  - Added support for `GARDEN_TERMINAL_APP` to specify the default terminal application viewer.
- **Comprehensive Configuration & Manifest Documentation**:
  - Authored `docs/configuration.md`: Comprehensive reference table for all `GARDEN_*` environment variables, `garden.toml` schema, and `garden-swarm.json` full JSON Schema specification with WorkerSpec details.
- **Enhanced Test Coverage**:
  - Added test in `tests/test_garden.nim` verifying `GARDEN_SWARM_FILE` and `GARDEN_PROJECT_DIR` environment variable overrides during prompt generation.

## [0.2.0] - 2026-10-06

### Added
- **Prompt-Based Swarm Bootstrapping Mode**: Replaced automated tmux session and pane spawning with human-in-the-loop prompt generation (`garden prompts` / `garden launch`).
- **10-Backtick Raw Markdown Block Fencing**: All emitted prompt cards are wrapped in exactly 10 backticks, ensuring that nested markdown formatting and bash code fences remain unrendered raw text inside preformatted copy blocks.
- **Self-Contained Worker Prompt Cards**: Generated prompt cards provide complete session onboarding: codename identity, persona name, role, opposing cognitive priorities, target repo navigation, `RHIZO_AGENT_NAME` environment setup, `rhizo open` registration, single-shot listener discipline (`rhizo listen`), task queue claiming, fencing mutex locks, Vine strand isolation, Two-Key gate verification (`vine gate`), and context compaction state riders (`SWARM_RUNTIME_STATE`).
- **Garden Coordination Guide v1.1**: Upgraded the canonical guide in `src/guide.nim` and `AGENTS.md` to formalize interactive session coordination and single-shot listener discipline over tmux process multiplexing.
- **CLI Subcommand `prompts`**: Introduced `garden prompts` with `--worker <name>`, `--write [file]`, and `--json` options for flexible prompt inspection, file persistence, and programmatic consumption.

### Changed
- **Default `garden launch` Behavior**: `garden launch` now defaults to spitting out 10-backtick-fenced worker prompt cards for direct clipboard copying into new sessions (Claude Code, OpenCode, Antigravity, Pi, Cursor), with `--tmux` preserved as an optional legacy fallback.
- **Skill Harmonization**: Updated `launch-workers`, `garden`, and `orchestrate-swarm` across repository and global configuration directories to reflect prompt-based session coordination, `rhizo probe` diagnostics, and `garden teardown`.

## [0.1.6] - 2026-09-30

### Fixed
- **Cross-Platform Test Execution**: Resolved binary executable naming conventions (`ExeExt`) across Windows, macOS, and Linux test runners.
- **Resilient Swarm Status**: Added robust error handling in `doStatus` to gracefully handle corrupted or empty worker metadata files.

## [0.1.5] - 2026-09-30

### Changed
- **Swarm Invariants Formalization**: Embedded strict XML invariants (`<CRITICAL>`, `<INVARIANT>`) into the coordination guide and skill documentation enforcing the Lead Orchestrator Invariant, Zero Theatrical Dialogue (requiring empirical verification via tool calls for all dialectical claims), and Multiplexer Discipline for tmux workers.
- **Rift Workspace Integration**: Aligned swarm task planning and execution workflows with Rift copy-on-write strand virtualization and Two-Key Gate verification.
- **Swarm Ceremony Streamlining**: Harmonized the 5-phase swarm ceremony across `choose-personas`, `launch-workers`, `dialectical-pump`, `plan-implementation`, and `orchestrate-swarm`.
- **Version Alignment**: Synchronized `GardenVersion = "0.1.5"` across `src/garden.nim`, `garden.nimble`, and `package.json`.

## [0.1.4] - 2026-09-29

### Added
- **Fat-Package Pre-Bundled Native Binaries**: Npm package now pre-bundles native compiled binaries for all 5 major platforms (`darwin-arm64`, `darwin-x64`, `linux-x64`, `linux-arm64`, `win32-x64.exe`) inside `bin/binaries/`.
- **Zero-Latency Offline Execution**: Invocations immediately execute the matching bundled native binary with zero network requests, zero `curl`/`powershell` execution, and complete air-gap/corporate-proxy support.
- **Supply-Chain Security Hardening**: Completely eliminated runtime unverified binary downloads, external shell executions, and supply-chain scanner red flags.

## [0.1.3] - 2026-09-29

### Added
- **Architecture-Aware Binary Bootstrapping**: `bin/run.js` verifies binary compatibility and automatically downloads pre-built binaries from GitHub Releases into `~/.cache/garden/bin/`.
- **SKILL.md Self-Bootstrapping Section 0**: Added clear instructions for agents encountering a missing `garden` CLI to run `npm install -g @axiomantic/garden`.
- **GitHub Actions CI & Release Workflows**: Added automated cross-platform builds and release workflows.

### Fixed
- **Pure Universal NPM Package**: Excluded host binaries from npm package, publishing universal runner with automatic release provisioning.
