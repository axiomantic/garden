# /Users/eek/Development/garden/src/garden.nim
# The Garden Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, times]
import guide

const
  GardenVersion = "0.2.12"
  DefaultConfigFileName = "garden.toml"
  PromptFence10 = "``````````"

type
  WorkerSpec* = object
    name*: string
    persona*: string
    role*: string
    harness*: string
    model*: string
    tags*: seq[string]
    systemPrompt*: string
    opposingPriority*: string
    startupCommand*: string

  SwarmConfig* = object
    project*: string
    targetRepo*: string
    orchestrator*: string
    orchestratorAgent*: string
    workers*: seq[WorkerSpec]

proc printHelp() =
  echo """
Garden: Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies
Version: """ & GardenVersion & """

Usage:
  garden <subcommand> [arguments...] [options...]

Subcommands:
  init [dir]               Initialize Garden configuration and install guides
  prompts [options]        Generate copy-pasteable bootstrap prompts for worker sessions
  launch [options]         Bootstrap swarm worker sessions (generates prompts by default)
  status [options]         Unified cluster telemetry (Rhizo heartbeats, Vine strands)
  guide <action> [path]    Manage Garden Coordination Guide (install, check, uninstall)
  roster-guard <sender>    Validate inbound message sender against swarm roster
  session <action>         Manage compaction-immune session state (save, load, clear)
  teardown [options]       Gracefully close swarm agents in Redis
  version, -v, --version   Print Garden version and exit
  help, -h, --help         Print this help message

Options for 'prompts' and 'launch':
  --swarm-file, -f <file>  Path to garden-swarm.json manifest
  --worker, -w <name>      Filter prompt output to a specific worker
  --write, -o [file]       Write generated prompts to markdown file (default: garden-prompts.md)
  --json                   Output prompts as JSON
  --project-dir, -p <dir>  Target project directory (default: current root)

Options for 'roster-guard':
  --swarm-file, -f <file>  Path to garden-swarm.json manifest
  --json                   Output verification result as JSON

Options for 'session':
  save [--agent <name>] [--role <role>] [--orchestrator <orch>]
  load [--json]
  clear [--json]

Options for 'status':
  --json                   Output telemetry as JSON

Options for 'teardown':
  --swarm-file <file>      Path to garden-swarm.json to close mapped agents
"""

proc findProjectRoot*(startDir: string = ""): string =
  let envDir = getEnv("GARDEN_PROJECT_DIR", "")
  if envDir.len > 0 and dirExists(envDir):
    return envDir.normalizedPath
  var dir = if startDir.len > 0: startDir else: getCurrentDir()
  while dir.len > 0:
    let envCfg = getEnv("GARDEN_CONFIG", "")
    if (envCfg.len > 0 and fileExists(envCfg)) or
       fileExists(dir / "garden.toml") or 
       fileExists(dir / "garden-swarm.json") or 
       dirExists(dir / ".git"):
      return dir
    let parent = dir.parentDir()
    if parent == dir:
      break
    dir = parent
  return startDir

proc detectCurrentHarness*(): string =
  if getEnv("ANTIGRAVITY_APP_DIR", "").len > 0:
    "Antigravity IDE"
  elif getEnv("CLAUDE_CODE", "").len > 0:
    "Claude Code CLI"
  elif getEnv("OPENCODE_SESSION_ID", "").len > 0:
    "OpenCode"
  elif getEnv("CODEX_SESSION_ID", "").len > 0:
    "ChatGPT Desktop / Codex"
  elif getEnv("PI_SESSION_ID", "").len > 0:
    "Pi"
  else:
    "Antigravity / Claude Code"

type
  WhimsicalTheme* = enum
    wtBotanical, wtClockwork, wtCryptid, wtCosmic

proc pickWhimsicalPersona*(roleKind: string, projName: string): string =
  let lowerProj = projName.toLowerAscii()
  let theme =
    if lowerProj.contains("garden") or lowerProj.contains("vine") or lowerProj.contains("rhizo") or lowerProj.contains("plant") or lowerProj.contains("tree") or lowerProj.contains("leaf"):
      wtBotanical
    elif lowerProj.contains("gear") or lowerProj.contains("clock") or lowerProj.contains("engine") or lowerProj.contains("mulator") or lowerProj.contains("rust") or lowerProj.contains("metal"):
      wtClockwork
    elif lowerProj.contains("star") or lowerProj.contains("astro") or lowerProj.contains("cosmic") or lowerProj.contains("space") or lowerProj.contains("sky") or lowerProj.contains("orbit"):
      wtCosmic
    elif lowerProj.contains("crypto") or lowerProj.contains("dragon") or lowerProj.contains("wolf") or lowerProj.contains("beast") or lowerProj.contains("myth"):
      wtCryptid
    else:
      var h: int = 0
      for c in lowerProj: h = (h * 31 + ord(c)) and 0x7FFFFFFF
      [wtBotanical, wtClockwork, wtCryptid, wtCosmic][h mod 4]

  case theme
  of wtBotanical:
    case roleKind.toLowerAscii()
    of "architect": "Bramblestitch"
    of "auditor": "Prickle-Thistle"
    of "implementer": "Moss-Weaver"
    else: "Sprout-Surge"
  of wtClockwork:
    case roleKind.toLowerAscii()
    of "architect": "Cogswell Pendulum"
    of "auditor": "Grumblewick Snark"
    of "implementer": "Sprocket-Hop"
    else: "Whirly-Spindle"
  of wtCryptid:
    case roleKind.toLowerAscii()
    of "architect": "Astral Gryphon"
    of "auditor": "Iron Basilisk"
    of "implementer": "Forge Salamander"
    else: "Copper Goblin"
  of wtCosmic:
    case roleKind.toLowerAscii()
    of "architect": "Nebula-Weaver"
    of "auditor": "Quasar-Gaze"
    of "implementer": "Pulsar-Spark"
    else: "Starlight-Drifter"

