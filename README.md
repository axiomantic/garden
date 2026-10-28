# Garden

[![CI](https://github.com/axiomantic/garden/actions/workflows/ci.yml/badge.svg)](https://github.com/axiomantic/garden/actions/workflows/ci.yml)

[![Release](https://img.shields.io/github/v/release/axiomantic/garden)](https://github.com/axiomantic/garden/releases/latest)
[![License](https://img.shields.io/github/license/axiomantic/garden)](LICENSE)
[![Nim](https://img.shields.io/badge/Nim-2.2%2B-yellow.svg)](https://nim-lang.org)

Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies on top of Rhizo & Vine

## Quick Start

```nim
import garden

echo hello()
```

## Development

The `justfile` is the canonical command surface for common tasks:

```bash
just setup        # Install dependencies
just test         # Run test suite
just lint         # Check formatting (nph) and nimble check
just fmt          # Auto-format codebase with nph

just build        # Build release artifacts
```

## Upstream Updates

This project was initialized via [Polyform](https://github.com/axiomantic/polyform). To update boilerplate, CI workflows, and tooling from upstream:

```bash
uvx copier update --trust
```
