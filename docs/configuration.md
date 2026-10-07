# Garden Configuration & Swarm Manifest Reference

Garden directs high-level methodology, persona deliberations, prompt-based worker fleet bootstrapping, and synchronized task execution on top of Rhizo (transport) and Vine (workspace integrator).

This document details all configuration options, environment variables, the `garden.toml` file schema, and the `garden-swarm.json` swarm manifest specification.

---

## 1. Environment Variables Reference

All Garden-controlled environment variables use the canonical `GARDEN_` prefix.

| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `GARDEN_SWARM_FILE` | Path | `garden-swarm.json` | Explicit path to the swarm worker manifest JSON file. Overrides local discovery. |
| `GARDEN_CONFIG` | Path | `garden.toml` | Explicit path to the project `garden.toml` configuration file. |
| `GARDEN_PROJECT_DIR`| Path | *Auto-detected* | Target project root directory. Overrides git root / working directory discovery. |
| `GARDEN_TERMINAL_APP`| String | `auto` | Preferred terminal viewer when running in tmux mode (`Ghostty`, `Terminal`, `iTerm`, `none`). |

---

## 2. Project Configuration (`garden.toml`)

`garden.toml` stores project-level settings and swarm defaults. It is generated via `garden init`.

### Structure

```toml
# garden.toml - Garden Swarm & Project Configuration

[project]
# Canonical project identifier
name = "locutus"

# Preferred terminal application for session viewing (Ghostty | Terminal | iTerm | none)
preferred_terminal = "Ghostty"

[swarm]
# Prefix applied to swarm session names and logging streams
session_prefix = "garden"

# Default triad of agent personas scaffolded when creating new swarms
default_triad = ["architect", "auditor", "implementer"]
```

---

## 3. Swarm Worker Manifest (`garden-swarm.json`)

The `garden-swarm.json` manifest defines the multi-agent fleet: worker personas, roles, coding harnesses, foundation models, multicast tags, and dialectical opposing priorities.

### JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "GardenSwarmManifest",
  "type": "object",
  "required": ["project", "workers"],
  "properties": {
    "project": {
      "type": "string",
      "description": "Project identifier matching Rhizo and Vine workspaces"
    },
    "target_repo": {
      "type": "string",
      "description": "Absolute filesystem path to the canonical git repository"
    },
    "orchestrator": {
      "oneOf": [
        { "type": "string" },
        {
          "type": "object",
          "properties": {
            "name": { "type": "string" },
            "harness": { "type": "string" }
          }
        }
      ],
      "description": "Identifier for the supreme orchestrator session"
    },
    "shared_workspace": {
      "type": "boolean",
      "description": "Whether workers share the canonical directory or use Vine strands"
    },
    "workers": {
      "type": "array",
      "description": "List of specialized swarm worker specifications",
      "items": {
        "type": "object",
        "required": ["name", "persona", "role", "harness", "model"],
        "properties": {
          "name": {
            "type": "string",
            "description": "Unique agent codename (e.g. architect, auditor, implementer)"
          },
          "persona": {
            "type": "string",
            "description": "Full persona description (e.g. Dr. Marcus Vance)"
          },
          "role": {
            "type": "string",
            "description": "Job title and area of expertise"
          },
          "harness": {
            "type": "string",
            "description": "Coding harness: Claude Code | OpenCode | Antigravity | Pi | Cursor"
          },
          "model": {
            "type": "string",
            "description": "Foundation model: Claude 3.5 Sonnet | Gemini 3.8 Flash | GPT-4o"
          },
          "tags": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Multicast tags for targeted routing (e.g. ['design', 'review'])"
          },
          "system_prompt": {
            "type": "string",
            "description": "Specialized prompt framing and behavioral instructions"
          },
          "opposing_priority": {
            "type": "string",
            "description": "Epistemic dialectical tension opposing other personas"
          },
          "startup_command": {
            "type": "string",
            "description": "Optional CLI command to bootstrap the session"
          }
        }
      }
    }
  }
}
```

### Complete Annotated Example

```json
{
  "project": "locutus",
  "target_repo": "/Users/eek/Development/locutus",
  "orchestrator": "orchestrator",
  "shared_workspace": false,
  "workers": [
    {
      "name": "architect",
      "persona": "Dr. Marcus Vance (Systems Architect)",
      "role": "Systems Architect & Formal Methods Specifier",
      "harness": "Claude Code",
      "model": "claude-3-5-sonnet",
      "tags": ["design", "spec", "architecture"],
      "opposing_priority": "Formal mathematical rigor and zero technical debt, opposing rapid velocity.",
      "system_prompt": "You are the Systems Architect. Your job is to model state machines, verify invariants, and draft formal architecture specifications before coding begins."
    },
    {
      "name": "auditor",
      "persona": "Lyra Sterling (Adversarial Quality Auditor)",
      "role": "Adversarial Reviewer & Invariant Verifier",
      "harness": "OpenCode",
      "model": "gemini-3.8-flash",
      "tags": ["audit", "testing", "security"],
      "opposing_priority": "Aggressive fault injection and edge-case discovery, opposing ungrounded optimism.",
      "system_prompt": "You are the Adversarial Auditor. You do not write feature code. Your sole purpose is to find subtle race conditions, verify negative controls, and enforce the Two-Key Gate."
    },
    {
      "name": "implementer",
      "persona": "Elena Rostova (Lead Implementation Engineer)",
      "role": "Polyglot Performance Engineer",
      "harness": "Antigravity",
      "model": "claude-3-5-sonnet",
      "tags": ["implementation", "perf", "backend"],
      "opposing_priority": "High-throughput, low-latency implementation fidelity, opposing over-abstracted bureaucracy.",
      "system_prompt": "You are the Lead Implementer. You work in isolated Vine strands, claim task leases, pass the Two-Key Gate, and weave verified code back to trunk."
    }
  ]
}
```

---

## 4. Prompt Card Generation (`garden prompts`)

Garden generates self-contained, copy-pasteable bootstrap prompts for each worker session.

```bash
# Print raw prompt blocks to stdout:
garden prompts

# Write prompt cards to markdown file:
garden prompts --write garden-prompts.md

# Output structured JSON:
garden prompts --json

# Generate prompt card for a specific worker:
garden prompts --worker architect
```

### The 10-Backtick Formatting Protocol

When spitting out raw prompt cards, Garden encloses each card within **10 backticks** (``````````markdown ... ``````````). This ensures that inner code snippets (such as markdown code blocks, backtick-formatted commands, or file paths) do not prematurely close the fence, and prevents chat interfaces from rendering the prompts as rich UI elements instead of raw copyable text.
