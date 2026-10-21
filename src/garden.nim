# /Users/eek/Development/garden/src/garden.nim
# The Garden Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, times, random]
import guide
import seed
import germinate
import update
import roadmap

const
  GardenVersion = "0.2.22"
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
  plant <title> [options]  Sow a new botanical task/roadmap seed into .garden/seeds/
  roadmap [options]        Generate structured roadmap (JSON, re-entrant Markdown, pre-commit sync)
  germinate <act> <seed>   Germinate a seed (dispatch, prompt, inline, status)
  prompts [options]        Generate copy-pasteable bootstrap prompts for worker sessions
  launch [options]         Bootstrap swarm worker sessions (generates prompts by default)
  status [options]         Unified cluster telemetry (Rhizo heartbeats, Vine strands)
  guide <action> [path]    Manage Garden Coordination Guide (install, check, uninstall)
  roster-guard <sender>    Validate inbound message sender against swarm roster
  session <action>         Manage compaction-immune session state (save, load, clear)
  update [options]         Manage Triad updates across Garden, Rhizo, and Vine
  teardown [options]       Gracefully close swarm agents in Redis
  version, -v, --version   Print Garden version and exit
  help, -h, --help         Print this help message

Options for 'roadmap':
  --season, -S <name>      Filter roadmap to specific season/milestone
  --json, -j               Output structured roadmap as JSON
  --markdown, -m           Print formatted markdown roadmap to stdout (default)
  --write, -w [path]       Write ROADMAP.md to project root or specified path
  --sync, -s               Synchronize .garden/roadmap.json and update ROADMAP.md
  --project-dir, -p <dir>  Target project directory

Options for 'update':
  --apply, -a              Install latest triad packages via npm
  --skip <pkg@version>     Skip notifications for a specific package version
  --disable, -d, --never   Disable triad update prompts completely
  --enable, -e             Enable daily triad update prompts
  --check, -c              Force a fresh network check immediately
  --json                   Output update status as JSON

Options for 'plant':
  --season <name>          Seasonal allocation (e.g. spring, summer, autumn, winter)
  --sunlight <level>       Priority sunlight requirement (low, medium, high, blazing)
  --tags <csv>             Comma-separated taxonomy tags
  --id <id>                Explicit custom seed identifier
  --project-dir, -p <dir>  Target project directory
  --list, -l               List all sown seeds
  --json                   Output result as structured JSON

Options for 'germinate':
  --worker, -w <name>      Filter prompt generation to target worker (for 'prompt')
  --inline, -i             Print raw 10-backtick prompt cards directly to stdout
  --project-dir, -p <dir>  Target project directory
  --json                   Output result as structured JSON

Options for 'prompts' and 'launch':
  --swarm-file, -f <file>  Path to garden-swarm.json manifest
  --worker, -w <name>      Filter prompt output to a specific worker
  --write, -o [file]       Write generated prompts to markdown file (default: garden-prompts.md)
  --inline, -i             Print raw 10-backtick prompt cards directly to stdout
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
       dirExists(dir / ".git") or
       fileExists(dir / ".git"):
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

const
  BotanicalPrefixes = [
    "Briar", "Bramble", "Thistle", "Moss", "Fern", "Sprout", "Lichen", "Mycelium",
    "Bark", "Clover", "Elder", "Willow", "Ivy", "Thicket", "Rowan", "Juniper",
    "Sedge", "Sorrel", "Hemlock", "Nettle", "Birch", "Cedar", "Alder", "Ash"
  ]
  ClockworkPrefixes = [
    "Cog", "Sprocket", "Piston", "Ratchet", "Gimbal", "Flywheel", "Cam", "Bushing",
    "Spindle", "Pendulum", "Gear", "Crank", "Pinion", "Governor", "Spring", "Bezel",
    "Dynamo", "Tappet", "Escapement", "Caliber", "Chrono", "Brass", "Copper", "Gilded"
  ]
  CryptidPrefixes = [
    "Astral", "Iron", "Obsidian", "Gargoyle", "Chimera", "Basilisk", "Gryphon", "Kraken",
    "Drake", "Salamander", "Wyrm", "Sphinx", "Hydra", "Golem", "Rook", "Valkyrie",
    "Shadow", "Cobalt", "Rune", "Thunder", "Frost", "Granite", "Echo", "Mantis"
  ]
  CosmicPrefixes = [
    "Nebula", "Pulsar", "Quasar", "Starlight", "Solar", "Lunar", "Zenith", "Aurora",
    "Comet", "Meteor", "Astro", "Orbit", "Eclipse", "Nova", "Vortex", "Corona",
    "Photon", "Parallax", "Spectral", "Cosmic", "Horizon", "Helios", "Astron", "Ray"
  ]

  ArchitectSuffixes = [
    "Weaver", "Mason", "Architect", "Surveyor", "Shaper", "Wright", "Cartographer",
    "Loom", "Foundry", "Matrix", "Compass", "Spire", "Arbor", "Beacon", "Strand"
  ]
  AuditorSuffixes = [
    "Warden", "Sentinel", "Gaze", "Skeptic", "Caliper", "Plumb", "Scales", "Gauge",
    "Watcher", "Judge", "Shield", "Anvil", "Lens", "Audit", "Pillar"
  ]
  ImplementerSuffixes = [
    "Smith", "Forge", "Spark", "Surge", "Drifter", "Carver", "Caster", "Joiner",
    "Striker", "Tender", "Runner", "Builder", "Crafter", "Darter", "Scraper"
  ]
  GeneralSuffixes = [
    "Spindle", "Wanderer", "Seeker", "Keeper", "Whisperer", "Harvester", "Ranger"
  ]