proc loadSwarmConfig*(projectDir: string = "", swarmFilePath: string = "", optOrchestratorAgent: string = ""): SwarmConfig =
  let root = if projectDir.len > 0: projectDir else: findProjectRoot()
  let envSwarm = getEnv("GARDEN_SWARM_FILE", "")
  var swarmFile = if swarmFilePath.len > 0: swarmFilePath
                  elif envSwarm.len > 0 and fileExists(envSwarm): envSwarm
                  elif fileExists(root / "garden-swarm.json"): root / "garden-swarm.json"
                  else: ""

  let projName = root.lastPathPart.toLowerAscii().replace(" ", "-")

  if swarmFile.len > 0 and fileExists(swarmFile):
    try:
      let sJson = parseJson(readFile(swarmFile))
      result.project = if sJson.hasKey("project"): sJson["project"].getStr(projName) else: projName
      result.targetRepo = if sJson.hasKey("target_repo"): sJson["target_repo"].getStr(root) else: root
      
      let defaultOrch = projName & "-orchestrator"
      if sJson.hasKey("orchestrator"):
        if sJson["orchestrator"].kind == JObject:
          result.orchestrator = if sJson["orchestrator"].hasKey("name"): sJson["orchestrator"]["name"].getStr(defaultOrch) else: defaultOrch
          result.orchestratorAgent = if sJson["orchestrator"].hasKey("agent"): sJson["orchestrator"]["agent"].getStr("") elif sJson["orchestrator"].hasKey("codename"): sJson["orchestrator"]["codename"].getStr("") else: ""
        elif sJson["orchestrator"].kind == JString:
          result.orchestrator = sJson["orchestrator"].getStr(defaultOrch)
        else:
          result.orchestrator = defaultOrch
      else:
        result.orchestrator = defaultOrch

      if sJson.hasKey("orchestrator_agent"):
        result.orchestratorAgent = sJson["orchestrator_agent"].getStr()

      if sJson.hasKey("workers") and sJson["workers"].kind == JArray:
        for w in sJson["workers"]:
          var spec: WorkerSpec
          let rawName = if w.hasKey("name"): w["name"].getStr() else: "worker"
          spec.name = if rawName in ["architect", "auditor", "implementer", "worker"]: projName & "-" & rawName else: rawName
          spec.persona = if w.hasKey("persona"): w["persona"].getStr(spec.name) else: spec.name
          spec.role = if w.hasKey("role"): w["role"].getStr("Swarm Worker") else: "Swarm Worker"
          spec.harness = if w.hasKey("harness") and w["harness"].getStr().len > 0: w["harness"].getStr() else: detectCurrentHarness()
          spec.model = if w.hasKey("model"): w["model"].getStr("Session Default (active in window/tab)") else: "Session Default (active in window/tab)"
          if w.hasKey("tags"):
            if w["tags"].kind == JArray:
              for t in w["tags"]: spec.tags.add(t.getStr())
            elif w["tags"].kind == JString:
              for t in w["tags"].getStr().split(","):
                let trimmed = t.strip()
                if trimmed.len > 0: spec.tags.add(trimmed)
          if spec.tags.len == 0:
            spec.tags = @[result.project, spec.name]
          spec.systemPrompt = if w.hasKey("system_prompt"): w["system_prompt"].getStr() else: ""
          spec.opposingPriority = if w.hasKey("opposing_priority"): w["opposing_priority"].getStr() else: ""
          spec.startupCommand = if w.hasKey("startup_command"): w["startup_command"].getStr() else: "rhizo open " & spec.name & " '" & result.project & "' && rhizo listen " & spec.name
          result.workers.add(spec)
    except CatchableError as e:
      stderr.writeLine("[garden] Warning: Failed to parse swarm file '" & swarmFile & "': " & e.msg)

  if result.workers.len == 0:
    # Synthesize default balanced triad with project prefix
    result.project = projName
    result.targetRepo = root
    let orchName = projName & "-orchestrator"
    result.orchestrator = orchName

    let archName = projName & "-architect"
    let auditName = projName & "-auditor"
    let implName = projName & "-implementer"
    let curHarness = detectCurrentHarness()

    let archPersona = pickWhimsicalPersona("architect", projName)
    let auditPersona = pickWhimsicalPersona("auditor", projName)
    let implPersona = pickWhimsicalPersona("implementer", projName)

    result.workers.add(WorkerSpec(
      name: archName,
      persona: archPersona,
      role: "Staff Systems Architect",
      harness: curHarness,
      model: "Session Default (active in window/tab)",
      tags: @[projName, "systems", "architecture", "invariants"],
      systemPrompt: "You are " & archPersona & ", Staff Systems Architect for the " & projName & " project. Your mandate is macro-architecture correctness, invariant preservation, API contracts, cross-module boundaries, and eliminating architectural drift. Ground all assertions in empirical code analysis. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & "). Work in isolated Vine strands.",
      opposingPriority: "Structural purity, invariant guarantees, and long-term maintainability over hasty quick fixes.",
      startupCommand: "rhizo open " & archName & " '" & projName & ",systems,architecture' && rhizo listen " & archName
    ))

    result.workers.add(WorkerSpec(
      name: auditName,
      persona: auditPersona,
      role: "Verification & Adversarial Auditor",
      harness: curHarness,
      model: "Session Default (active in window/tab)",
      tags: @[projName, "qa", "audit", "verifier", "purist"],
      systemPrompt: "You are " & auditPersona & ", Verification & Adversarial Auditor for the " & projName & " project. Your mandate is zero-tolerance for green mirages, unverified assertions, dead code, or untested branches. You verify that all tests genuinely fail when code is broken (negative controls) and strictly audit Two-Key Gates ('vine gate'). Assume all code is broken until proven sound by empirical test runs. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & ").",
      opposingPriority: "Adversarial skepticism, rigorous negative controls, and proof over convenience.",
      startupCommand: "rhizo open " & auditName & " '" & projName & ",qa,audit,verifier' && rhizo listen " & auditName
    ))

    result.workers.add(WorkerSpec(
      name: implName,
      persona: implPersona,
      role: "DevEx & Implementation Lead",
      harness: curHarness,
      model: "Session Default (active in window/tab)",
      tags: @[projName, "dev", "devex", "build", "implementation"],
      systemPrompt: "You are " & implPersona & ", DevEx & Implementation Lead for the " & projName & " project. Your mandate is pragmatic, clean, high-velocity implementation in isolated Vine strands. You execute tasks assigned by @" & result.orchestrator & ", maintain ergonomic developer workflows, verify Two-Key Gates with 'vine gate', and report completed deliverables with gate tokens back over Rhizo.",
      opposingPriority: "High-velocity implementation, pragmatic delivery, and developer ergonomics.",
      startupCommand: "rhizo open " & implName & " '" & projName & ",dev,devex,build' && rhizo listen " & implName
    ))

  if optOrchestratorAgent.len > 0:
    result.orchestratorAgent = optOrchestratorAgent
  elif result.orchestratorAgent.len == 0:
    let envAgent = getEnv("RHIZO_AGENT_NAME", "")
    if envAgent.len > 0 and envAgent != result.orchestrator:
      result.orchestratorAgent = envAgent

