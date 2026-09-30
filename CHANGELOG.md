# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.5] - 2026-09-30

### Changed
- **Swarm Invariants Formalization**: Embedded strict XML invariants (`<CRITICAL>`, `<INVARIANT>`) into the coordination guide and skill documentation enforcing the Supreme Orchestrator Invariant, Zero Theatrical Dialogue (requiring empirical verification via tool calls for all dialectical claims), and Multiplexer Discipline for tmux workers.
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