proc pickWhimsicalPersona*(roleKind: string, projName: string): string =
  randomize()
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
      [wtBotanical, wtClockwork, wtCryptid, wtCosmic][rand(3)]

  let prefix = case theme
    of wtBotanical: BotanicalPrefixes[rand(BotanicalPrefixes.high)]
    of wtClockwork: ClockworkPrefixes[rand(ClockworkPrefixes.high)]
    of wtCryptid:   CryptidPrefixes[rand(CryptidPrefixes.high)]
    of wtCosmic:    CosmicPrefixes[rand(CosmicPrefixes.high)]

  let rk = roleKind.toLowerAscii()
  let suffix =
    if rk.contains("architect") or rk.contains("systems"):
      ArchitectSuffixes[rand(ArchitectSuffixes.high)]
    elif rk.contains("audit") or rk.contains("qa") or rk.contains("verifier"):
      AuditorSuffixes[rand(AuditorSuffixes.high)]
    elif rk.contains("impl") or rk.contains("dev"):
      ImplementerSuffixes[rand(ImplementerSuffixes.high)]
    else:
      GeneralSuffixes[rand(GeneralSuffixes.high)]

  result = prefix & "-" & suffix

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
      systemPrompt: "You are " & auditPersona & ", Verification & Adversarial Auditor for the " & projName & " project. Your mandate is zero-tolerance for green mirages, unverified assertions, dead code, shelfware, or untested branches. You are the INDEPENDENT AUDITOR responsible for Key 3 of the Three-Key Gate. Workers submit their strands to you via 'vine submit'. You audit their strands under the presumption of guilt using the Five Pillars: 1) Closed-Circuit Two-Point Diff, 2) Holistic Integration, 3) Literal Fidelity & Parity, 4) Replacement Purge, 5) Structural Assertion Rigor. If defects are found, reject with 'vine audit reject <strand> --auditor " & auditName & " --reason <reason>'. When 0 defects remain and tests pass, ratify approval with 'vine audit approve <strand> --auditor " & auditName & "'. YOU NEVER AUDIT YOUR OWN WORK. Assume all code is broken until proven sound by empirical test runs. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & ").",
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
      systemPrompt: "You are " & implPersona & ", DevEx & Implementation Lead for the " & projName & " project. Your mandate is pragmatic, clean, high-velocity implementation in isolated Vine strands. You execute tasks assigned by @" & result.orchestrator & ", maintain ergonomic developer workflows, verify Keys 1 & 2 with 'vine gate', submit for independent audit with 'vine submit', and report completed deliverables back over Rhizo. Remember: THE WORKER IS NOT THE AUDITOR; never attempt to self-audit.",
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
    try:
      let res = execCmdEx(cmd)
      if res.exitCode == 0:
        if not quiet:
          echo "[garden] Auto-registered alias in Rhizo: @" & cfg.orchestrator & " -> @" & cfg.orchestratorAgent
      else:
        if not quiet:
          stderr.writeLine("[garden] Warning: Failed to auto-register alias in Rhizo: " & res.output.strip())
    except CatchableError as e:
      if not quiet:
        stderr.writeLine("[garden] Warning: Could not invoke rhizo to register alias: " & e.msg)

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
  result &= "Execute these shell commands right now in your VERY FIRST tool turn to register, announce arrival, and arm:\n\n"
  result &= "```bash\n"
  result &= "cd \"" & cfg.targetRepo & "\"\n"
  result &= "export RHIZO_AGENT_NAME=\"" & w.name & "\"\n"
  result &= "rhizo open \"" & w.name & "\" \"" & tagsStr & "\"\n"
  result &= "# If running in Codex, install turn-end Stop hook interlock:\n"
  result &= "rhizo hook install --codex --agent \"" & w.name & "\"\n\n"
  result &= "# 1. Broadcast Mutual Arrival Handshake (WAKES orchestrator if idle):\n"
  result &= "rhizo send --to \"" & cfg.orchestrator & "\" --subject \"WORKER_READY\" --body \"Worker @" & w.name & " (" & w.persona & " - " & w.role & ") initialized. Standing by for sprint assignment.\"\n\n"
  result &= "# 2. Arm single-shot listener for incoming directives:\n"
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
  result &= "   - IMMEDIATE ACK & RE-ARM UPON RECEIPT: Immediately claim the task ('rhizo task claim <id> --lease 900' or send a quick ACK reply to @" & cfg.orchestrator & " WITHOUT --listen). In Tier 2 async harnesses (e.g. Antigravity), immediately launch 'rhizo listen " & w.name & "' in the background (`run_command(WaitMsBeforeAsync=500)`).\n"
  result &= "   - MANDATORY ANTIGRAVITY NON-YIELD INVARIANT: When launching your background listener, your harness will say: 'YOU MUST TAKE ONE OF THE FOLLOWING TWO ACTIONS: A) either proceed to other relevant work or B) simply update the user and end the turn. DO NOTHING ELSE.' YOU MUST ALWAYS CHOOSE (A) PROCEED TO OTHER RELEVANT WORK! Never pick (B) or end the turn. Continue implementing, committing, and running tests in this exact turn!\n"
  result &= "   - PERIODIC PROGRESS TELEMETRY: During long multi-step tasks (>2 minutes, e.g. Playwright E2E or full builds), run `rhizo task progress <id> \"Step X/Y: ...\"` before/after major steps to refresh your in-flight task lease and heartbeat.\n"
  result &= "   - Before concluding your turn, ensure your single-shot listener ('rhizo listen " & w.name & "') is armed or use 'rhizo reply ... --listen' when sending your completion report.\n"
  result &= "</CRITICAL>\n\n"

  result &= "### 4. Listener Discipline & Coordination Invariants\n"
  result &= "<CRITICAL>\n"
  result &= "- Single-Shot Blocking: 'rhizo listen " & w.name & "' blocks until a message arrives, then exits immediately.\n"
  result &= "- Infinite Wait: Always run 'rhizo listen' with zero timeout (never use bounded timeouts, which cause token-thrashing empty wakeups).\n"
  result &= "- Anti-Premature-Yield: NEVER pass --listen on initial CLAIM or ACK replies. Only pass --listen (or arm your listener) on your final completion / READY_FOR_WEAVE reply.\n"
  result &= "- FORBIDDEN: NEVER wrap 'rhizo listen' in a shell loop (`while true; do rhizo listen; done` or `until rhizo listen; do ...`). Loops trap messages inside unmonitored subshell logs and hang coordination.\n"
  result &= "- Re-arming: In Tier 2 async harnesses (Antigravity), re-arm 'rhizo listen " & w.name & "' (`WaitMsBeforeAsync=500`) immediately upon task receipt so you remain reachable during multi-file edits. Always verify it is armed before ending any turn.\n"
  result &= "</CRITICAL>\n\n"
  
  result &= "### 5. Task Execution & Workspace Protocol\n"
  result &= "- **Claiming & Progress Telemetry**:\n"
  result &= "  - From a work queue: `rhizo claim queue:" & cfg.project & ":tasks --lease 300`\n"
  result &= "  - Direct task claim & lease extension: `rhizo task claim <task_id> --lease 900`\n"
  result &= "  - In-flight progress heartbeat (>2m tasks): `rhizo task progress <task_id> \"Step X/Y: Running E2E...\"`\n"
  result &= "- **Distributed Locks**: If modifying shared resources, acquire a fencing token first:\n"
  result &= "  `rhizo lock <resource> --fencing`\n"
  result &= "- **Isolated Workspaces (Vine Strands)**:\n"
  result &= "  Always isolate task changes inside a dedicated Vine strand:\n"
  result &= "  `vine new <task_id>`\n"
  result &= "- **Pre-Weave Changelog Discipline**:\n"
  result &= "  If the project has a changelog (CHANGELOG.md), record your user-facing changes under '## [Unreleased]':\n"
  result &= "  `vine changelog \"Description of changes\"` (or `vine changelog --ensure-unreleased`)\n"
  result &= "- **Verification & Three-Key Gate Protocol**:\n"
  result &= "  Verify before reporting completion with Keys 1 & 2 of the Three-Key Gate (verifies mergeability, tests, and changelog update):\n"
  result &= "  `vine gate`\n"
  result &= "- **THE WORKER IS NOT THE AUDITOR INVARIANT (MANDATORY)**:\n"
  result &= "  <CRITICAL>\n"
  result &= "  YOU ARE NOT THE AUDITOR. An implementer or worker MUST NEVER attempt to audit or approve their own strand ('vine audit approve' on your own strand will fail with Exit Code 6: Self-audit violation). The Key 3 Adversarial Audit MUST be performed by an independent Adversarial Auditor session created by the Orchestrator.\n"
  result &= "  Once your tests and changelog pass, submit your strand for independent audit with `vine submit` (or `vine gate --submit`), notify the Orchestrator (@" & cfg.orchestrator & "), and await the auditor's review.\n"
  result &= "  If the auditor rejects your strand ('AUDIT_REJECTED'), inspect the findings, fix them in your strand, and re-submit with `vine submit`.\n"
  result &= "  </CRITICAL>\n"
  result &= "- **Reporting & Acknowledging**:\n"
  result &= "  Send status updates or gate reports back to the Orchestrator:\n"
  result &= "  `rhizo ack queue:" & cfg.project & ":tasks <task_id>`\n\n"

  if w.name.toLowerAscii.contains("audit") or w.role.toLowerAscii.contains("audit"):
    result &= "### 5b. Key 3 Adversarial Auditor Protocol (YOUR PRIMARY MANDATE)\n"
    result &= "<CRITICAL>\n"
    result &= "YOU ARE THE DESIGNATED ADVERSARIAL AUDITOR. You enforce Key 3 of the Three-Key Gate.\n"
    result &= "- When a worker submits a strand (`vine submit`), inspect their strand directory under the presumption of guilt.\n"
    result &= "- Verify the Five Pillars:\n"
    result &= "  1. Closed-Circuit Two-Point Diff: Provider wired to real Consumer call-site.\n"
    result &= "  2. Holistic Integration: Real errors and application state handled (no hollow stubs/toys).\n"
    result &= "  3. Literal Fidelity & Parity: Exact implementation of the specification (zero loose approximations).\n"
    result &= "  4. Replacement Purge: All legacy or obsolete code targeted for replacement is deleted.\n"
    result &= "  5. Structural Assertion Rigor: Tests assert full structural equality with negative controls.\n"
    result &= "- IF DEFECTS FOUND: Reject the strand with detailed actionable feedback:\n"
    result &= "  `vine audit reject <strand_path> --auditor \"" & w.name & "\" --reason \"<findings>\"`\n"
    result &= "- IF 100% SOUND & CLEAN: Ratify approval and generate cryptographic audit token:\n"
    result &= "  `vine audit approve <strand_path> --auditor \"" & w.name & "\" --notes \"<notes>\"`\n"
    result &= "- SELF-AUDIT IS STRICTLY FORBIDDEN: You must never audit or approve your own strand.\n"
    result &= "</CRITICAL>\n\n"

  result &= "### 6. Closed-Circuit & Holistic Integration Invariant (No Shelfware / No Stubs)\n"
  result &= "<CRITICAL>\n"
  result &= "- Two-Point Diff Mandate: Never build isolated code in a vacuum. Every deliverable must exhibit a Two-Point Diff: the Provider (new capability) and the Consumer (live production call-site, router, UI canvas, or CLI entrypoint). Code tested only by its own unit tests is strictly prohibited as incomplete shelfware.\n"
  result &= "- Holistic Integration (No Stubs / No Toys): The producer and consumer must actually holistically integrate with the system. It must NOT be a toy, stub, mock, or heuristic approximation of the feature. It must handle real application state, live events, and production errors.\n"
  result &= "- Aggressive Replacement Purge (Zero Dead Code): Any existing code, configurations, or fallbacks that your feature is intended to replace or upgrade MUST BE DELETED in the same strand. Do not preserve obsolete logic as a fallback, and do not leave commented-out shims in the codebase.\n"
  result &= "</CRITICAL>\n\n"

  result &= "### 7. Scheduled Watchdog & Health Check Protocol (ONLY for OpenAI Codex / ChatGPT CLI)\n"
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
  
  result &= "### 8. Compaction State Rider\n"
  result &= "Whenever context summarization or compaction occurs, preserve this block verbatim:\n"
  result &= "<!-- SWARM_RUNTIME_STATE: DO NOT DISCARD OR ABBREVIATE IN COMPACTION -->\n"
  result &= "- AGENT_NAME: " & w.name & " (Role: " & w.role & ")\n"
  result &= "- ORCHESTRATOR: @" & cfg.orchestrator & "\n"
  result &= "- TARGET_REPO: " & cfg.targetRepo & "\n"
  result &= "<!-- END_SWARM_RUNTIME_STATE -->\n"

