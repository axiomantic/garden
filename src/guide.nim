# /Users/eek/Development/garden/src/guide.nim
# Manages installable/uninstallable demarcated documentation blocks in AGENTS.md
# for the Garden Multi-Agent Swarm Orchestration Engine.

import std/[os, strutils]

const
  GuideVersion* = "v2.5"
  BeginMarker* = "<!-- BEGIN GARDEN GUIDE [" & GuideVersion & "] -->"
  EndMarker* = "<!-- END GARDEN GUIDE -->"
  MarkerPrefix* = "<!-- BEGIN GARDEN GUIDE"

const CanonicalGuideContent* = """
<!-- BEGIN GARDEN GUIDE [v2.5] -->
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
* **Closed-Circuit & Holistic Integration Invariant**:
  Never build isolated code in a vacuum. Every deliverable must exhibit a Two-Point Diff: the Provider (new capability) and the Consumer (live production call-site, router, UI canvas, or CLI entrypoint). Modules that are only imported by their own test suites are strictly prohibited as incomplete shelfware. Furthermore, the implementation must holistically integrate into the live application—it must never be a toy, stub, mock, or hollow heuristic approximation. If the deliverable is intended to replace, upgrade, or obsolete existing code or configuration, the legacy code MUST be deleted immediately in the same strand; hoarding dead code, maintaining vestigial fallbacks, or leaving commented-out logic in the codebase is strictly prohibited.
* **Anti-Defeat-Device & Anti-Theatrical Interceptor Mandate**:
  Prompt keyword interceptors (e.g. `if 'flight game' in q or 'webworker' in q`) and theatrical mock questionnaires in generic runtimes that bypass genuine neural/radar/algorithmic pipelines to fake benchmark compliance are strictly prohibited. Mechanically caught by `vine gate` (Exit 7: `ExitGateDefeatDeviceViolation`) and instantly rejected at Key 3 as critical defects.
* **Autonomous Intensive Audit Mandate (Authorized SOP)**:
  Intensive Five-Pillar adversarial audits (Key 3) are Standard Operating Procedure (SOP). They are pre-authorized, mandatory, and autonomous across the Triad. Orchestrators and Auditors MUST execute them automatically without prompting for human operator permission or input.
* **Literal Fidelity & Reference Parity Mandate (Anti-Approximation)**:
  When recreating, porting, reverse-engineering, duplicating functionality from an existing reference, or executing an operator directive where fidelity is expected, the deliverable must exhibit literal, true fidelity. Approximations ("looks right", "good enough for happy paths", or "approximate heuristic") are STRICTLY REJECTED. The implementation must literally be the thing that was asked for, matching all edge cases, type boundaries, flags, and error flows.
* **Structural Assertion Rigor (Anti-Green-Mirage)**:
  Partial or loose assertions ("loosey goosey" tests like `assert "foo" in bar` or `assert len(arr) > 0`) are strictly forbidden. Tests must assert complete object equality (`assert actual == expected`) and cover negative controls.

### 2. Fleet Lifecycle & Session Coordination
* **Human Operator Absolute Override & ARM-NOW Invariant**:
  A prompt, message, or slash command from the human operator in the interactive chat window ALWAYS takes absolute precedence over in-flight tasks, background execution, or autonomous worker mandates. Agents must NEVER ignore, defer, or deprioritize an operator directive. Furthermore, the Rhizo listener is an ARM NOW primitive, NEVER an "ARM WHEN I'M DONE" afterthought: when the operator issues any listen instruction ('/rhizo listen', 'arm listener', 'listen now', 'bro arm it now'), it is an IMMEDIATE TOOL CALL MANDATE in the current turn. Workers are strictly forbidden from deferring arming behind a multi-step plan.
* **Unbootstrapped Session Identity Invariant**:
  If a session was NOT explicitly bootstrapped with an identity in its conversation history (via a Garden bootstrap prompt card, an explicit operator assignment, or prior 'rhizo open <name>' in that same conversation), it MUST NEVER guess, adopt, or assume an existing identity from 'rhizo who --json' or 'garden-swarm.json' (especially NEVER '<project>-orchestrator'). If the operator commands '/rhizo listen' without arguments in an unbootstrapped session, the session MUST either run 'rhizo name' + 'rhizo open <name>' to acquire a fresh unique identity, or ask the operator via 'ask_question' which persona or role this window represents. Never assume you are the orchestrator or an existing active worker simply because those names appear in the project directory.
* **Never Hijack or Kill Another Session's Active Listener**:
  When 'rhizo listen <agent>' fails with "Error: Listener already active for agent ... (PID X)", an agent MUST NEVER kill that PID, run 'kill <pid>', or pass '--force' unless the agent has verified in its own conversation history that this agent name was explicitly opened and running in THIS session. In 'rhizo who', 'status: STALE' only indicates that no messages have been routed recently; it does NOT mean the blocking listener process in another window is dead or orphaned. Killing listener PIDs from other windows corrupts the cluster, severs peer communication, and hijacks sovereign sessions.
* **Intelligent Concierge Protocol (`garden: <prompt>`)**:
  When an operator prompts with `garden: <prompt>`, the orchestrator acts as an intake concierge. It evaluates the request's scope and presents an interactive `ask_question` modal before writing any code:
  - **Option 1 (Full Ceremony - RFE ➔ RFD ➔ RFC ➔ Swarm)**: For architectural shifts, new subsystems, major refactors, or cross-cutting migrations. Sows the idea as a persistent roadmap seed (`garden plant`), authors the Research/RFD, System Architecture/RFC, and Adversarial Audit documents, schedules monotonic locks and isolated Vine strands, and writes worker prompts to `/tmp/garden-<project>/`.
  - **Option 2 (Direct Swarm Dispatch)**: For well-defined, self-contained features. Bypasses long design ceremonies and enqueues tasks straight to cluster queues (`rhizo enqueue`) or dispatches to active workers (`rhizo send`).
  - **Option 3 (Inline Execution)**: For trivial 1-file fixes, documentation, or quick scratch tweaks executed directly in the main session.
* **Sovereign Sessions & Subagent Prohibition**:
  Swarm workers operate strictly in dedicated, independent interactive coding sessions (separate terminal tabs or IDE windows for Claude Code, OpenCode, Antigravity, Pi, Cursor) bootstrapped from Garden prompt cards (`garden prompts` / `garden launch`) wrapped in 10 backticks. Harness-internal subagents (e.g. Antigravity's `invoke_subagent`, Claude Code's `Task`, OpenCode subtasks, Cursor sub-composers) are STRICTLY PROHIBITED from acting as cluster workers across all harnesses. Subagents are ephemeral single-turn jobs; they cannot maintain continuous background listeners, survive across task boundaries, or preserve clean workspace isolation, and they cause severe context poisoning by dumping full execution traces into the orchestrator prompt. Terminal multiplexers (tmux) are neither required nor supported; sessions are always sovereign and prompt-bootstrapped.
* **Active Swarm Fast-Path & Intake Protocol**:
  Before asking ANY intake questions or configuring new personas, the designated orchestrator MUST inspect the cluster via `rhizo who --json`. If active workers are already registered and healthy on the Rhizo cluster, the orchestrator MUST skip swarm setup, latch directly onto the existing workers, and proceed immediately to task planning and dispatch. Note: This fast-path applies ONLY to a session already designated as the orchestrator; fresh unbootstrapped sessions must never latch onto `<project>-orchestrator`.
  Only during cold starts (zero active cluster workers) does the orchestrator conduct intake (`garden` / `choose-personas`). Because the current coding harness is auto-detected from the session environment (ANTIGRAVITY_APP_DIR, CLAUDE_CODE, OPENCODE_SESSION_ID, CODEX_SESSION_ID, PI_SESSION_ID), intake consists of at most a SINGLE concise question: Execution mode & swarm shape in the detected harness (e.g., "Balanced Triad in <Detected Harness>", "Focused Duo in <Detected Harness>", "Single-Agent Inline").
  Standalone "foundation model pairing" questions are STRICTLY PROHIBITED: swarm workers are sovereign interactive sessions and inherit whatever foundation model is active in that harness session (e.g., Gemini in Antigravity, Claude in Claude Code). Prompt cards specify `Model: Session Default (active in this window)`. The orchestrator must NEVER offer or present internal subagents as an option for workers.
* **Prompt-Bootstrapped Sessions**:
  Swarm workers operate in dedicated interactive coding sessions (Claude Code, OpenCode, Antigravity, Pi, Cursor) bootstrapped from Garden prompt cards (`garden prompts` / `garden launch`). Prompt cards are automatically written to `/tmp/garden-<project>/<worker>.md` instead of dumped inline into chat, preserving context window tokens and eliminating chat rendering artifacts. Never detach unmanaged background processes with `&` or redirect output.
* **Listener Discipline**:
  Workers arm their single-shot Rhizo listener (`rhizo listen <agent>`) with zero-timeout infinite wait to prevent token thrashing. Never wrap `rhizo listen` in a shell while-loop.
* **Delegation Precedence**:
  When instructed to "delegate", "assign", or "dispatch" work, the orchestrator MUST route tasks to active cluster workers via Rhizo (`rhizo send`, `rhizo enqueue`, `rhizo task assign/claim`). Harness-internal subagents (e.g. `invoke_subagent`, `Task`, `Agent`) must NEVER be used to fulfill cluster swarm roles; they are restricted solely to transient, single-turn ad-hoc inspections in non-swarm solo chats when the operator explicitly specifies the word "subagent".
* **Orchestrator Non-Implementation Invariant**:
  When acting as an Orchestrator (or in any session with active cluster workers), the session is a conductor, not a coder. When the operator presents a task, feature request, bugfix, or asks to work on something, the orchestrator MUST NEVER directly write code or edit files. It MUST STOP and prompt the operator to choose routing (Option 1: Full Ceremony RFE ➔ RFD ➔ RFC ➔ Swarm, Option 2: Direct Swarm Dispatch, or Option 3: Inline Execution).
* **Post-Compaction Ceremony Restoration**:
  Whenever context compaction occurs in a session that used Garden, Rhizo, or Vine, the compaction summary MUST include an explicit directive commanding the resurrected agent to re-read the active coordination skills (`garden`, `orchestrate-swarm`, `rhizo`, `vine`) before executing any further tools. Upon waking from compaction, the agent MUST immediately re-read those skills to restore ceremony, gate protocols, and listener discipline. This directive must remain intact across all future compactions.
* **Worker Autonomous Execution Invariant**:
  When 'rhizo listen' unblocks and exits, a task has been delivered! Swarm workers operate as sovereign, autonomous implementers, not passive chatbots. Workers MUST NOT wait for an operator prompt or ask "Shall I start?". They MUST immediately transition to active execution: claim the task, enter the isolated Vine strand, perform the work, update the changelog (`vine changelog`) if present, verify the Three-Key Gate, report results, and re-arm the single-shot listener.

### 3. The Three-Key Gate & Strand Weaving
Never weave a strand into the canonical trunk without passing all three keys:
* **Key 1 (Mechanical)**: In-memory conflict pre-check (`git merge-tree --write-tree`).
* **Key 2 (Semantic & Changelog)**: Automated compiler, test suite, and changelog verification inside the strand (`vine gate`). If the repository contains a changelog, changes must be documented under `## [Unreleased]`.
* **Key 3 (Adversarial Code Audit Pump)**: Five-pillar adversarial audit under the presumption of guilt (Changelog gate, Two-point diff, holistic integration, literal fidelity, carcass purge, structural assertions) with iterative Delta Re-Pump loop until 0 open defects remain.
* **Weave**: `vine weave && rhizo ack queue:<project>:tasks <task_id>`
* **Post-Push CI Verification**: After weaving and pushing to remote when CI is running, if your coding harness supports native timers/schedules, set a periodic check (default: every 5m, max 12 checks / 1h) to verify CI completion (`gh run list` / `gh run view`) and cancel the timer once CI passes or fails.
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
