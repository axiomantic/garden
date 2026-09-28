# /Users/eek/Development/agora/src/guide.nim
# Manages installable/uninstallable demarcated documentation blocks in AGENTS.md
# for the Agora Multi-Agent Swarm Orchestration Engine.

import std/[os, strutils]

const
  GuideVersion* = "v1.0"
  BeginMarker* = "<!-- BEGIN AGORA GUIDE [" & GuideVersion & "] -->"
  EndMarker* = "<!-- END AGORA GUIDE -->"
  MarkerPrefix* = "<!-- BEGIN AGORA GUIDE"

const CanonicalGuideContent* = """
<!-- BEGIN AGORA GUIDE [v1.0] -->
<!-- DO NOT EDIT DIRECTLY: Managed by `agora guide install` -->

## Agora Multi-Agent Swarm & Ceremony Guide

Agora directs high-level methodology, persona deliberations, and synchronized task execution on top of Locu (transport) and Braid (workspace integrator).

### 0. Self-Bootstrapping Prerequisite
This project requires `locu`, `braid`, and `agora`. If missing, install via npm:
```bash
npm install -g @axiomantic/locu @axiomantic/braid @axiomantic/agora
```

### 1. Invariants & Epistemic Protocol
* **Zero Theatrical Dialogue**:
  Every dialectical exchange must cite empirical evidence obtained from tool execution (file line citations, test suite runs, AST analysis, compiler output). Theatrical roleplay without tool grounding is strictly prohibited.
* **Single-Source Planning**:
  All tasks, locks, and strands must be coordinated via `implementation_plan.md`. Dynamic progress must be tracked in lockstep with plan checkboxes (`- [ ]` to `- [x]`) and harness To-Do tracking.
* **Emergent Design Addendum Protocol**:
  Workers discovering architectural discrepancies cannot unilaterally deviate from `design.md`. They must submit a formal `addendum_<topic>.md` with rationale, await Orchestrator ratification, update `design.md`, and refresh `implementation_plan.md`.

### 2. Fleet Lifecycle & Multiplexer Discipline
* **Tmux Multiplexing**:
  All swarm workers run inside managed tmux panes created via `agora launch` or `scripts/launch_tmux_swarm.sh`. Never detach unmanaged background processes with `&` or redirect output.
* **Continuous Listening**:
  Workers must keep their Locu listener active (`locu listen <agent>`) with zero-timeout infinite wait to prevent token thrashing.

### 3. The Two-Key Gate & Strand Weaving
Never weave a strand into the canonical trunk without passing both keys:
* **Key 1 (Mechanical)**: In-memory conflict pre-check (`git merge-tree --write-tree`).
* **Key 2 (Semantic)**: Automated compiler and test suite run inside the strand.
* **Weave**: `braid weave && locu ack queue:<project>:tasks <task_id>`
<!-- END AGORA GUIDE -->
"""

type
  GuideStatus* = enum
    gsInstalled,
    gsNotFound,
    gsMalformed,
    gsFileMissing

proc checkGuide*(targetPath: string): GuideStatus =
  if not fileExists(targetPath):
    return gsFileMissing

  let content = readFile(targetPath)
  let hasBegin = content.contains(MarkerPrefix)
  let hasEnd = content.contains(EndMarker)

  if hasBegin and hasEnd:
    return gsInstalled
  elif hasBegin xor hasEnd:
    return gsMalformed
  else:
    return gsNotFound

proc installGuide*(targetPath: string): tuple[success: bool, message: string] =
  let status = checkGuide(targetPath)

  if status == gsMalformed:
    return (false, "Error: Malformed markers detected in " & targetPath & " (one marker found without matching pair). Aborting to prevent data loss.")

  let pid = getCurrentProcessId()
  let tmpPath = targetPath & ".tmp." & $pid

  try:
    if status == gsFileMissing:
      let parentDir = targetPath.splitPath.head
      if parentDir.len > 0:
        createDir(parentDir)
      let initialContent = "# AGENTS.md — Multi-Agent Coordination Guide\n\n" & CanonicalGuideContent.strip() & "\n"
      writeFile(tmpPath, initialContent)
      moveFile(tmpPath, targetPath)
      return (true, "Created " & targetPath & " and installed Agora Guide [" & GuideVersion & "].")

    let content = readFile(targetPath)

    if status == gsInstalled:
      # In-place update between markers
      let lines = content.splitLines()
      var newLines: seq[string] = @[]
      var inBlock = false
      var replaced = false

      for line in lines:
        if line.contains(MarkerPrefix):
          inBlock = true
          if not replaced:
            newLines.add(CanonicalGuideContent.strip())
            replaced = true
          continue
        elif inBlock and line.contains(EndMarker):
          inBlock = false
          continue

        if not inBlock:
          newLines.add(line)

      writeFile(tmpPath, newLines.join("\n") & "\n")
      moveFile(tmpPath, targetPath)
      return (true, "Updated Agora Guide to [" & GuideVersion & "] in " & targetPath & ".")

    else:
      # Append block cleanly
      var newContent = content.strip() & "\n\n" & CanonicalGuideContent.strip() & "\n"
      writeFile(tmpPath, newContent)
      moveFile(tmpPath, targetPath)
      return (true, "Appended Agora Guide [" & GuideVersion & "] to " & targetPath & ".")
  except CatchableError as e:
    if fileExists(tmpPath):
      try: removeFile(tmpPath) except CatchableError: discard
    return (false, "Error installing Agora Guide into " & targetPath & ": " & e.msg)

proc uninstallGuide*(targetPath: string): tuple[success: bool, message: string] =
  let status = checkGuide(targetPath)

  case status
  of gsFileMissing:
    return (false, "Target file does not exist: " & targetPath)
  of gsNotFound:
    return (true, "Agora Guide is not present in " & targetPath & " (nothing to remove).")
  of gsMalformed:
    return (false, "Error: Malformed markers detected in " & targetPath & " (unbalanced begin/end markers). Refusing to modify file.")
  of gsInstalled:
    let pid = getCurrentProcessId()
    let tmpPath = targetPath & ".tmp." & $pid

    try:
      let content = readFile(targetPath)
      let lines = content.splitLines()
      var newLines: seq[string] = @[]
      var inBlock = false

      for line in lines:
        if line.contains(MarkerPrefix):
          inBlock = true
          continue
        elif inBlock and line.contains(EndMarker):
          inBlock = false
          continue

        if not inBlock:
          newLines.add(line)

      # Clean up trailing whitespace
      var cleanOutput = newLines.join("\n").strip()
      if cleanOutput.len > 0:
        cleanOutput &= "\n"

      writeFile(tmpPath, cleanOutput)
      moveFile(tmpPath, targetPath)
      return (true, "Uninstalled Agora Guide from " & targetPath & ".")
    except CatchableError as e:
      if fileExists(tmpPath):
        try: removeFile(tmpPath) except CatchableError: discard
      return (false, "Error removing Agora Guide from " & targetPath & ": " & e.msg)
