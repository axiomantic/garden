# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-09-29

### Added
- **Architecture-Aware Binary Bootstrapping**: `bin/run.js` verifies binary compatibility and automatically downloads pre-built binaries from GitHub Releases into `~/.cache/garden/bin/`.
- **SKILL.md Self-Bootstrapping Section 0**: Added clear instructions for agents encountering a missing `garden` CLI to run `npm install -g @axiomantic/garden`.
- **GitHub Actions CI & Release Workflows**: Added automated cross-platform builds and release workflows.

### Fixed
- **Pure Universal NPM Package**: Excluded host binaries from npm package, publishing universal runner with automatic release provisioning.