proc getGardenTempDir*(projectName: string): string =
  let base = if dirExists("/tmp"): "/tmp" else: getTempDir()
  result = base / ("garden-" & projectName)
  createDir(result)

type ClusterWorkerInfo = object
  agent: string
  project: string
  status: string
  listener: string
  state: string

proc queryClusterAgents(): seq[ClusterWorkerInfo] =
  var res: seq[ClusterWorkerInfo] = @[]
  if findExe("rhizo").len > 0:
    try:
      let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let trimmed = whoOut.strip()
        var parsedList: JsonNode = nil
        if trimmed.startsWith("["):
          parsedList = parseJson(trimmed)
        elif trimmed.startsWith("{"):
          let obj = parseJson(trimmed)
          if obj.hasKey("agents") and obj["agents"].kind == JArray:
            parsedList = obj["agents"]
        if not parsedList.isNil and parsedList.kind == JArray:
          for item in parsedList:
            let ag = if item.hasKey("agent"): item["agent"].getStr() elif item.hasKey("name"): item["name"].getStr() else: ""
            let proj = item.getOrDefault("project").getStr("")
            let st = item.getOrDefault("status").getStr("")
            let lis = item.getOrDefault("listener").getStr("")
            let state = item.getOrDefault("state").getStr("")
            if ag.len > 0:
              res.add(ClusterWorkerInfo(agent: ag, project: proj, status: st, listener: lis, state: state))
    except CatchableError: discard
  return res

