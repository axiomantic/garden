# /Users/eek/Development/garden/src/guide.nim
# Manages installable/uninstallable demarcated documentation blocks in AGENTS.md
# for the Garden Multi-Agent Swarm Orchestration Engine.

import std/[os, strutils]

const
  GuideVersion* = "v2.0"
  BeginMarker* = "<!-- BEGIN GARDEN GUIDE [" & GuideVersion & "] -->"
  EndMarker* = "<!-- END GARDEN GUIDE -->"
  MarkerPrefix* = "<!-- BEGIN GARDEN GUIDE"

const CanonicalGuideContent* = """
<!-- BEGIN GARDEN GUIDE [v2.0] -->
<!-- DO NOT EDIT DIRECTLY: Managed by `garden guide install` -->

## Garden Multi-Agent Swarm & Ceremony Guide

Garden directs high-level methodology, persona deliberations, and synchronized task execution on top of Rhizo (transport) and Vine (workspace integrator).

### 0. Self-Bootstrapping Prerequisite
This project requires `rhizo`, `vine`, and `garden`. If missing, install via npm:
```bash
npm install -g @axiomantic/rhizo @axiomantic/vine @axiomantic/garden rift-snapshot
```

### 1. Invariants & Epistemic Protocol
* **Zero Theatrical Dialogue**:
  Every dialectical exchange must cite empirical evidence obtained from tool execution (file line citations, test suite runs, AST analysis, compiler output). Theatrical roleplay without tool grounding is strictly prohibited.
* **Single-Source Planning**:
  All tasks, locks, and strands must be coordinated via `implementation_plan.md`. Dynamic progress must be tracked in lockstep with plan checkboxes (`- [ ]` to `- [x]`) and harness To-Do tracking.
* **Emergent Design Addendum Protocol**:
  Workers discovering architectural discrepancies cannot unilaterally deviate from `design.md`. They must submit a formal `addendum_<topic>.md` with rationale, await Orchestrator ratification, update `design.md`, and refresh `implementation_plan.md`.

### 2. Fleet Lifecycle & Session Coordination
* **Human Operator Absolute Override & ARM-NOW Invariant**:
  A prompt, message, or slash command from the human operator in the interactive chat window ALWAYS takes absolute precedence over in-flight tasks, background execution, or autonomous worker mandates. Agents must NEVER ignore, defer, or deprioritize an operator directive. Furthermore, the Rhizo listener is an ARM NOW primitive, NEVER an "ARM WHEN I'M DONE" afterthought: when the operator issues any listen instruction ('/rhizo listen', 'arm listener', 'listen now', 'bro arm it now'), it is an IMMEDIATE TOOL CALL MANDATE in the current turn. Workers are strictly forbidden from deferring arming behind a multi-step plan.
* **Sovereign Sessions & Subagent Prohibition**:
  Swarm workers operate strictly in dedicated, independent interactive coding sessions (separate terminal tabs or IDE windows for Claude Code, OpenCode, Antigravity, Pi, Cursor) bootstrapped from Garden prompt cards (`garden prompts` / `garden launch`) wrapped in 10 backticks. Harness-internal subagents (e.g. Antigravity's `invoke_subagent`, Claude Code's `Task`, OpenCode subtasks, Cursor sub-composers) are STRICTLY PROHIBITED from acting as cluster workers across all harnesses. Subagents are ephemeral single-turn jobs; they cannot maintain continuous background listeners, survive across task boundaries, or preserve clean workspace isolation, and they cause severe context poisoning by dumping full execution traces into the orchestrator prompt. Terminal multiplexers (tmux) are neither required nor supported; sessions are always sovereign and prompt-bootstrapped.
* **Active Swarm Fast-Path & Intake Protocol**:
  Before asking ANY intake questions or configuring new personas, the orchestrator MUST inspect the cluster via `rhizo who --json`. If active workers are already registered and healthy on the Rhizo cluster, the orchestrator MUST skip swarm setup, latch directly onto the existing workers, and proceed immediately to task planning and dispatch.
  Only during cold starts (zero active cluster workers) does the orchestrator conduct intake (`garden` / `choose-personas`). Because the current coding harness is auto-detected from the session environment (ANTIGRAVITY_APP_DIR, CLAUDE_CODE, OPENCODE_SESSION_ID, CODEX_SESSION_ID, PI_SESSION_ID), intake consists of at most a SINGLE concise question: Execution mode & swarm shape in the detected harness (e.g., "Balanced Triad in <Detected Harness>", "Focused Duo in <Detected Harness>", "Single-Agent Inline").
  Standalone "foundation model pairing" questions are STRICTLY PROHIBITED: swarm workers are sovereign interactive sessions and inherit whatever foundation model is active in that harness session (e.g., Gemini in Antigravity, Claude in Claude Code). Prompt cards specify `Model: Session Default (active in this window)`. The orchestrator must NEVER offer or present internal subagents as an option for workers.
* **Prompt-Bootstrapped Sessions**:
  Swarm workers operate in dedicated interactive coding sessions (Claude Code, OpenCode, Antigravity, Pi, Cursor) bootstrapped from Garden prompt cards (`garden prompts` / `garden launch`) wrapped in 10 backticks. Never detach unmanaged background processes with `&` or redirect output.
* **Listener Discipline**:
  Workers arm their single-shot Rhizo listener (`rhizo listen <agent>`) with zero-timeout infinite wait to prevent token thrashing. Never wrap `rhizo listen` in a shell while-loop.
* **Delegation Precedence**:
  When instructed to "delegate", "assign", or "dispatch" work, the orchestrator MUST route tasks to active cluster workers via Rhizo (`rhizo send`, `rhizo enqueue`, `rhizo task assign/claim`). Harness-internal subagents (e.g. `invoke_subagent`, `Task`, `Agent`) must NEVER be used to fulfill cluster swarm roles; they are restricted solely to transient, single-turn ad-hoc inspections in non-swarm solo chats when the operator explicitly specifies the word "subagent".
* **Orchestrator Non-Implementation Invariant**:
  When acting as an Orchestrator (or in any session with active cluster workers), the session is a conductor, not a coder. When the operator presents a task, feature request, bugfix, or asks to work on something, the orchestrator MUST NEVER directly write code or edit files. It MUST STOP and prompt the operator to choose routing (Enqueue to cluster queue, Dispatch to worker, or Execute inline).
* **Post-Compaction Ceremony Restoration**:
  Whenever context compaction occurs in a session that used Garden, Rhizo, or Vine, the compaction summary MUST include an explicit directive commanding the resurrected agent to re-read the active coordination skills (`garden`, `orchestrate-swarm`, `rhizo`, `vine`) before executing any further tools. Upon waking from compaction, the agent MUST immediately re-read those skills to restore ceremony, gate protocols, and listener discipline. This directive must remain intact across all future compactions.
* **Worker Autonomous Execution Invariant**:
  When 'rhizo listen' unblocks and exits, a task has been delivered! Swarm workers operate as sovereign, autonomous implementers, not passive chatbots. Workers MUST NOT wait for an operator prompt or ask "Shall I start?". They MUST immediately transition to active execution: claim the task, enter the isolated Vine strand, perform the work, verify the Two-Key Gate, report results, and re-arm the single-shot listener.

### 3. The Two-Key Gate & Strand Weaving
Never weave a strand into the canonical trunk without passing both keys:
* **Key 1 (Mechanical)**: In-memory conflict pre-check (`git merge-tree --write-tree`).
* **Key 2 (Semantic)**: Automated compiler and test suite run inside the strand.
* **Weave**: `vine weave && rhizo ack queue:<project>:tasks <task_id>`
<!-- END GARDEN GUIDE -->
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
      return (true, "Created " & targetPath & " and installed Garden Guide [" & GuideVersion & "].")

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
      return (true, "Updated Garden Guide to [" & GuideVersion & "] in " & targetPath & ".")

    else:
      # Append block cleanly
      var newContent = content.strip() & "\n\n" & CanonicalGuideContent.strip() & "\n"
      writeFile(tmpPath, newContent)
      moveFile(tmpPath, targetPath)
      return (true, "Appended Garden Guide [" & GuideVersion & "] to " & targetPath & ".")
  except CatchableError as e:
    if fileExists(tmpPath):
      try: removeFile(tmpPath) except CatchableError: discard
    return (false, "Error installing Garden Guide into " & targetPath & ": " & e.msg)

proc uninstallGuide*(targetPath: string): tuple[success: bool, message: string] =
  let status = checkGuide(targetPath)

  case status
  of gsFileMissing:
    return (false, "Target file does not exist: " & targetPath)
  of gsNotFound:
    return (true, "Garden Guide is not present in " & targetPath & " (nothing to remove).")
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
      return (true, "Uninstalled Garden Guide from " & targetPath & ".")
    except CatchableError as e:
      if fileExists(tmpPath):
        try: removeFile(tmpPath) except CatchableError: discard
      return (false, "Error removing Garden Guide from " & targetPath & ": " & e.msg)
