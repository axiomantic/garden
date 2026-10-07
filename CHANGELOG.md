# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