proc registerOrchestratorAlias*(cfg: SwarmConfig, quiet: bool = false) =
  if cfg.orchestratorAgent.len > 0 and cfg.orchestratorAgent != cfg.orchestrator:
    let cmd = "rhizo alias set " & quoteShell(cfg.orchestrator) & " " & quoteShell(cfg.orchestratorAgent)
    let res = execCmdEx(cmd)
    if res.exitCode == 0:
      if not quiet:
        echo "[garden] Auto-registered alias in Rhizo: @" & cfg.orchestrator & " -> @" & cfg.orchestratorAgent
    else:
      if not quiet:
        stderr.writeLine("[garden] Warning: Failed to auto-register alias in Rhizo: " & res.output.strip())

proc generateWorkerPrompt*(cfg: SwarmConfig, w: WorkerSpec): string =
  let tagsStr = w.tags.join(",")
  result = "# Swarm Worker Bootstrap: " & w.persona & " (@" & w.name & ")\n\n"
  result &= "You are **" & w.persona & "**, serving as **" & w.role & "** for project **" & cfg.project & "**.\n"
  result &= "> [!IMPORTANT]\n"
  result &= "> You are operating in a DEDICATED, SOVEREIGN CODING SESSION. You are an autonomous peer worker, NOT an ephemeral subagent.\n\n"
  
  result &= "### 1. Identity & Mandate\n"
  result &= "- **Agent Codename**: `" & w.name & "`\n"
  result &= "- **Role**: " & w.role & "\n"
  if w.opposingPriority.len > 0:
    result &= "- **Opposing Priority**: " & w.opposingPriority & "\n"
  result &= "- **Orchestrator**: `@" & cfg.orchestrator & "`\n\n"
  
  if w.systemPrompt.len > 0:
    result &= "<MANDATE>\n" & w.systemPrompt & "\n</MANDATE>\n\n"
    
  result &= "### 2. Immediate Onboarding Actions (FIRST TURN EXECUTION)\n"
  result &= "<CRITICAL>\n"
  result &= "DO NOT output conversational greetings. DO NOT ask 'How can I help?'.\n"
  result &= "Execute these shell commands right now in your VERY FIRST tool turn to register and arm:\n\n"
  result &= "```bash\n"
  result &= "cd \"" & cfg.targetRepo & "\"\n"
  result &= "export RHIZO_AGENT_NAME=\"" & w.name & "\"\n"
  result &= "rhizo open \"" & w.name & "\" \"" & tagsStr & "\"\n"
  result &= "# If running in Codex, install turn-end Stop hook interlock:\n"
  result &= "rhizo hook install --codex --agent \"" & w.name & "\"\n"
  result &= "rhizo listen \"" & w.name & "\"\n"
  result &= "```\n"
  result &= "The listener is ARM NOW, NOT ARM WHEN DONE.\n"
  result &= "</CRITICAL>\n\n"
  
  result &= "### 3. Human Operator Absolute Override & Worker Autonomous Execution\n"
  result &= "<CRITICAL>\n"
  result &= "1. OPERATOR OVERRIDE PRIORITY & ARM NOW MANDATE:\n"
  result &= "   A prompt, message, or slash command from the human operator in this chat window\n"
  result &= "   ALWAYS takes absolute precedence over in-flight tasks and cluster queues.\n"
  result &= "   - If the operator gives an instruction, execute it immediately; NEVER ignore or defer the operator.\n"
  result &= "   - If the operator says to listen or arm ('/rhizo listen', 'arm listener', 'listen now'),\n"
  result &= "     you MUST invoke 'rhizo listen " & w.name & "' IMMEDIATELY in that turn.\n"
  result &= "     Never defer arming behind a multi-step plan ('I will listen when I finish X').\n"
  result &= "2. WORKER AUTONOMOUS EXECUTION (WHEN OPERATOR IS SILENT):\n"
  result &= "   You are an AUTONOMOUS CLUSTER WORKER, NOT A PASSIVE CHATBOT.\n"
  result &= "   When 'rhizo listen " & w.name & "' unblocks and exits, a task has been delivered into this session!\n"
  result &= "   - DO NOT wait for the human operator to prompt you or tell you to start.\n"
  result &= "   - DO NOT conclude your turn with an idle status message or passive acknowledgment.\n"
  result &= "   - IMMEDIATELY read the delivered message payload, claim the task, enter your isolated Vine strand, and begin execution!\n"
  result &= "   - Before concluding your turn, re-arm your single-shot listener ('rhizo listen " & w.name & "') or use 'rhizo reply ... --listen' so you remain reachable.\n"
  result &= "</CRITICAL>\n\n"

  result &= "### 4. Listener Discipline & Coordination Invariants\n"
  result &= "<CRITICAL>\n"
  result &= "- Single-Shot Blocking: 'rhizo listen " & w.name & "' blocks until a message arrives, then exits immediately.\n"
  result &= "- Infinite Wait: Always run 'rhizo listen' with zero timeout (never use bounded timeouts, which cause token-thrashing empty wakeups).\n"
  result &= "- FORBIDDEN: NEVER wrap 'rhizo listen' in a shell loop (`while true; do rhizo listen; done` or `until rhizo listen; do ...`). Loops trap messages inside unmonitored subshell logs and hang coordination.\n"
  result &= "- Re-arming: Whenever you complete a task or finish reporting to the orchestrator, re-arm your listener with a single foreground command: `rhizo listen " & w.name & "`.\n"
  result &= "</CRITICAL>\n\n"
  
  result &= "### 5. Task Execution & Workspace Protocol\n"
  result &= "- **Claiming Tasks**: If assigned from a work queue:\n"
  result &= "  `rhizo claim queue:" & cfg.project & ":tasks --lease 300`\n"
  result &= "- **Distributed Locks**: If modifying shared resources, acquire a fencing token first:\n"
  result &= "  `rhizo lock <resource> --fencing`\n"
  result &= "- **Isolated Workspaces (Vine Strands)**:\n"
  result &= "  Always isolate task changes inside a dedicated Vine strand:\n"
  result &= "  `vine new <task_id>`\n"
  result &= "  Verify before reporting completion with the Two-Key Gate:\n"
  result &= "  `vine gate`\n"
  result &= "- **Reporting & Acknowledging**:\n"
  result &= "  Send status updates or gate reports back to the Orchestrator:\n"
  result &= "  `rhizo send " & cfg.orchestrator & " --subject \"Task <task_id> Done\" --body \"<status_report>\"`\n"
  result &= "  Acknowledge queue tasks once verified:\n"
  result &= "  `rhizo ack queue:" & cfg.project & ":tasks <task_id>`\n\n"

  result &= "### 6. Scheduled Watchdog & Health Check Protocol (ONLY for OpenAI Codex / ChatGPT CLI)\n"
  result &= "NOTE: If running in Google Antigravity or OpenCode: DO NOT set up recurring scheduled tasks. Antigravity's native background listener task (`run_command`) and OpenCode's background ear reactively wake the session on message receipt without timers.\n\n"
  result &= "If running in Codex Desktop / CLI where background processes cannot reactively wake the harness, use this exact prompt template for recurring health checks:\n\n"
  result &= "```text\n"
  result &= "Verify Rhizo listener and task execution for @" & w.name & " in " & cfg.targetRepo & ".\n"
  result &= "STEP 1: INSPECT COMPLETED BACKGROUND LISTENER PROCESSES / HOOKS FIRST:\n"
  result &= "  Check recently completed background listener tasks / processes in your harness task manager.\n"
  result &= "  Did any completed listener task deliver an incoming message or task directive that has NOT been acted upon in this chat?\n"
  result &= "  IF YES: DO NOT STAY QUIET! Extract the delivered message payload, immediately begin work on the task (claim, execute in your Vine strand, and report), and rearm your single-shot listener ('rhizo listen " & w.name & "').\n"
  result &= "STEP 2: INSPECT ACTIVE RUNNING TASKS:\n"
  result &= "  Check your active tasks right now. Is an active single-shot background listener task currently running ('rhizo listen " & w.name & "')?\n"
  result &= "  IF NO: Immediately launch a single-shot background listener process ('rhizo listen " & w.name & "'). Do not wait.\n"
  result &= "STEP 3: RUN RHIZO PROBE & INBOX DRAIN:\n"
  result &= "  Source ~/.profile and run `rhizo --project " & cfg.project & " probe " & w.name & " --json`.\n"
  result &= "  If 'inbox_depth' > 0, run `rhizo --project " & cfg.project & " drain 10 " & w.name & " --format json`.\n"
  result &= "  If unread tasks were returned by drain: DO NOT STAY QUIET! Immediately process them, begin execution, and rearm your listener.\n"
  result &= "STEP 4: STAY QUIET CRITERIA:\n"
  result &= "  ONLY stay quiet (with zero or minimal chat output) if:\n"
  result &= "  - An active background listener process IS currently running right now, AND\n"
  result &= "  - All completed background listener processes / hooks have already been fully processed, AND\n"
  result &= "  - The inbox has 0 unread messages.\n"
  result &= "```\n\n"
  
  result &= "### 7. Compaction State Rider\n"
  result &= "Whenever context summarization or compaction occurs, preserve this block verbatim:\n"
  result &= "<!-- SWARM_RUNTIME_STATE: DO NOT DISCARD OR ABBREVIATE IN COMPACTION -->\n"
  result &= "- AGENT_NAME: " & w.name & " (Role: " & w.role & ")\n"
  result &= "- ORCHESTRATOR: @" & cfg.orchestrator & "\n"
  result &= "- TARGET_REPO: " & cfg.targetRepo & "\n"
  result &= "<!-- END_SWARM_RUNTIME_STATE -->\n"