proc doPrompts*(
  projectDir: string,
  swarmFile: string,
  targetWorker: string,
  writeFileParam: string,
  jsonOutput: bool,
  optOrchAgent: string = "",
  inlineOutput: bool = false
): int =
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

  let clusterAgents = queryClusterAgents()
  var alreadyListening: seq[string] = @[]
  var idleClusterPeers: seq[string] = @[]
  for ca in clusterAgents:
    if ca.listener.toUpperAscii() == "LISTENING":
      for w in selectedWorkers:
        if ca.agent.toLowerAscii() == w.name.toLowerAscii():
          alreadyListening.add(w.name)
      if ca.project.toLowerAscii() != cfg.project.toLowerAscii() and (ca.state.toUpperAscii().startsWith("IDLE") or ca.state.len == 0):
        idleClusterPeers.add(ca.agent)

  let tempBaseDir = getGardenTempDir(cfg.project)
  let allWorkersFilePath = tempBaseDir / "all-workers.md"

  type GeneratedCard = object
    worker: WorkerSpec
    filePath: string
    copyCmd: string
    promptText: string
    promptBlock: string
    header: string
    subheader: string

  var generatedCards: seq[GeneratedCard] = @[]
  var allWorkersBuf = "# Garden Swarm Bootstrap Prompts: " & cfg.project & "\n\n"
  allWorkersBuf &= "> Generated by Garden v" & GardenVersion & "\n"
  allWorkersBuf &= "> Stored in: " & tempBaseDir & "\n\n"

  for idx, w in selectedWorkers:
    let promptText = generateWorkerPrompt(cfg, w)
    let header = "--- WORKER " & $(idx + 1) & " of " & $selectedWorkers.len & ": @" & w.name & " (" & w.persona & " - " & w.role & ") ---"
    let subheader = "Recommended Harness: " & w.harness & " | Model: " & w.model
    let promptBlock = PromptFence10 & "markdown\n" & promptText & "\n" & PromptFence10 & "\n"
    
    let workerFilePath = tempBaseDir / (w.name & ".md")
    writeFile(workerFilePath, promptText)

    allWorkersBuf &= "## " & header & "\n\n"
    allWorkersBuf &= "**" & subheader & "**\n\n"
    allWorkersBuf &= promptBlock & "\n\n"

    generatedCards.add(GeneratedCard(
      worker: w,
      filePath: workerFilePath,
      copyCmd: getCopyCommand(workerFilePath),
      promptText: promptText,
      promptBlock: promptBlock,
      header: header,
      subheader: subheader
    ))

  writeFile(allWorkersFilePath, allWorkersBuf)

  if writeFileParam.len > 0:
    let outPath = if isAbsolute(writeFileParam): writeFileParam else: cfg.targetRepo / writeFileParam
    writeFile(outPath, allWorkersBuf)
    echo "[garden] Prompts successfully written to: " & outPath

  if jsonOutput:
    var jObj = newJObject()
    jObj["project"] = %cfg.project
    jObj["target_repo"] = %cfg.targetRepo
    jObj["orchestrator"] = %cfg.orchestrator
    if cfg.orchestratorAgent.len > 0:
      jObj["orchestrator_agent"] = %cfg.orchestratorAgent
    jObj["count"] = %selectedWorkers.len
    jObj["temp_dir"] = %tempBaseDir
    jObj["all_file_path"] = %allWorkersFilePath
    jObj["already_listening"] = %alreadyListening
    jObj["idle_cluster_peers"] = %idleClusterPeers
    var jPrompts = newJArray()
    for card in generatedCards:
      var jw = newJObject()
      jw["name"] = %card.worker.name
      jw["persona"] = %card.worker.persona
      jw["role"] = %card.worker.role
      jw["harness"] = %card.worker.harness
      jw["model"] = %card.worker.model
      jw["tags"] = %card.worker.tags
      jw["file_path"] = %card.filePath
      jw["copy_command"] = %card.copyCmd
      jw["prompt"] = %card.promptText
      jPrompts.add(jw)
    jObj["workers"] = jPrompts
    echo pretty(jObj)
    return 0

  if inlineOutput:
    echo "================================================================================"
    echo "  GARDEN SWARM BOOTSTRAP: " & cfg.project
    echo "================================================================================"
    echo "Generated " & $selectedWorkers.len & " worker bootstrap prompt(s)."
    echo "Copy and paste each prompt block below into a separate session"
    echo "(Claude Code CLI, OpenCode, Antigravity, Pi, etc.)."
    echo ""
    if alreadyListening.len > 0:
      echo "  ACTIVE & LISTENING WORKERS IN THIS PROJECT (No Prompt Paste Needed!):"
      for al in alreadyListening:
        echo "    - @" & al & " is ALREADY active and listening"
      echo ""
    if idleClusterPeers.len > 0:
      echo "  AVAILABLE IDLE CLUSTER WORKERS (Can be repurposed without opening new tabs):"
      for ip in idleClusterPeers:
        echo "    - @" & ip & " (repurpose via: rhizo reassign " & ip & " --project " & cfg.project & " --role <role>)"
      echo ""
    echo "Once pasted, verify cluster registration readiness with:"
    echo "  rhizo who"
    echo ""
    echo "CRITICAL ORCHESTRATOR MANDATE:"
    echo "  You MUST arm your background listener NOW in this very turn before yielding:"
    echo "    rhizo listen " & cfg.orchestrator
    echo "  As soon as workers are pasted (or re-tagged), their WORKER_READY handshake will wake you!"
    echo "================================================================================\n"

    for card in generatedCards:
      echo "================================================================================"
      echo card.header
      echo card.subheader
      echo "--------------------------------------------------------------------------------"
      echo card.promptBlock
      echo "================================================================================\n"
  else:
    echo "================================================================================"
    echo "  GARDEN SWARM BOOTSTRAP: " & cfg.project
    echo "================================================================================"
    echo "Generated " & $selectedWorkers.len & " worker bootstrap prompt card(s) in:"
    echo "  " & tempBaseDir & "/"
    echo ""
    for idx, card in generatedCards:
      let w = card.worker
      echo "  " & $(idx + 1) & ". @" & w.name & " (" & w.persona & " - " & w.role & ")"
      echo "     Harness:      " & w.harness & " | Model: " & w.model
      echo "     Prompt File:  " & card.filePath
      echo "     Copy Command: " & card.copyCmd
      echo ""
    echo "  All Cards Combined:"
    echo "     File: " & allWorkersFilePath
    echo ""
    if alreadyListening.len > 0:
      echo "  Active & Listening in Project (No Prompt Paste Needed!):"
      for al in alreadyListening:
        echo "    - @" & al & " (ALREADY LISTENING)"
      echo ""
    if idleClusterPeers.len > 0:
      echo "  Available Idle Cluster Workers (Can be repurposed without opening new tabs):"
      for ip in idleClusterPeers:
        echo "    - @" & ip & " (Run: rhizo reassign " & ip & " --project " & cfg.project & " --role <role>)"
      echo ""
    echo "Instructions for operator:"
    echo "  1. Open a new terminal tab / session for each worker in your detected harness."
    echo "  2. Copy each prompt card (using the copy command above or opening the file)."
    echo "  3. Paste into the corresponding session."
    echo "  4. Verify cluster registration: rhizo who"
    echo ""
    echo "CRITICAL ORCHESTRATOR MANDATE:"
    echo "  You MUST arm your background listener NOW in this very turn before yielding:"
    echo "    rhizo listen " & cfg.orchestrator
    echo "  As soon as workers are pasted (or re-tagged), their WORKER_READY handshake will wake you!"
    echo "================================================================================"

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
    try:
      let res = execCmdEx(cmd)
      if res.exitCode == 0:
        echo "[garden] Auto-registered alias in Rhizo: @" & defaultOrch & " -> @" & actualAgent
    except CatchableError:
      discard

  echo "[garden] Initialization complete for " & root
  return 0

proc doLaunch*(projectDir: string, swarmFile: string, targetWorker: string, writeFileParam: string, jsonOutput: bool, optOrchAgent: string = "", inlineOutput: bool = false): int =
  return doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput)

proc doStatus*(jsonOutput: bool): int =
  try:
    let root = findProjectRoot()
    let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")

    var statusObj = newJObject()
    statusObj["project"] = %root

    # 1. Query Rhizo heartbeats via 'rhizo who --json'
    try:
      let (rhizoOut, rhizoCode) = execCmdEx("rhizo who --json")
      let trimmed = rhizoOut.strip()
      if rhizoCode == 0 and (trimmed.startsWith("{") or trimmed.startsWith("[")):
        statusObj["rhizo"] = parseJson(trimmed)
      else:
        statusObj["rhizo"] = newJNull()
    except CatchableError:
      statusObj["rhizo"] = newJNull()

    # 2. Query Vine active strands via 'vine list'
    try:
      let (vineOut, vineCode) = execCmdEx("vine list")
      let trimmed = vineOut.strip()
      if vineCode == 0 and (trimmed.startsWith("{") or trimmed.startsWith("[")):
        statusObj["vine_strands"] = parseJson(trimmed)
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

      var agents: JsonNode = nil
      if not statusObj["rhizo"].isNil:
        if statusObj["rhizo"].kind == JArray:
          agents = statusObj["rhizo"]
        elif statusObj["rhizo"].kind == JObject and statusObj["rhizo"].hasKey("agents") and statusObj["rhizo"]["agents"].kind == JArray:
          agents = statusObj["rhizo"]["agents"]

      if not agents.isNil and agents.len > 0:
        echo "\nRhizo Agents Online (" & $agents.len & "):"
        for a in agents:
          let aname = if a.hasKey("agent"): a["agent"].getStr() elif a.hasKey("name"): a["name"].getStr() else: "unknown"
          let astatus = if a.hasKey("status"): a["status"].getStr() else: "ACTIVE"
          let astate = if a.hasKey("state"): a["state"].getStr() else: "active"
          let alistener = if a.hasKey("listener"): a["listener"].getStr() else: ""
          var atags = ""
          if a.hasKey("tags"):
            if a["tags"].kind == JArray:
              var tList: seq[string] = @[]
              for t in a["tags"]:
                tList.add(t.getStr())
              atags = tList.join(", ")
            elif a["tags"].kind == JString:
              atags = a["tags"].getStr()

          var parts: seq[string] = @[astate]
          if alistener.len > 0:
            parts.add(alistener.toLowerAscii())
          if astatus.len > 0 and astatus.toUpperAscii() != "ACTIVE":
            parts.add(astatus.toLowerAscii())

          let infoStr = parts.join(" | ")
          let tagStr = if atags.len > 0: " tags: " & atags else: ""
          echo "  @" & aname & " [" & infoStr & "]" & tagStr
      elif not agents.isNil and agents.len == 0:
        echo "\nRhizo Agents Online (0): None"

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