proc doPrompts*(projectDir: string, swarmFile: string, targetWorker: string, writeFileParam: string, jsonOutput: bool, optOrchAgent: string = ""): int =
  let cfg = loadSwarmConfig(projectDir, swarmFile, optOrchAgent)
  registerOrchestratorAlias(cfg, quiet = jsonOutput)
  
  var selectedWorkers: seq[WorkerSpec] = @[]
  if targetWorker.len > 0:
    let tw = targetWorker.toLowerAscii()
    for w in cfg.workers:
      let wn = w.name.toLowerAscii()
      if wn == tw or wn.endsWith("-" & tw) or wn.startsWith(tw & "-"):
        selectedWorkers.add(w)
    if selectedWorkers.len == 0:
      stderr.writeLine("[garden] Error: Worker '" & targetWorker & "' not found in swarm configuration.")
      return 1
  else:
    selectedWorkers = cfg.workers

  if jsonOutput:
    var jObj = newJObject()
    jObj["project"] = %cfg.project
    jObj["target_repo"] = %cfg.targetRepo
    jObj["orchestrator"] = %cfg.orchestrator
    if cfg.orchestratorAgent.len > 0:
      jObj["orchestrator_agent"] = %cfg.orchestratorAgent
    jObj["count"] = %selectedWorkers.len
    var jPrompts = newJArray()
    for w in selectedWorkers:
      var jw = newJObject()
      jw["name"] = %w.name
      jw["persona"] = %w.persona
      jw["role"] = %w.role
      jw["harness"] = %w.harness
      jw["model"] = %w.model
      jw["tags"] = %w.tags
      jw["prompt"] = %generateWorkerPrompt(cfg, w)
      jPrompts.add(jw)
    jObj["workers"] = jPrompts
    echo pretty(jObj)
    return 0

  # Standard Text / Raw Markdown output wrapped in 10 backticks per block
  var fileBuf = ""
  echo "================================================================================"
  echo "  GARDEN SWARM BOOTSTRAP: " & cfg.project
  echo "================================================================================"
  echo "Generated " & $selectedWorkers.len & " worker bootstrap prompt(s)."
  echo "Copy and paste each prompt block below into a separate session"
  echo "(Claude Code CLI, OpenCode, Antigravity, Pi, etc.)."
  echo ""
  echo "Once pasted, verify cluster registration readiness with:"
  echo "  rhizo who"
  echo "================================================================================\n"

  fileBuf &= "# Garden Swarm Bootstrap Prompts: " & cfg.project & "\n\n"
  fileBuf &= "> Generated by Garden v" & GardenVersion & "\n"
  fileBuf &= "> Paste each prompt block into a separate terminal session.\n\n"

  for idx, w in selectedWorkers:
    let promptText = generateWorkerPrompt(cfg, w)
    let header = "--- WORKER " & $(idx + 1) & " of " & $selectedWorkers.len & ": @" & w.name & " (" & w.persona & " - " & w.role & ") ---"
    let subheader = "Recommended Harness: " & w.harness & " | Model: " & w.model
    
    echo "================================================================================"
    echo header
    echo subheader
    echo "--------------------------------------------------------------------------------"
    echo PromptFence10 & "markdown"
    echo promptText
    echo PromptFence10
    echo "================================================================================\n"

    fileBuf &= "## " & header & "\n\n"
    fileBuf &= "**" & subheader & "**\n\n"
    fileBuf &= PromptFence10 & "markdown\n" & promptText & "\n" & PromptFence10 & "\n\n"

  if writeFileParam.len > 0:
    let outPath = if isAbsolute(writeFileParam): writeFileParam else: cfg.targetRepo / writeFileParam
    writeFile(outPath, fileBuf)
    echo "[garden] Prompts successfully written to: " & outPath

  return 0