proc doRosterGuard*(sender: string, jsonOutput: bool = false, swarmFile: string = "", projectDir: string = "", fix: bool = false): int =
  let cfg = loadSwarmConfig(projectDir, swarmFile)
  let normSender = sender.toLowerAscii.strip()

  if normSender.len > 0 and normSender != "audit":
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

  # Cluster audit mode: query active Redis cluster agents via rhizo who --json
  var aliens: seq[string] = @[]
  var verified: seq[string] = @[]
  var quarantined: seq[string] = @[]

  if findExe("rhizo").len > 0:
    try:
      let (whoOut, whoCode) = execCmdEx("rhizo who --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let trimmed = whoOut.strip()
        var parsedList: JsonNode = nil
        if trimmed.startsWith("["):
          parsedList = parseJson(trimmed)
        elif trimmed.startsWith("{"):
          let obj = parseJson(trimmed)
          if obj.hasKey("agents") and obj["agents"].kind == JArray:
            parsedList = obj["agents"]

        if not parsedList.isNil and parsedList.kind == JArray:
          for item in parsedList:
            let ag = if item.hasKey("agent"): item["agent"].getStr() elif item.hasKey("name"): item["name"].getStr() else: ""
            if ag.len == 0: continue
            if validateRosterSender(cfg, ag):
              verified.add(ag)
            else:
              aliens.add(ag)
              if fix:
                let (_, cCode) = execCmdEx("rhizo close " & quoteShell(ag))
                if cCode == 0:
                  quarantined.add(ag)
    except CatchableError:
      discard

  if jsonOutput:
    var jObj = %*{
      "project": cfg.project,
      "audit": "ROSTER_AUDIT",
      "verified_count": verified.len,
      "alien_count": aliens.len,
      "verified": verified,
      "aliens": aliens
    }
    if fix:
      jObj["quarantined"] = %quarantined
    echo pretty(jObj)
  else:
    echo "=========================================================="
    echo "  Garden Swarm Roster Audit: " & cfg.project
    echo "=========================================================="
    echo "Verified Swarm Members (" & $verified.len & "):"
    for v in verified:
      echo "  ✓ @" & v
    if aliens.len > 0:
      echo "\nAlien / Unauthorized Agents (" & $aliens.len & "):"
      for a in aliens:
        let qStatus = if a in quarantined: " [QUARANTINED/CLOSED]" else: " [UNAUTHORIZED]"
        echo "  ✗ @" & a & qStatus
      if not fix:
        echo "\nRun 'garden roster-guard --fix' to close unauthorized agents."
    else:
      echo "\nNo alien agents detected. Cluster roster 100% clean."
    echo "=========================================================="

  if aliens.len > 0 and not fix:
    return 1
  return 0

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
      try:
        discard execCmdEx("rhizo close " & quoteShell(wname))
      except CatchableError:
        discard

  return 0

proc doPlant*(
  title: string,
  season: string,
  sunlight: string,
  tagsCsv: string,
  customId: string,
  projectDir: string,
  listMode: bool,
  jsonOutput: bool
): int =
  let root = if projectDir.len > 0: projectDir else: findProjectRoot()

  if listMode:
    let seeds = listSeeds(root)
    if jsonOutput:
      var jArr = newJArray()
      for s in seeds:
        jArr.add(s.toJson())
      echo pretty(jArr)
    else:
      if seeds.len == 0:
        echo "[garden plant] No seeds sown yet in " & root / ".garden" / "seeds"
      else:
        echo "=========================================================="
        echo "  Garden Sown Seeds (" & $seeds.len & ")"
        echo "=========================================================="
        for s in seeds:
          echo "- [" & s.status & "] " & s.title & " (" & s.id & ")"
          echo "    Season: " & s.season & " | Sunlight: " & s.sunlight & " | Tags: " & s.tags.join(", ")
          echo "    File:   " & s.filePath
    return 0

  if title.strip().len == 0:
    stderr.writeLine("Usage: garden plant <title> [--season <name>] [--sunlight <low|medium|high|blazing>] [--tags <csv>] [--json]")
    return 1

  let normSunlight = sunlight.toLowerAscii().strip()
  if sunlight.len > 0 and not isValidSunlight(normSunlight):
    stderr.writeLine("[garden] Error: Invalid sunlight level '" & sunlight & "'. Valid levels: low, medium, high, blazing.")
    return 1

  var tags: seq[string] = @[]
  if tagsCsv.len > 0:
    for t in tagsCsv.split(','):
      let trimmed = t.strip()
      if trimmed.len > 0:
        tags.add(trimmed)

  try:
    let seed = plantSeed(
      title = title,
      projectRoot = root,
      season = if season.len > 0: season else: "spring",
      sunlight = if normSunlight.len > 0: normSunlight else: "medium",
      tags = tags,
      customId = customId
    )

    if jsonOutput:
      echo pretty(seed.toJson())
    else:
      echo "[garden] Sowed seed '" & seed.title & "' (" & seed.id & ")"
      echo "  Status:   " & seed.status
      echo "  Season:   " & seed.season
      echo "  Sunlight: " & seed.sunlight
      if seed.tags.len > 0:
        echo "  Tags:     " & seed.tags.join(", ")
      echo "  File:     " & seed.filePath

    # Auto-sync .garden/roadmap.json and update ROADMAP.md if present
    try:
      let rm = buildRoadmap(root)
      discard saveRoadmap(rm, root, writeMarkdown = fileExists(root / "ROADMAP.md"))
    except CatchableError:
      discard

    return 0
  except CatchableError as e:
    stderr.writeLine("[garden] Error planting seed: " & e.msg)
    return 1

proc doRoadmap*(season: string = "", projectDir: string = "", jsonOutput: bool = false,
                writeMarkdown: bool = false, markdownPath: string = ""): int =
  let root = if projectDir.len > 0: projectDir else: findProjectRoot()
  let rm = buildRoadmap(root, season)

  # Always persist structured JSON to .garden/roadmap.json
  let (jsonPath, mdPath) = saveRoadmap(rm, root, writeMarkdown = writeMarkdown, markdownPath = markdownPath)

  if jsonOutput:
    echo pretty(rm.toJson())
  elif writeMarkdown:
    echo "[garden roadmap] Persisted roadmap JSON to " & jsonPath
    echo "[garden roadmap] Wrote re-entrant Markdown roadmap to " & mdPath
  else:
    echo rm.toMarkdown()
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
  of "plant":
    var title = ""
    var season = ""
    var sunlight = ""
    var tagsCsv = ""
    var customId = ""
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var listMode = false
    var jsonOutput = false
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--list", "-l"]:
        listMode = true
      elif (a in ["--season", "-s"]) and i + 1 < params.len:
        inc i; season = params[i]
      elif a.startsWith("--season="):
        season = a[9..^1]
      elif (a in ["--sunlight", "-S"]) and i + 1 < params.len:
        inc i; sunlight = params[i]
      elif a.startsWith("--sunlight="):
        sunlight = a[11..^1]
      elif (a in ["--tags", "-t"]) and i + 1 < params.len:
        inc i; tagsCsv = params[i]
      elif a.startsWith("--tags="):
        tagsCsv = a[7..^1]
      elif a in ["--id"] and i + 1 < params.len:
        inc i; customId = params[i]
      elif a.startsWith("--id="):
        customId = a[5..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif not a.startsWith("-"):
        if title.len == 0:
          title = a
        else:
          title &= " " & a
      inc i
    quit(doPlant(title, season, sunlight, tagsCsv, customId, projectDir, listMode, jsonOutput))
  of "roadmap":
    var season = ""
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var jsonOutput = false
    var writeMarkdown = false
    var markdownPath = ""
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--write", "-w"]:
        writeMarkdown = true
        if i + 1 < params.len and not params[i + 1].startsWith("-"):
          inc i; markdownPath = params[i]
      elif a.startsWith("--write="):
        writeMarkdown = true
        markdownPath = a[8..^1]
      elif a in ["--sync", "-s"]:
        writeMarkdown = true
      elif (a in ["--season", "-S"]) and i + 1 < params.len:
        inc i; season = params[i]
      elif a.startsWith("--season="):
        season = a[9..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif a in ["--markdown", "-m"]:
        writeMarkdown = false
      inc i
    quit(doRoadmap(season, projectDir, jsonOutput, writeMarkdown, markdownPath))
  of "germinate":
    if params.len < 2:
      stderr.writeLine("Usage: garden germinate <dispatch|prompt|inline|status> <seed_id> [options...]")
      quit(1)
    let action = params[1].toLowerAscii()
    var seedId = ""
    var targetWorker = ""
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var jsonOutput = false
    var inlineOutput = false
    var i = 2
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--inline", "-i"]:
        inlineOutput = true
      elif (a in ["--worker", "-w"]) and i + 1 < params.len:
        inc i; targetWorker = params[i]
      elif a.startsWith("--worker="):
        targetWorker = a[9..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif not a.startsWith("-") and seedId.len == 0:
        seedId = a
      inc i

    if seedId.len == 0 and action in ["dispatch", "prompt", "inline", "status"]:
      stderr.writeLine("Usage: garden germinate " & action & " <seed_id> [options...]")
      quit(1)

    quit(doGerminate(action, seedId, targetWorker, projectDir, jsonOutput, inlineOutput))
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
    var inlineOutput = false
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
      of "--inline", "-i":
        inlineOutput = true
      of "--project-dir", "-p":
        inc i; if i < params.len: projectDir = params[i]
      else: discard
      inc i
    quit(doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput))
  of "launch":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var targetWorker = ""
    var writeFileParam = ""
    var jsonOutput = false
    var inlineOutput = false
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
      of "--inline", "-i":
        inlineOutput = true
      of "--project-dir", "-p":
        inc i; if i < params.len: projectDir = params[i]
      else: discard
      inc i
    quit(doLaunch(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput))
  of "status":
    var jsonOutput = false
    var i = 1
    while i < params.len:
      case params[i]
      of "--json": jsonOutput = true
      else: discard
      inc i
    let code = doStatus(jsonOutput)
    if not jsonOutput:
      let rider = getUpdatePromptRider(GardenVersion)
      if rider.len > 0:
        echo "\n" & rider
    quit(code)
  of "update", "upgrade":
    let code = doUpdateCommand(params[1..^1], GardenVersion)
    quit(code)
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
    var fix = false
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--json", "-j"]: jsonOutput = true
      elif a in ["--fix", "-F"]: fix = true
      elif a in ["--audit", "-a"]: discard
      elif (a in ["--swarm-file", "-f"]) and i + 1 < params.len:
        inc i; swarmFile = params[i]
      elif a.startsWith("--swarm-file="): swarmFile = a[13..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="): projectDir = a[14..^1]
      elif not a.startsWith("-") and sender.len == 0:
        sender = a
      inc i
    quit(doRosterGuard(sender, jsonOutput, swarmFile, projectDir, fix))
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