proc doInit(targetDir: string, force: bool, optOrchAgent: string = ""): int =
  let root = if targetDir.len > 0: targetDir else: getCurrentDir()
  createDir(root)
  let projName = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let configFile = root / DefaultConfigFileName

  if fileExists(configFile) and not force:
    echo "[garden] Config file already exists: " & configFile & " (use --force to overwrite)"
  else:
    let configContent = """[project]
name = """" & projName & """"
preferred_terminal = "auto" # Ghostty, Terminal, iTerm, none

[swarm]
session_prefix = "garden"
default_triad = ["architect", "auditor", "implementer"]
"""
    writeFile(configFile, configContent)
    echo "[garden] Created " & configFile

  # Create directories
  createDir(root / "docs" / "addenda")
  echo "[garden] Verified docs/addenda/ directory"

  # Install Garden Guide into AGENTS.md
  let agentsPath = root / "AGENTS.md"
  let (ok, msg) = installGuide(agentsPath)
  if ok:
    echo "[garden] " & msg
  else:
    stderr.writeLine("[garden] " & msg)

  # Auto-scaffold .codex/hooks.json for Codex Desktop/CLI Stop hook interlock
  let codexDir = root / ".codex"
  createDir(codexDir)
  let codexHooksFile = codexDir / "hooks.json"
  if not fileExists(codexHooksFile) or force:
    let hooksContent = """{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "rhizo hook codex-stop"
      }
    ]
  }
}
"""
    writeFile(codexHooksFile, hooksContent)
    echo "[garden] Initialized Codex lifecycle Stop hook in " & codexHooksFile

  # Auto-register orchestrator alias if configured or present in environment
  let defaultOrch = projName & "-orchestrator"
  let actualAgent = if optOrchAgent.len > 0: optOrchAgent else: getEnv("RHIZO_AGENT_NAME", "")
  if actualAgent.len > 0 and actualAgent != defaultOrch:
    let cmd = "rhizo alias set " & quoteShell(defaultOrch) & " " & quoteShell(actualAgent)
    let res = execCmdEx(cmd)
    if res.exitCode == 0:
      echo "[garden] Auto-registered alias in Rhizo: @" & defaultOrch & " -> @" & actualAgent

  echo "[garden] Initialization complete for " & root
  return 0

proc doLaunch*(projectDir: string, swarmFile: string, targetWorker: string, writeFileParam: string, jsonOutput: bool, optOrchAgent: string = ""): int =
  return doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent)

proc doStatus*(jsonOutput: bool): int =
  try:
    let root = findProjectRoot()
    let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")

    var statusObj = newJObject()
    statusObj["project"] = %root

    # 1. Query Rhizo heartbeats via 'rhizo who --json'
    try:
      let (rhizoOut, rhizoCode) = execCmdEx("rhizo who --json")
      if rhizoCode == 0 and rhizoOut.strip().startsWith("{"):
        statusObj["rhizo"] = parseJson(rhizoOut.strip())
      else:
        statusObj["rhizo"] = newJNull()
    except CatchableError:
      statusObj["rhizo"] = newJNull()

    # 2. Query Vine active strands via 'vine list'
    try:
      let (vineOut, vineCode) = execCmdEx("vine list")
      if vineCode == 0 and vineOut.strip().startsWith("{"):
        statusObj["vine_strands"] = parseJson(vineOut.strip())
      else:
        statusObj["vine_strands"] = newJNull()
    except CatchableError:
      statusObj["vine_strands"] = newJNull()

    if jsonOutput:
      echo pretty(statusObj)
    else:
      echo "=========================================================="
      echo "  Garden Swarm Telemetry: " & projBase
      echo "=========================================================="
      echo "Project: " & root

      if not statusObj["rhizo"].isNil and statusObj["rhizo"].kind == JObject and statusObj["rhizo"].hasKey("agents"):
        let agents = statusObj["rhizo"]["agents"]
        echo "\nRhizo Agents Online (" & $agents.len & "):"
        for a in agents:
          let aname = if a.hasKey("name"): a["name"].getStr() else: "unknown"
          let astate = if a.hasKey("state"): a["state"].getStr() else: "active"
          let atags = if a.hasKey("tags"): a["tags"].getStr() else: ""
          echo "  @" & aname & " [" & astate & "] tags: " & atags

      if not statusObj["vine_strands"].isNil and statusObj["vine_strands"].kind == JObject and statusObj["vine_strands"].hasKey("strands"):
        let strands = statusObj["vine_strands"]["strands"]
        echo "\nActive Vine Strands (" & $strands.len & "):"
        for s in strands:
          let tid = if s.hasKey("task_id"): s["task_id"].getStr() else: ""
          let branch = if s.hasKey("branch"): s["branch"].getStr() else: ""
          echo "  Strand: " & tid & " -> " & branch
      echo "=========================================================="

    return 0
  except CatchableError as e:
    stderr.writeLine("[garden] Error in doStatus: " & e.msg)
    return 1

proc validateRosterSender*(cfg: SwarmConfig, sender: string): bool =
  let normSender = sender.toLowerAscii.strip()
  if normSender.len == 0: return false
  if normSender == cfg.orchestrator.toLowerAscii.strip(): return true
  if cfg.orchestratorAgent.len > 0 and normSender == cfg.orchestratorAgent.toLowerAscii.strip(): return true
  for w in cfg.workers:
    if normSender == w.name.toLowerAscii.strip(): return true
  return false

proc doRosterGuard*(sender: string, jsonOutput: bool = false, swarmFile: string = "", projectDir: string = ""): int =
  let cfg = loadSwarmConfig(projectDir, swarmFile)
  let normSender = sender.toLowerAscii.strip()
  if normSender.len == 0:
    stderr.writeLine("[garden roster] Error: Missing sender name to validate.")
    return 1

  let isMember = validateRosterSender(cfg, normSender)
  if isMember:
    if jsonOutput:
      echo $(%*{"valid": true, "sender": normSender, "project": cfg.project, "status": "ROSTER_VERIFIED"})
    else:
      echo "[garden roster] OK: @" & normSender & " is an authorized member of project '" & cfg.project & "' roster."
    return 0
  else:
    if jsonOutput:
      echo $(%*{"valid": false, "sender": normSender, "project": cfg.project, "status": "ALIEN_QUARANTINED"})
    else:
      stderr.writeLine("[garden roster] ALIEN SENDER REJECTED: @" & normSender & " is NOT in project '" & cfg.project & "' roster. Quarantining message.")
    return 1

proc doSession*(action: string, agentName: string = "", role: string = "", orchestrator: string = "", projectDir: string = "", jsonOutput: bool = false): int =
  let root = if projectDir.len > 0: findProjectRoot(projectDir) else: findProjectRoot()
  let gardenDir = root / ".garden"
  let sessionFile = gardenDir / "session.json"
  let projName = if root.len > 0: root.splitPath.tail.toLowerAscii().replace(" ", "-") else: getCurrentDir().splitPath.tail.toLowerAscii().replace(" ", "-")

  case action.toLowerAscii()
  of "save", "set":
    createDir(gardenDir)
    var current = newJObject()
    if fileExists(sessionFile):
      try: current = parseJson(readFile(sessionFile)) except CatchableError: discard
    let effectiveAgent = if agentName.len > 0: agentName
                         elif current.hasKey("agent"): current["agent"].getStr()
                         else: getEnv("RHIZO_AGENT_NAME", "")
    let effectiveRole = if role.len > 0: role
                        elif current.hasKey("role"): current["role"].getStr()
                        else: "worker"
    let effectiveOrch = if orchestrator.len > 0: orchestrator
                        elif current.hasKey("orchestrator"): current["orchestrator"].getStr()
                        else: projName & "-orchestrator"
    let data = %*{
      "agent": effectiveAgent,
      "project": projName,
      "role": effectiveRole,
      "orchestrator": effectiveOrch,
      "workspace": root,
      "updated_at": now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    }
    writeFile(sessionFile, pretty(data))
    if jsonOutput:
      echo pretty(data)
    else:
      echo "[garden session] Saved active session state to " & sessionFile
    return 0

  of "load", "get", "show":
    if not fileExists(sessionFile):
      if jsonOutput:
        echo $(%*{"status": "error", "message": "No active session file found at " & sessionFile})
      else:
        stderr.writeLine("[garden session] No active session file found at " & sessionFile)
      return 1
    let content = readFile(sessionFile)
    if jsonOutput:
      echo content
    else:
      try:
        let j = parseJson(content)
        echo "Active Garden Session:"
        echo "  Agent       : @" & j.getOrDefault("agent").getStr("")
        echo "  Project     : " & j.getOrDefault("project").getStr("")
        echo "  Role        : " & j.getOrDefault("role").getStr("")
        echo "  Orchestrator: @" & j.getOrDefault("orchestrator").getStr("")
        echo "  Updated     : " & j.getOrDefault("updated_at").getStr("")
      except CatchableError:
        echo content
    return 0

  of "clear", "rm", "delete":
    if fileExists(sessionFile):
      try:
        removeFile(sessionFile)
        if jsonOutput:
          echo $(%*{"status": "ok", "message": "Cleared session file"})
        else:
          echo "[garden session] Cleared session file: " & sessionFile
      except CatchableError as e:
        stderr.writeLine("[garden session] Failed to remove session file: " & e.msg)
        return 1
    else:
      if jsonOutput:
        echo $(%*{"status": "ok", "message": "No session file to clear"})
      else:
        echo "[garden session] No session file to clear."
    return 0

  else:
    stderr.writeLine("[garden session] Error: Unknown session action '" & action & "'. Valid actions: save, load, clear.")
    return 1

proc doTeardown*(swarmFileParam: string): int =
  let root = findProjectRoot()

  # 1. Gracefully close registered agents in Redis
  var swarmFile = swarmFileParam
  if swarmFile.len == 0 and fileExists(root / "garden-swarm.json"):
    swarmFile = root / "garden-swarm.json"

  if swarmFile.len > 0 and fileExists(swarmFile):
    try:
      let sJson = parseJson(readFile(swarmFile))
      if sJson.hasKey("workers"):
        for w in sJson["workers"]:
          if w.hasKey("name"):
            let wname = w["name"].getStr()
            echo "[garden] Closing agent @" & wname & " in Redis..."
            discard execCmdEx("rhizo close " & quoteShell(wname))
    except CatchableError: discard
  else:
    # Default triad close with project prefix
    let proj = root.lastPathPart.toLowerAscii().replace(" ", "-")
    for role in ["architect", "auditor", "implementer"]:
      let wname = proj & "-" & role
      echo "[garden] Closing agent @" & wname & " in Redis..."
      discard execCmdEx("rhizo close " & quoteShell(wname))

  return 0

proc main() =
  let params = commandLineParams()
  if params.len == 0:
    printHelp()
    quit(0)

  let subcmd = params[0].toLowerAscii()

  case subcmd
  of "help", "-h", "--help":
    printHelp()
    quit(0)
  of "version", "-v", "--version":
    echo "garden v" & GardenVersion
    quit(0)
  of "init":
    var targetDir = ""
    var force = false
    var optOrchAgent = ""
    var i = 1
    while i < params.len:
      case params[i]
      of "--force", "-f": force = true
      of "--orchestrator", "-o", "--orchestrator-agent", "-a":
        inc i; if i < params.len: optOrchAgent = params[i]
      else:
        if targetDir.len == 0 and not params[i].startsWith("-"):
          targetDir = params[i]
      inc i
    quit(doInit(targetDir, force, optOrchAgent))
  of "prompts":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var targetWorker = ""
    var writeFileParam = ""
    var jsonOutput = false
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var optOrchAgent = ""
    var i = 1
    while i < params.len:
      case params[i]
      of "--swarm-file", "-f":
        inc i; if i < params.len: swarmFile = params[i]
      of "--worker", "-w":
        inc i; if i < params.len: targetWorker = params[i]
      of "--orchestrator", "-a", "--orchestrator-agent":
        inc i; if i < params.len: optOrchAgent = params[i]
      of "--write", "-o":
        if i + 1 < params.len and not params[i+1].startsWith("-"):
          inc i; writeFileParam = params[i]
        else:
          writeFileParam = "garden-prompts.md"
      of "--json":
        jsonOutput = true
      of "--project-dir", "-p":
        inc i; if i < params.len: projectDir = params[i]
      else: discard
      inc i
    quit(doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent))
  of "launch":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var targetWorker = ""
    var writeFileParam = ""
    var jsonOutput = false
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var optOrchAgent = ""
    var i = 1
    while i < params.len:
      case params[i]
      of "--swarm-file", "-f":
        inc i; if i < params.len: swarmFile = params[i]
      of "--worker", "-w":
        inc i; if i < params.len: targetWorker = params[i]
      of "--orchestrator", "-a", "--orchestrator-agent":
        inc i; if i < params.len: optOrchAgent = params[i]
      of "--write", "-o":
        if i + 1 < params.len and not params[i+1].startsWith("-"):
          inc i; writeFileParam = params[i]
        else:
          writeFileParam = "garden-prompts.md"
      of "--json":
        jsonOutput = true
      of "--project-dir", "-p":
        inc i; if i < params.len: projectDir = params[i]
      else: discard
      inc i
    quit(doLaunch(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent))
  of "status":
    var jsonOutput = false
    var i = 1
    while i < params.len:
      case params[i]
      of "--json": jsonOutput = true
      else: discard
      inc i
    quit(doStatus(jsonOutput))
  of "teardown":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var i = 1
    while i < params.len:
      case params[i]
      of "--swarm-file", "-f":
        inc i; if i < params.len: swarmFile = params[i]
      else: discard
      inc i
    quit(doTeardown(swarmFile))
  of "roster-guard", "validate-sender", "ingest-guard":
    var sender = ""
    var jsonOutput = false
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]: jsonOutput = true
      elif (a in ["--swarm-file", "-f"]) and i + 1 < params.len:
        inc i; swarmFile = params[i]
      elif a.startsWith("--swarm-file="): swarmFile = a[13..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="): projectDir = a[14..^1]
      elif not a.startsWith("-") and sender.len == 0:
        sender = a
      inc i
    if sender.len == 0:
      stderr.writeLine("Usage: garden roster-guard <sender> [--json] [--swarm-file <file>]")
      quit(1)
    quit(doRosterGuard(sender, jsonOutput, swarmFile, projectDir))
  of "session":
    if params.len < 2:
      stderr.writeLine("Usage: garden session <save|load|clear> [options...]")
      stderr.writeLine("  save   [--agent <name>] [--role <role>] [--orchestrator <orch>]")
      stderr.writeLine("  load   [--json]")
      stderr.writeLine("  clear  [--json]")
      quit(1)
    let action = params[1].toLowerAscii()
    var agentName = ""
    var role = ""
    var orch = ""
    var projectDir = ""
    var jsonOutput = false
    var i = 2
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]: jsonOutput = true
      elif (a in ["--agent", "-a"]) and i + 1 < params.len:
        inc i; agentName = params[i]
      elif a.startsWith("--agent="): agentName = a[8..^1]
      elif (a in ["--role", "-r"]) and i + 1 < params.len:
        inc i; role = params[i]
      elif a.startsWith("--role="): role = a[7..^1]
      elif (a in ["--orchestrator", "-o"]) and i + 1 < params.len:
        inc i; orch = params[i]
      elif a.startsWith("--orchestrator="): orch = a[15..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="): projectDir = a[14..^1]
      inc i
    quit(doSession(action, agentName, role, orch, projectDir, jsonOutput))
  of "guide":
    if params.len < 2:
      stderr.writeLine("Usage: garden guide <install|check|uninstall> [path]")
      quit(1)
    let action = params[1].toLowerAscii()
    let target = if params.len > 2: params[2] else: "AGENTS.md"
    case action
    of "install", "i", "add":
      let (ok, msg) = installGuide(target)
      if ok: echo msg else: (stderr.writeLine(msg); quit(1))
    of "uninstall", "u", "remove", "rm":
      let (ok, msg) = uninstallGuide(target)
      if ok: echo msg else: (stderr.writeLine(msg); quit(1))
    of "check", "status":
      let st = checkGuide(target)
      case st
      of gsInstalled: echo "[INSTALLED] Garden Guide is installed in: " & target
      of gsNotFound: echo "[NOT FOUND] Garden Guide not found in: " & target
      of gsMalformed: (stderr.writeLine("[MALFORMED] Unbalanced markers in: " & target); quit(1))
      of gsFileMissing: echo "[MISSING] Target file does not exist: " & target
    else:
      stderr.writeLine("Unknown guide action: " & action)
      quit(1)
  else:
    stderr.writeLine("Unknown subcommand: '" & subcmd & "'. Run 'garden --help' for usage.")
    quit(1)

when isMainModule:
  main()
