# /Users/eek/Development/garden/src/garden.nim
# The Garden Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, times, random]
import guide
import seed
import germinate
import update
import roadmap

when defined(inProcessTest):
  template quit(code: int = 0) = testQuit(code)

const
  GardenVersion = "0.2.30"
  DefaultConfigFileName = "garden.toml"
  PromptFence10 = "``````````"

type
  WorkerProfile* = enum
    wpImplementation, wpInvestigation, wpVerification, wpAudit

  HarnessType* = enum
    htAntigravity, htClaudeCode, htCodex, htOpenCode, htPi, htGeneric

  WorkerExecutionMode* = enum
    wemAuto, wemSubagents, wemTmux, wemPrompts

  WorkerSpec* = object
    name*: string             # Unique listener codename ID (agent_id)
    roleSlug*: string         # Triad role slug (architect, auditor, implementer, etc.)
    persona*: string
    role*: string             # Human-readable role title
    harness*: string
    model*: string
    tags*: seq[string]
    profile*: string
    systemPrompt*: string
    opposingPriority*: string
    startupCommand*: string

  SwarmConfig* = object
    project*: string
    targetRepo*: string
    orchestrator*: string
    orchestratorAgent*: string
    executionMode*: string
    workers*: seq[WorkerSpec]

proc printHelp*() =
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
  repurpose [workers...]   Repurpose existing cluster listeners into target project
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

Options for 'init':
  [dir]                    Target directory (default: current directory)
  --force, -f              Force overwrite existing garden.toml
  --orchestrator, -a <name> Set default orchestrator agent name

Options for 'guide':
  install [path]           Install Garden Guide into AGENTS.md (default) or specified file
  check [path]             Verify Garden Guide installation integrity
  uninstall [path]         Remove Garden Guide from AGENTS.md or specified file

Options for 'repurpose':
  --project, -p <proj>     Target project codename (default: current project)
  --role, -r <role>        Target role assignment
  --tags, -t <csv>         Target taxonomy tags
  --self-tag, -s           Offer candidate roles and allow worker to self-select matching tags
  --expected-tags <csv>    Expected capabilities or tools required
  --allow-cross-project    Allow repurposing a worker currently assigned to another project
  --force, -f              Force repurposing even if worker is currently BUSY
  --json                   Output result as structured JSON

Options for 'roadmap':
  --season, -S <name>      Filter roadmap to specific season/milestone
  --json, -j               Output structured roadmap as JSON
  --markdown, -m           Print formatted markdown roadmap to stdout (default)
  --write, -w [path]       Write ROADMAP.md to project root or specified path
  --sync, -s               Synchronize ROADMAP.md from botanical seeds
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
  --queue, -q <name>       Target queue for 'dispatch' (default: queue:<project>:tasks)
  --inline, -i             Print raw 10-backtick prompt cards directly to stdout
  --project-dir, -p <dir>  Target project directory
  --json                   Output result as structured JSON

Options for 'prompts' and 'launch':
  --worker, -w <name>      Filter prompt output to a specific worker (agent_id or role slug)
  --role, -r <role>        Filter prompt output to a specific role (architect, auditor, implementer)
  --mode <mode>            Execution mode override (auto, subagents, tmux, prompts)
  --subagent, --subagents  Generate drillable subagent briefs (sets execution_mode=subagents)
  --tmux                   Spawn/prepare tmux worker panes for CLI harnesses (sets execution_mode=tmux)
  --task <task_id>         Bind a specific task ID in generated subagent briefs
  --dry-run                Prepare commands and metadata without spawning tmux windows
  --write, -o [file]       Write generated prompts to markdown file (default: garden-prompts.md)
  --inline, -i             Print raw 10-backtick prompt cards directly to stdout
  --force-prompts, --cards Force prompt card generation (skips fast-path and subagent/tmux defaults)
  --json                   Output prompts as JSON
  --project-dir, -p <dir>  Target project directory (default: current root)

Options for 'roster-guard':
  --json                   Output verification result as JSON

Options for 'session':
  save [--agent <name>] [--role <role>] [--orchestrator <orch>]
  load [--json]
  clear [--json]
  (Note: on-disk session.json is eliminated; state is dynamic via Redis/environment)

Options for 'status':
  --json                   Output telemetry as JSON

Options for 'teardown':
  Tears down all active project workers registered in Redis
"""

proc detectCurrentHarness*(): string =
  if getEnv("ANTIGRAVITY_APP_DIR", "").len > 0:
    "Antigravity IDE"
  elif getEnv("CLAUDE_CODE", "").len > 0:
    "Claude Code CLI"
  elif getEnv("OPENCODE_DESKTOP", "").len > 0:
    "OpenCode Desktop"
  elif getEnv("OPENCODE_SESSION_ID", "").len > 0:
    "OpenCode"
  elif getEnv("CODEX_CLI", "").len > 0:
    "Codex CLI"
  elif getEnv("CODEX_SESSION_ID", "").len > 0:
    "ChatGPT Desktop / Codex"
  elif getEnv("PI_SESSION_ID", "").len > 0:
    "Pi"
  else:
    "Antigravity / Claude Code"

proc normalizeHarness*(h: string): HarnessType =
  let hl = h.toLowerAscii
  if hl.contains("antigravity"):
    return htAntigravity
  elif hl.contains("claude"):
    return htClaudeCode
  elif hl.contains("codex") or hl.contains("chatgpt"):
    return htCodex
  elif hl.contains("opencode"):
    return htOpenCode
  elif hl.contains("pi"):
    return htPi
  else:
    return htGeneric

proc supportsDrillableSubagents*(harness: string): bool =
  normalizeHarness(harness) in [htAntigravity, htOpenCode]

proc supportsTmuxFactory*(harness: string): bool =
  let hl = harness.toLowerAscii().strip()
  if hl.contains("cli"):
    return true
  if hl.contains("antigravity") or hl.contains("desktop"):
    return false
  return normalizeHarness(harness) in [htClaudeCode, htOpenCode, htPi, htCodex, htGeneric]

proc resolveExecutionMode*(
  harness: string,
  configuredMode: string = "",
  forcePrompts: bool = false,
  optSubagent: bool = false,
  optTmux: bool = false,
  inTmux: bool = (getEnv("TMUX", "").len > 0)
): string =
  if forcePrompts:
    return "prompts"
  if optSubagent:
    return "subagents"
  if optTmux:
    return "tmux"

  let cm = configuredMode.toLowerAscii().strip()
  if cm in ["subagent", "subagents"]:
    return "subagents"
  elif cm == "tmux":
    return "tmux"
  elif cm in ["prompt", "prompts", "cards"]:
    return "prompts"

  let hl = harness.toLowerAscii()
  let ht = normalizeHarness(harness)
  if supportsDrillableSubagents(harness):
    return "subagents"
  if (hl.contains("codex cli") or (ht in [htCodex, htClaudeCode, htPi] and not hl.contains("desktop"))) and inTmux:
    return "tmux"
  return "prompts"

proc resolveWorkerProfile*(w: WorkerSpec): WorkerProfile =
  let p = w.profile.toLowerAscii.strip()
  if p in ["implementation", "implementer", "impl", "dev", "coder", "build"]:
    return wpImplementation
  elif p in ["investigation", "investigator", "research", "researcher", "review", "reviewer", "read-only", "readonly"]:
    return wpInvestigation
  elif p in ["verification", "verifier", "qa", "test", "tester"]:
    return wpVerification
  elif p in ["audit", "auditor", "adversarial-audit", "adversarial-auditor"]:
    return wpAudit

  # Legacy & heuristic fallback if explicit profile is not provided
  let combined = (w.role & " " & w.tags.join(" ") & " " & w.name).toLowerAscii
  if combined.contains("audit"):
    return wpAudit
  elif combined.contains("verif") or combined.contains("qa") or combined.contains("tester"):
    return wpVerification
  elif combined.contains("investig") or combined.contains("review") or combined.contains("research") or combined.contains("read-only") or combined.contains("readonly"):
    return wpInvestigation
  return wpImplementation

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

proc discoverOrchestrator*(project: string, optOrchestratorAgent: string = ""): string =
  ## Dynamically discovers the actual orchestrator agent running for this project.
  ## Priority:
  ## 1. Explicit CLI option (-a, --orchestrator, --orchestrator-agent)
  ## 2. Active session RHIZO_AGENT_NAME (excluding fake '-orchestrator' suffixes)
  ## 3. Discovered Rhizo leader via 'rhizo leader status orchestrator:<project>'
  ## 4. Active agent on the cluster tagged 'orchestrator' or 'lead' in 'rhizo who'
  if optOrchestratorAgent.strip().len > 0:
    return optOrchestratorAgent.strip()

  let envAgent = getEnv("RHIZO_AGENT_NAME", "").strip()
  if envAgent.len > 0 and not envAgent.endsWith("-orchestrator"):
    return envAgent

  try:
    let cmd = "rhizo leader status " & quoteShell("orchestrator:" & project) & " --json"
    let (outp, code) = execCmdEx(cmd)
    if code == 0 and outp.strip().len > 0:
      let j = parseJson(outp.strip())
      if j.hasKey("status") and j["status"].getStr() == "active" and j.hasKey("leader"):
        let ldr = j["leader"].getStr().strip()
        if ldr.len > 0 and not ldr.endsWith("-orchestrator"):
          return ldr
  except CatchableError:
    discard

  let root = findProjectRoot()
  let legacySess = root / ".garden" / "session.json"
  if fileExists(legacySess):
    try: removeFile(legacySess) except CatchableError: discard

  try:
    let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
    if whoCode == 0 and whoOut.strip().len > 0:
      let wJson = parseJson(whoOut.strip())
      if wJson.kind == JArray:
        for item in wJson:
          let itemProj = if item.hasKey("project"): item["project"].getStr().toLowerAscii() else: ""
          let itemAgent = if item.hasKey("agent"): item["agent"].getStr().strip() else: ""
          if (itemProj == project.toLowerAscii() or project.len == 0 or project == "default") and itemAgent.len > 0:
            if item.hasKey("tags") and item["tags"].kind == JArray:
              for t in item["tags"]:
                if t.getStr() in ["orchestrator", "lead"] and not itemAgent.endsWith("-orchestrator"):
                  return itemAgent
  except CatchableError:
    discard

  if envAgent.len > 0:
    return envAgent

  return ""

proc unquoteToml(s: string): string =
  let t = s.strip()
  if (t.startsWith("\"\"\"") and t.endsWith("\"\"\"")) or (t.startsWith("'''") and t.endsWith("'''")):
    if t.len >= 6:
      return t[3 .. ^4].strip()
  elif (t.startsWith("\"") and t.endsWith("\"")) or (t.startsWith("'") and t.endsWith("'")):
    if t.len >= 2:
      return t[1 .. ^2].replace("\\\"", "\"").replace("\\n", "\n")
  return t

proc parseTomlArray(val: string): seq[string] =
  var s = val.strip()
  if s.startsWith("[") and s.endsWith("]"):
    s = s[1..^2].strip()
  if s.len == 0: return @[]
  var current = ""
  var inQuote = false
  var quoteChar = '"'
  for c in s:
    if not inQuote and (c == '"' or c == '\''):
      inQuote = true
      quoteChar = c
      current.add(c)
    elif inQuote and c == quoteChar:
      inQuote = false
      current.add(c)
    elif not inQuote and c == ',':
      let clean = current.strip().unquoteToml()
      if clean.len > 0: result.add(clean)
      current = ""
    else:
      current.add(c)
  let clean = current.strip().unquoteToml()
  if clean.len > 0: result.add(clean)

proc parseTomlSwarmConfig*(content: string): JsonNode =
  result = newJObject()
  result["workers"] = newJArray()

  var curSection = ""
  var curWorker: JsonNode = nil

  template flushWorker() =
    if not curWorker.isNil:
      result["workers"].add(curWorker)
      curWorker = nil

  for rawLine in content.splitLines():
    var line = rawLine.strip()
    if line.len == 0 or line.startsWith("#") or line.startsWith(";"):
      continue

    var quoteChar = '\0'
    var escaped = false
    var cleanLine = ""
    for c in line:
      if escaped:
        escaped = false
      elif c == '\\' and quoteChar == '"':
        escaped = true
      elif quoteChar == '\0' and (c == '"' or c == '\''):
        quoteChar = c
      elif c == quoteChar:
        quoteChar = '\0'
      elif c == '#' and quoteChar == '\0':
        break
      cleanLine.add(c)
    cleanLine = cleanLine.strip()
    if cleanLine.len == 0: continue

    # Check for array of tables: [[workers]] or [[worker]]
    if cleanLine.startsWith("[[") and cleanLine.endsWith("]]"):
      flushWorker()
      let tableName = cleanLine[2 .. ^3].strip().toLowerAscii
      if tableName in ["workers", "worker", "swarm.workers", "swarm.worker"]:
        curSection = "workers"
        curWorker = newJObject()
      else:
        curSection = tableName
      continue

    # Check for table header: [section]
    if cleanLine.startsWith("[") and cleanLine.endsWith("]"):
      flushWorker()
      curSection = cleanLine[1 .. ^2].strip().toLowerAscii
      if curSection.startsWith("workers.") or curSection.startsWith("worker."):
        let parts = curSection.split('.')
        let workerName = if parts.len > 1: parts[1] else: "worker"
        curSection = "workers"
        curWorker = newJObject()
        curWorker["name"] = %workerName
      continue

    let eqIdx = cleanLine.find('=')
    if eqIdx > 0:
      let key = cleanLine[0 ..< eqIdx].strip().toLowerAscii.replace("-", "_")
      let rawVal = cleanLine[eqIdx + 1 .. ^1].strip()

      if curSection == "workers" and not curWorker.isNil:
        if rawVal.startsWith("[") and rawVal.endsWith("]"):
          let arr = parseTomlArray(rawVal)
          var jArr = newJArray()
          for item in arr: jArr.add(%item)
          curWorker[key] = jArr
        else:
          curWorker[key] = %rawVal.unquoteToml()
      elif curSection in ["orchestrator", "swarm.orchestrator"]:
        if not result.hasKey("orchestrator") or result["orchestrator"].kind != JObject:
          result["orchestrator"] = newJObject()
        result["orchestrator"][key] = %rawVal.unquoteToml()
      elif curSection in ["project", "swarm", ""]:
        if key in ["project", "name"]:
          if not result.hasKey("project") or curSection == "project":
            result["project"] = %rawVal.unquoteToml()
        elif key in ["target_repo", "repo"]:
          result["target_repo"] = %rawVal.unquoteToml()
        elif key in ["orchestrator", "orchestrator_agent"]:
          result[key] = %rawVal.unquoteToml()
        elif key in ["execution_mode", "mode"]:
          result["execution_mode"] = %rawVal.unquoteToml()
        elif key == "default_triad":
          if rawVal.startsWith("[") and rawVal.endsWith("]"):
            let arr = parseTomlArray(rawVal)
            var jArr = newJArray()
            for item in arr: jArr.add(%item.toLowerAscii().strip())
            result["default_triad"] = jArr
      else:
        discard

  flushWorker()

proc loadSwarmConfig*(projectDir: string = "", swarmFilePath: string = "", optOrchestratorAgent: string = "", optProject: string = ""): SwarmConfig =
  let root = if projectDir.len > 0: projectDir else: findProjectRoot()
  let envProj = getEnv("RHIZO_PROJECT", getEnv("GARDEN_PROJECT", "")).strip()
  let projName = if optProject.len > 0: optProject.toLowerAscii().replace(" ", "-")
                 elif envProj.len > 0: envProj.toLowerAscii().replace(" ", "-")
                 elif root.len > 0 and root != "/": root.lastPathPart.toLowerAscii().replace(" ", "-")
                 else: "default"
  let discoveredOrch = discoverOrchestrator(projName, optOrchestratorAgent)
  let effectiveOrch = if discoveredOrch.len > 0: discoveredOrch else: "orchestrator"

  result.project = projName
  result.targetRepo = root
  result.orchestrator = effectiveOrch
  result.orchestratorAgent = effectiveOrch
  result.executionMode = "auto"

  # Migration / legacy reading: read legacy garden-swarm.json if present, then purge
  let legacySwarm = root / "garden-swarm.json"
  let envSwarm = getEnv("GARDEN_SWARM_FILE", "")
  var customFile = if swarmFilePath.len > 0 and not swarmFilePath.endsWith("garden-swarm.json"): swarmFilePath
                   elif envSwarm.len > 0 and not envSwarm.endsWith("garden-swarm.json") and fileExists(envSwarm): envSwarm
                   else: ""

  var sJson: JsonNode = nil
  if fileExists(legacySwarm):
    try:
      sJson = parseJson(readFile(legacySwarm))
      removeFile(legacySwarm)
    except CatchableError: discard
  elif customFile.len > 0 and fileExists(customFile):
    try:
      let content = readFile(customFile)
      if customFile.endsWith(".toml") or (not content.strip().startsWith("{") and not content.strip().startsWith("[")):
        try:
          sJson = parseTomlSwarmConfig(content)
        except CatchableError:
          sJson = parseJson(content)
      else:
        try:
          sJson = parseJson(content)
        except CatchableError:
          sJson = parseTomlSwarmConfig(content)
    except CatchableError as e:
      stderr.writeLine("[garden] Warning: Failed to parse custom swarm file: " & e.msg)
  elif fileExists(root / DefaultConfigFileName):
    try:
      let tomlContent = readFile(root / DefaultConfigFileName)
      if tomlContent.contains("[[workers]]") or tomlContent.contains("[[worker]]") or tomlContent.contains("[workers.") or tomlContent.contains("execution_mode") or tomlContent.contains("[project]") or tomlContent.contains("[swarm]"):
        sJson = parseTomlSwarmConfig(tomlContent)
    except CatchableError: discard

  if not sJson.isNil:
    try:
      result.project = if optProject.len > 0: projName
                       elif sJson.hasKey("project") and sJson["project"].getStr().strip().len > 0: sJson["project"].getStr().strip()
                       else: projName
      result.targetRepo = if sJson.hasKey("target_repo"): sJson["target_repo"].getStr(root) else: root
      if sJson.hasKey("execution_mode"):
        result.executionMode = sJson["execution_mode"].getStr("auto")
      
      if sJson.hasKey("orchestrator"):
        if sJson["orchestrator"].kind == JObject:
          result.orchestrator = if sJson["orchestrator"].hasKey("name"): sJson["orchestrator"]["name"].getStr(effectiveOrch) else: effectiveOrch
          result.orchestratorAgent = if sJson["orchestrator"].hasKey("agent"): sJson["orchestrator"]["agent"].getStr("") elif sJson["orchestrator"].hasKey("codename"): sJson["orchestrator"]["codename"].getStr("") else: ""
        elif sJson["orchestrator"].kind == JString:
          result.orchestrator = sJson["orchestrator"].getStr(effectiveOrch)
        else:
          result.orchestrator = effectiveOrch
      else:
        result.orchestrator = effectiveOrch

      if sJson.hasKey("orchestrator_agent"):
        result.orchestratorAgent = sJson["orchestrator_agent"].getStr()

      var customUsedNames: seq[string] = @[]
      if result.orchestrator.len > 0 and result.orchestrator != "orchestrator":
        customUsedNames.add(result.orchestrator)
      if result.orchestratorAgent.len > 0:
        customUsedNames.add(result.orchestratorAgent)

      if sJson.hasKey("workers") and sJson["workers"].kind == JArray:
        for w in sJson["workers"]:
          var spec: WorkerSpec
          let rawName = if w.hasKey("name"): w["name"].getStr() else: "worker"
          let roleVal = if w.hasKey("role"): w["role"].getStr("Swarm Worker") else: "Swarm Worker"
          let rawSlug = if w.hasKey("role_slug"): w["role_slug"].getStr()
                        elif rawName in ["architect", "auditor", "implementer"]: rawName
                        elif roleVal.toLowerAscii.contains("architect"): "architect"
                        elif roleVal.toLowerAscii.contains("audit"): "auditor"
                        elif roleVal.toLowerAscii.contains("implement"): "implementer"
                        else: ""
          spec.roleSlug = rawSlug
          if rawName in ["architect", "auditor", "implementer", "worker"] or rawName.endsWith("-architect") or rawName.endsWith("-auditor") or rawName.endsWith("-implementer"):
            spec.name = allocateUniqueCodename(result.project, rawSlug, customUsedNames)
          else:
            spec.name = rawName
            customUsedNames.add(spec.name)
          spec.persona = if w.hasKey("persona"): w["persona"].getStr(spec.name) else: spec.name
          spec.role = roleVal
          spec.harness = if w.hasKey("harness") and w["harness"].getStr().len > 0: w["harness"].getStr() else: detectCurrentHarness()
          spec.model = if w.hasKey("model"): w["model"].getStr("Session Default (active in window/tab)") else: "Session Default (active in window/tab)"
          if w.hasKey("tags"):
            if w["tags"].kind == JArray:
              for t in w["tags"]: spec.tags.add(t.getStr())
            elif w["tags"].kind == JString:
              for t in w["tags"].getStr().split(","):
                let trimmed = t.strip()
                if trimmed.len > 0: spec.tags.add(trimmed)
          if spec.roleSlug.len > 0 and spec.roleSlug notin spec.tags:
            spec.tags.add(spec.roleSlug)
          if spec.tags.len == 0:
            spec.tags = @[result.project, spec.name]
          spec.systemPrompt = if w.hasKey("system_prompt"): w["system_prompt"].getStr() else: ""
          spec.opposingPriority = if w.hasKey("opposing_priority"): w["opposing_priority"].getStr() else: ""
          let isTier1 = normalizeHarness(spec.harness) in [htAntigravity, htOpenCode, htPi]
          let tagsStr = spec.tags.join(",")
          spec.startupCommand = if w.hasKey("startup_command"): w["startup_command"].getStr()
                                elif isTier1: "rhizo open " & spec.name & " '" & tagsStr & "'"
                                else: "rhizo open " & spec.name & " '" & tagsStr & "' && rhizo listen " & spec.name
          spec.profile = if w.hasKey("profile"): w["profile"].getStr() elif w.hasKey("capability"): w["capability"].getStr() else: ""
          result.workers.add(spec)
    except CatchableError as e:
      stderr.writeLine("[garden] Warning: Failed to parse custom swarm file: " & e.msg)

  if result.workers.len == 0:
    # Synthesize default balanced triad dynamically on the fly from project/seed requirements
    let synthProj = if result.project.len > 0: result.project else: projName

    # Read active botanical seeds to enrich synthesized requirements
    var seedContext = ""
    var seedTags: seq[string] = @[]
    try:
      let seeds = listSeeds(root)
      var activeSeedTitles: seq[string] = @[]
      for s in seeds:
        if s.status != "HARVESTED" and s.status != "WOVEN":
          activeSeedTitles.add(s.title & " (" & s.id & ")")
          for t in s.tags:
            if t notin seedTags and t != synthProj: seedTags.add(t)
      if activeSeedTitles.len > 0:
        seedContext = " Sown project seed(s): " & activeSeedTitles.join("; ") & "."
    except CatchableError:
      discard

    var triadUsedNames: seq[string] = @[]
    if result.orchestrator.len > 0 and result.orchestrator != "orchestrator":
      triadUsedNames.add(result.orchestrator)
    if result.orchestratorAgent.len > 0:
      triadUsedNames.add(result.orchestratorAgent)

    let archName = allocateUniqueCodename(synthProj, "architect", triadUsedNames)
    let auditName = allocateUniqueCodename(synthProj, "auditor", triadUsedNames)
    let implName = allocateUniqueCodename(synthProj, "implementer", triadUsedNames)
    let curHarness = detectCurrentHarness()
    let curHarnessType = normalizeHarness(curHarness)

    let archPersona = pickWhimsicalPersona("architect", synthProj)
    let auditPersona = pickWhimsicalPersona("auditor", synthProj)
    let implPersona = pickWhimsicalPersona("implementer", synthProj)

    var archTags = @[synthProj, "architect", "systems", "architecture", "invariants"]
    var auditTags = @[synthProj, "auditor", "qa", "audit", "verifier", "purist"]
    var implTags = @[synthProj, "implementer", "dev", "devex", "build", "implementation"]
    for st in seedTags:
      if st notin implTags: implTags.add(st)

    let archTagsStr = archTags.join(",")
    let auditTagsStr = auditTags.join(",")
    let implTagsStr = implTags.join(",")

    let isTier1 = curHarnessType in [htAntigravity, htOpenCode, htPi]
    let archCmd = if isTier1: "rhizo open " & archName & " '" & archTagsStr & "'"
                  else: "rhizo open " & archName & " '" & archTagsStr & "' && rhizo listen " & archName
    let auditCmd = if isTier1: "rhizo open " & auditName & " '" & auditTagsStr & "'"
                   else: "rhizo open " & auditName & " '" & auditTagsStr & "' && rhizo listen " & auditName
    let implCmd = if isTier1: "rhizo open " & implName & " '" & implTagsStr & "'"
                  else: "rhizo open " & implName & " '" & implTagsStr & "' && rhizo listen " & implName

    var activeTriadRoles = @["architect", "auditor", "implementer"]
    if not sJson.isNil and sJson.hasKey("default_triad") and sJson["default_triad"].kind == JArray and sJson["default_triad"].len > 0:
      var customTriad: seq[string] = @[]
      for rItem in sJson["default_triad"]:
        if rItem.kind == JString:
          let rs = rItem.getStr().toLowerAscii().strip()
          if rs.len > 0 and rs notin customTriad: customTriad.add(rs)
      if customTriad.len > 0:
        activeTriadRoles = customTriad

    if "architect" in activeTriadRoles:
      result.workers.add(WorkerSpec(
        name: archName,
        roleSlug: "architect",
        persona: archPersona,
        role: "Staff Systems Architect",
        harness: curHarness,
        model: "Session Default (active in window/tab)",
        tags: archTags,
        profile: "investigation",
        systemPrompt: "You are " & archPersona & ", Staff Systems Architect for the " & synthProj & " project. Your mandate is macro-architecture correctness, invariant preservation, API contracts, cross-module boundaries, and eliminating architectural drift." & seedContext & " Ground all assertions in empirical code analysis. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & "). Operate as an investigator and architectural reviewer.",
        opposingPriority: "Structural purity, invariant guarantees, and long-term maintainability over hasty quick fixes.",
        startupCommand: archCmd
      ))

    if "auditor" in activeTriadRoles:
      result.workers.add(WorkerSpec(
        name: auditName,
        roleSlug: "auditor",
        persona: auditPersona,
        role: "Verification & Adversarial Auditor",
        harness: curHarness,
        model: "Session Default (active in window/tab)",
        tags: auditTags,
        profile: "audit",
        systemPrompt: "You are " & auditPersona & ", Verification & Adversarial Auditor for the " & synthProj & " project. Your mandate is zero-tolerance for green mirages, unverified assertions, dead code, shelfware, or untested branches. You are the INDEPENDENT AUDITOR responsible for Key 3 of the Three-Key Gate. The Adversarial Auditor ONLY inspects and ratifies/rejects Key 3 (vine audit inspect + vine audit approve/reject). The Lead Orchestrator is solely responsible for running vine weave after Key 3 ratification; turning the Auditor into a merge clerk biases the LLM toward rubber-stamping audits just to finish its administrative checklist. Workers submit their strands to you via 'vine submit'. You audit their strands under the presumption of guilt using the Five Pillars: 1) Closed-Circuit Two-Point Diff, 2) Holistic Integration, 3) Literal Fidelity & Parity, 4) Replacement Purge, 5) Structural Assertion Rigor. If defects are found, reject with 'vine audit reject <task_id> --auditor " & auditName & " --ticket <hex> --reason <reason> --listen'. When 0 defects remain and tests pass, ratify approval with 'vine audit approve <task_id> --auditor " & auditName & " --ticket <hex> --evidence <evidence> --listen'. YOU NEVER AUDIT YOUR OWN WORK. Assume all code is broken until proven sound by empirical test runs. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & ").",
        opposingPriority: "Adversarial skepticism, rigorous negative controls, and proof over convenience.",
        startupCommand: auditCmd
      ))

    if "implementer" in activeTriadRoles:
      result.workers.add(WorkerSpec(
        name: implName,
        roleSlug: "implementer",
        persona: implPersona,
        role: "DevEx & Implementation Lead",
        harness: curHarness,
        model: "Session Default (active in window/tab)",
        tags: implTags,
        profile: "implementation",
        systemPrompt: "You are " & implPersona & ", DevEx & Implementation Lead for the " & synthProj & " project. Your mandate is pragmatic, clean, high-velocity implementation in isolated Vine strands." & seedContext & " You execute tasks assigned by @" & result.orchestrator & ", maintain ergonomic developer workflows, verify Keys 1 & 2 with 'vine gate', submit for independent audit with 'vine submit', and report completed deliverables back over Rhizo. Remember: THE WORKER IS NOT THE AUDITOR; never attempt to self-audit.",
        opposingPriority: "High-velocity implementation, pragmatic delivery, and developer ergonomics.",
        startupCommand: implCmd
      ))

  # Override / sanitize orchestrator if explicit or fake
  if optOrchestratorAgent.len > 0:
    result.orchestrator = optOrchestratorAgent.strip()
    result.orchestratorAgent = result.orchestrator
  elif result.orchestrator.len == 0 or result.orchestrator.endsWith("-orchestrator"):
    if discoveredOrch.len > 0:
      result.orchestrator = discoveredOrch
      result.orchestratorAgent = discoveredOrch
    else:
      result.orchestrator = "orchestrator"
      result.orchestratorAgent = "orchestrator"
  elif result.orchestratorAgent.len == 0:
    result.orchestratorAgent = result.orchestrator

proc generateWorkerPrompt*(cfg: SwarmConfig, w: WorkerSpec): string =
  let tagsStr = w.tags.join(",")
  let profile = resolveWorkerProfile(w)
  let harnessKind = normalizeHarness(w.harness)

  result = "# Swarm Worker Bootstrap: " & w.persona & " (@" & w.name & ")\n\n"
  result &= "You are **" & w.persona & "**, serving as **" & w.role & "** for project **" & cfg.project & "**.\n"
  result &= "> [!IMPORTANT]\n"
  result &= "> You are operating in an INTERACTIVE WORKER SESSION (top-level tab/window or tmux pane). You are an autonomous peer worker, NOT an opaque single-turn tool call.\n\n"
  
  result &= "### 1. Identity & Mandate\n"
  result &= "- **Unique Listener ID (agent_id)**: `" & w.name & "`\n"
  let roleTagInfo = if w.roleSlug.len > 0: " (routable via @" & w.roleSlug & " tag)" else: ""
  result &= "- **Triad Role**: " & w.role & roleTagInfo & "\n"
  let profileTitle = case profile
    of wpImplementation: "Implementation & Feature Engineering"
    of wpInvestigation: "Investigation & Review (Non-Modifying / Read-Only)"
    of wpVerification: "Verification & Quality Assurance"
    of wpAudit: "Adversarial Audit (Key 3 Gate)"
  result &= "- **Profile / Capability**: " & profileTitle & "\n"
  if w.opposingPriority.len > 0:
    result &= "- **Opposing Priority**: " & w.opposingPriority & "\n"
  result &= "- **Orchestrator**: `@" & cfg.orchestrator & "`\n\n"
  
  if w.systemPrompt.len > 0:
    result &= "<MANDATE>\n" & w.systemPrompt & "\n</MANDATE>\n\n"
    
  result &= "### 2. Immediate Onboarding Actions (FIRST TURN EXECUTION)\n"
  result &= "<CRITICAL>\n"
  result &= "DO NOT output conversational greetings. DO NOT ask 'How can I help?'.\n"
  result &= "Execute these shell commands right now in your VERY FIRST tool turn to register and announce arrival:\n\n"
  result &= "```bash\n"
  result &= "cd \"" & cfg.targetRepo & "\"\n"
  result &= "export RHIZO_AGENT_ID=\"" & w.name & "\"\n"
  result &= "export RHIZO_AGENT_NAME=\"" & w.name & "\"\n"
  result &= "rhizo open \"" & w.name & "\" \"" & tagsStr & "\"\n"
  if harnessKind == htCodex:
    result &= "# If authorized, register your Codex thread ID for native wakeups:\n"
    result &= "[ -n \"$CODEX_THREAD_ID\" ] && rhizo session register \"" & w.name & "\" --thread-id \"$CODEX_THREAD_ID\" --harness codex\n"
    result &= "# Optional: Install turn-end Stop hook interlock if authorized:\n"
    result &= "# rhizo hook install --codex --agent \"" & w.name & "\"\n\n"
  elif harnessKind == htClaudeCode:
    result &= "# Optional: Install Claude Code prompt hook interlock if authorized:\n"
    result &= "# rhizo hook install --claude --agent \"" & w.name & "\"\n\n"
  elif harnessKind == htAntigravity:
    result &= "# Install Antigravity lifecycle hooks (PreInvocation, PostToolUse lease keep-alive, Stop interlock):\n"
    result &= "rhizo hook install --antigravity --agent \"" & w.name & "\"\n\n"

  result &= "# Broadcast Mutual Arrival Handshake (enqueued to Rhizo):\n"
  result &= "rhizo send --to \"" & cfg.orchestrator & "\" --subject \"WORKER_READY\" --body \"Worker @" & w.name & " (" & w.persona & " - " & w.role & ") initialized. Standing by for sprint assignment.\"\n"

  if harnessKind in [htOpenCode, htPi, htAntigravity]:
    result &= "```\n"
    result &= "> [!NOTE]\n"
    if harnessKind == htAntigravity:
      result &= "> **Multiplexed Router & Session Registry Active (Continuous Ambient Ear & Hooks)**: In Google Antigravity, running 'rhizo open \"" & w.name & "\" \"" & tagsStr & "\"' (or 'rhizo session register \"" & w.name & "\" --tags \"" & tagsStr & "\"') registers your identity, conversation ID, and language server token/address mapping in Redis. A single host Multiplexed Router Service ('rhizo router') handles all message listening and routing for the host, while hooks and CLI commands automatically refresh the token and address registry.\n"
      result &= "> DO NOT launch a redundant blocking shell listener ('rhizo listen'); incoming directives are delivered directly into your session context via 'agentapi send-message' without manual per-turn re-arming.\n"
    else:
      result &= "> **Multiplexed Router & In-Process Ear Active**: In OpenCode and Pi, running 'rhizo open \"" & w.name & "\" \"" & tagsStr & "\"' (or 'rhizo session register \"" & w.name & "\" --tags \"" & tagsStr & "\"') registers your session with the host Multiplexed Router Service ('rhizo router'), and your session receives incoming directives reactively via its internal event ear.\n"
      result &= "> DO NOT launch a redundant blocking shell listener ('rhizo listen'); incoming directives are delivered directly into your session context.\n"
  else:
    result &= "\n# Arm single-shot listener for incoming directives:\n"
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
  if harnessKind notin [htOpenCode, htPi, htAntigravity]:
    result &= "   - If the operator says to listen or arm ('/rhizo listen', 'arm listener', 'listen now'),\n"
    result &= "     you MUST invoke 'rhizo listen " & w.name & "' IMMEDIATELY in that turn.\n"
    result &= "     Never defer arming behind a multi-step plan ('I will listen when I finish X').\n"
  else:
    result &= "   - If the operator asks to check or revive the listener, run 'rhizo open \"" & w.name & "\"' or 'rhizo session register \"" & w.name & "\"'\n"
    result &= "     to refresh the session registration and ensure the host Multiplexed Router is directing messages to this window.\n"
  result &= "2. WORKER AUTONOMOUS EXECUTION (WHEN OPERATOR IS SILENT):\n"
  result &= "   You are an AUTONOMOUS CLUSTER WORKER, NOT A PASSIVE CHATBOT.\n"
  if harnessKind == htAntigravity:
    result &= "   When an incoming directive is delivered via 'agentapi send-message' from the host Multiplexed Router Service, a task has been received!\n"
  elif harnessKind in [htOpenCode, htPi]:
    result &= "   When an incoming directive is delivered via the Multiplexed Router / in-process event ear, a task has been received!\n"
  else:
    result &= "   When 'rhizo listen " & w.name & "' unblocks and exits, a task has been delivered into this session!\n"
  result &= "   - IMMEDIATE ACK UPON RECEIPT: Immediately claim the task ('rhizo task claim <id> --lease 900' or send a quick ACK reply to @" & cfg.orchestrator & " WITHOUT --listen).\n"
  if harnessKind == htAntigravity:
    result &= "   - MULTIPLEXED ROUTER EXECUTION: In Antigravity, the host Multiplexed Router Service ('rhizo router') pushes incoming tasks directly into the conversation via 'agentapi send-message' (and PostToolUse hooks auto-extend task leases), so execute without manual 'rhizo listen' re-arming!\n"
  elif harnessKind in [htOpenCode, htPi]:
    result &= "   - MULTIPLEXED ROUTER EXECUTION: In OpenCode and Pi, the host Multiplexed Router Service ('rhizo router') routes messages directly to your in-process event stream, so execute without manual 'rhizo listen' re-arming!\n"
  result &= "   - PERIODIC PROGRESS TELEMETRY: During long multi-step tasks (>2 minutes), run `rhizo task progress <id> \"Step X/Y: ...\"` before/after major steps to refresh your in-flight task lease and heartbeat.\n"
  if harnessKind notin [htOpenCode, htPi, htAntigravity]:
    result &= "   - Before concluding your turn, ensure your single-shot listener ('rhizo listen " & w.name & "') is armed or use 'rhizo reply ... --listen' when sending your completion report.\n"
  result &= "</CRITICAL>\n\n"

  result &= "### 4. Listener Discipline & Coordination Invariants\n"
  result &= "<CRITICAL>\n"
  if harnessKind in [htOpenCode, htPi, htAntigravity]:
    if harnessKind == htAntigravity:
      result &= "- Multiplexed Router & Session Registry Active (Continuous Ambient Ear): One singleton 'rhizo router' service listens for all agents on the machine and routes messages directly to the right session/conversation ID via 'agentapi send-message'. Hooks and CLI commands automatically update 'rhizo:agent:<name>' and 'rhizo:agy_host:<machine_id>' whenever the language server address or CSRF token changes. Do NOT spawn blocking 'rhizo listen' subprocesses or wrap listeners in shell loops.\n"
    else:
      result &= "- Multiplexed Router Active: Incoming messages are delivered into your context reactively via the host Multiplexed Router and in-process ear. Do NOT run blocking shell listeners.\n"
  else:
    result &= "- Single-Shot Blocking: 'rhizo listen " & w.name & "' blocks until a message arrives, then exits immediately.\n"
    result &= "- Infinite Wait: Always run 'rhizo listen' with zero timeout (never use bounded timeouts, which cause token-thrashing empty wakeups).\n"
    result &= "- Anti-Premature-Yield: NEVER pass --listen on initial CLAIM or ACK replies. Only pass --listen (or arm your listener) on your final completion / turn-end reply.\n"
    result &= "- FORBIDDEN: NEVER wrap 'rhizo listen' in a shell loop (`while true; do rhizo listen; done` or `until rhizo listen; do ...`). Loops trap messages inside unmonitored subshell logs and hang coordination.\n"
  result &= "</CRITICAL>\n\n"
  
  case profile
  of wpImplementation:
    result &= "### 5. Task Execution & Workspace Protocol (Implementation Lead)\n"
    result &= "- **Claiming & Progress Telemetry**:\n"
    result &= "  - From a work queue: `rhizo claim queue:" & cfg.project & ":tasks --lease 300`\n"
    result &= "  - Direct task claim & lease extension: `rhizo task claim <task_id> --lease 900`\n"
    result &= "  - In-flight progress heartbeat (>2m tasks): `rhizo task progress <task_id> \"Step X/Y: Running E2E...\"`\n"
    result &= "- **Distributed Locks**: If modifying shared resources, acquire a fencing token first:\n"
    result &= "  `rhizo lock <resource> --fencing`\n"
    result &= "- **Isolated Workspaces (Vine Strands)**:\n"
    result &= "  Always isolate task changes inside a dedicated Vine strand:\n"
    result &= "  `vine new <task_id>`\n"
    result &= "  Vine tracks strand identity in `.git/config` (`vine.taskId`, `vine.project`) and authoritative state in Redis (zero on-disk `.vine.json` state files).\n"
    result &= "- **Pre-Weave Changelog Discipline**:\n"
    result &= "  If the project has a changelog (CHANGELOG.md), record your user-facing changes under '## [Unreleased]':\n"
    result &= "  `vine changelog \"Description of changes\"` (or `vine changelog --ensure-unreleased`)\n"
    result &= "- **Verification & Three-Key Gate Protocol**:\n"
    result &= "  Verify before reporting completion with Keys 1 & 2 of the Three-Key Gate (verifies mergeability, tests, and changelog update):\n"
    result &= "  `vine gate`\n"
    result &= "- **THE WORKER IS NOT THE AUDITOR INVARIANT (MANDATORY)**:\n"
    result &= "  <CRITICAL>\n"
    result &= "  YOU ARE NOT THE AUDITOR. An implementer or worker MUST NEVER attempt to audit or approve their own strand ('vine audit approve' on your own strand will fail with Exit Code 6: Self-audit violation). The Key 3 Adversarial Audit MUST be performed by an independent Adversarial Auditor session created by the Orchestrator.\n"
    result &= "  Once your tests and changelog pass, submit your strand for independent audit with `vine submit` (generates cryptographic delivery ticket / gate token), notify the Orchestrator (@" & cfg.orchestrator & "), and await the auditor's review.\n"
    result &= "  If the auditor rejects your strand ('AUDIT_REJECTED'), inspect the findings, fix them in your strand, and re-submit with `vine submit`.\n"
    result &= "  </CRITICAL>\n"
    result &= "- **Reporting & Acknowledging**:\n"
    result &= "  Send status updates or gate reports back to the Orchestrator:\n"
    result &= "  `rhizo ack queue:" & cfg.project & ":tasks <task_id>`\n\n"

    result &= "### 6. Closed-Circuit & Holistic Integration Invariant (No Shelfware / No Stubs)\n"
    result &= "<CRITICAL>\n"
    result &= "- Two-Point Diff Mandate: Never build isolated code in a vacuum. Every deliverable must exhibit a Two-Point Diff: the Provider (new capability) and the Consumer (live production call-site, router, UI canvas, or CLI entrypoint). Code tested only by its own unit tests is strictly prohibited as incomplete shelfware.\n"
    result &= "- Holistic Integration (No Stubs / No Toys): The producer and consumer must actually holistically integrate with the system. It must NOT be a toy, stub, mock, or heuristic approximation of the feature. It must handle real application state, live events, and production errors.\n"
    result &= "- Aggressive Replacement Purge (Zero Dead Code): Any existing code, configurations, or fallbacks that your feature is intended to replace or upgrade MUST BE DELETED in the same strand. Do not preserve obsolete logic as a fallback, and do not leave commented-out shims in the codebase.\n"
    result &= "</CRITICAL>\n\n"

  of wpInvestigation:
    result &= "### 5. Investigation, Research & Review Protocol (NON-IMPLEMENTING / READ-ONLY)\n"
    result &= "<CRITICAL>\n"
    result &= "YOU ARE AN INVESTIGATOR AND REVIEWER. You are NOT an implementation coder.\n"
    result &= "- READ-ONLY DISCIPLINE: You MUST NOT edit application source files, test suites, or build configurations.\n"
    result &= "- NO WORKSPACE MUTATIONS: Do NOT create code branches or strands, do NOT update project changelogs, and do NOT commit or submit implementation deliverables.\n"
    result &= "- EMPIRICAL EVIDENCE: Ground all findings, architectural reviews, and recommendations in real code citations (exact file paths, line numbers, test runs, AST inspects, and git blame).\n"
    result &= "- DELIVERABLES: Your deliverables are structured research documents, RFC proposals, architecture reviews, or audit feedback delivered over Rhizo to the Orchestrator (`rhizo reply` or `rhizo send`).\n"
    result &= "- Task Claiming: Claim assigned investigation tasks via `rhizo task claim <task_id> --no-vine --lease 900`.\n"
    result &= "</CRITICAL>\n\n"

  of wpVerification:
    result &= "### 5. Verification & Quality Assurance Protocol (CHECKS ONLY / NO SOURCE EDITS)\n"
    result &= "<CRITICAL>\n"
    result &= "YOU ARE A VERIFICATION & QA ENGINEER. Your mandate is rigorous testing and reproduction.\n"
    result &= "- PERMITTED ACTIONS:\n"
    result &= "  * Execute test suites, linters, static analyzers, repro scripts, and benchmark pipelines.\n"
    result &= "  * Generate temporary disposable test outputs, reproduction traces, or cache artifacts in `/tmp` or `.cache`.\n"
    result &= "- STRICT PROHIBITION AGAINST CHANGING APPLICATION SOURCE OR TESTS:\n"
    result &= "  * You must NEVER modify application source code or alter tests to force them green (anti-green mirage).\n"
    result &= "  * Do NOT modify changelogs or submit code deliverables.\n"
    result &= "- DELIVERABLES: Output empirical verification matrices, reproduction scripts, defect traces, and test coverage evidence over Rhizo to @" & cfg.orchestrator & ".\n"
    result &= "- Task Claiming: Claim assigned verification tasks via `rhizo task claim <task_id> --no-vine --lease 900`.\n"
    result &= "</CRITICAL>\n\n"

  of wpAudit:
    result &= "### 5. Key 3 Adversarial Auditor Protocol (YOUR PRIMARY MANDATE)\n"
    result &= "<CRITICAL>\n"
    result &= "YOU ARE THE DESIGNATED ADVERSARIAL AUDITOR. You enforce Key 3 of the Three-Key Gate.\n"
    result &= "- The Adversarial Auditor ONLY inspects and ratifies/rejects Key 3 (`vine audit inspect` + `vine audit approve/reject`).\n"
    result &= "- MERGE-CLERK DECOUPLING INVARIANT: The Lead Orchestrator is solely responsible for running `vine weave` after Key 3 ratification. The Orchestrator is strictly forbidden from delegating weaving, merge conflict resolution, ROADMAP.md updates, or release chores to the Auditor. Turning the Auditor into a merge clerk biases the LLM toward rubber-stamping audits just to finish its administrative checklist.\n"
    result &= "- When an implementer finishes work and requests review, inspect their submitted strand directory under the presumption of guilt:\n"
    result &= "  `vine audit inspect <task_id>`\n"
    result &= "- Verify the Five Pillars:\n"
    result &= "  1. Closed-Circuit Two-Point Diff: Provider wired to real Consumer call-site.\n"
    result &= "  2. Holistic Integration: Real errors and application state handled (no hollow stubs/toys).\n"
    result &= "  3. Literal Fidelity & Parity: Exact implementation of the specification (zero loose approximations).\n"
    result &= "  4. Replacement Purge: All legacy or obsolete code targeted for replacement is deleted.\n"
    result &= "  5. Structural Assertion Rigor: Tests assert full structural equality with negative controls.\n"
    result &= "- INVERTED EFFORT GRADIENT:\n"
    result &= "  * Rejection is the fast-path whenever ANY doubt, green mirage, or defect exists: `vine audit reject <task_id> --auditor \"" & w.name & "\" --ticket <hex> --reason \"<findings>\" --listen`\n"
    result &= "  * Approval is evidence-bound and requires explicit proof citing specific changed file basenames, provider->consumer call-sites, and negative control assertions: `vine audit approve <task_id> --auditor \"" & w.name & "\" --ticket <hex> --evidence \"<changed files, provider->consumer call-sites, negative controls>\" --listen`\n"
    result &= "- SELF-AUDIT IS STRICTLY FORBIDDEN: You must never audit or approve your own strand.\n"
    result &= "- ZERO IMPLEMENTATION EDITING: You audit and ratify others' strands; you do not implement code or resolve merge conflicts.\n"
    result &= "</CRITICAL>\n\n"

  # Section 7: Harness-Aware Wakeup Guidance
  case harnessKind
  of htCodex:
    result &= "### 7. Codex Native Wakeup Protocol (`RHIZO_WAKE`)\n"
    result &= "<CRITICAL>\n"
    result &= "Autonomous Wakeup Invariant on OpenAI Codex:\n"
    result &= "- Distinguish Payload Transport from Idle Wakeup: Messages and task directives MUST always be dispatched through Rhizo first (`rhizo send <agent> \"<subject>\" \"<body>\"`).\n"
    result &= "- Shell Listeners & Hooks Do Not Wake Idle Codex: A running background listener or turn-end Stop hook alone cannot resume an idle Codex session when a new message arrives.\n"
    result &= "- Scheduled Polling & Watchdogs PROHIBITED: Do NOT configure recurring timers, cron schedules, or infinite shell loops (`while true; do rhizo listen; done`). Scheduled polling exhausts token budgets and is strictly forbidden.\n"
    result &= "- Native Wake Mechanism: To wake an idle Codex session, the sender invokes Codex's native tool:\n"
    result &= "    send_message_to_thread(thread_id=\"<thread_id>\", message=\"RHIZO_WAKE\")\n"
    result &= "- Wakeup Rules:\n"
    result &= "  * Send exactly 'RHIZO_WAKE'.\n"
    result &= "  * One wake per actionable batch: Enqueue all batch tasks to Rhizo before sending a single wake.\n"
    result &= "  * Anti-Ping-Pong: NEVER wake for routine ACKs or replies. Routine ACKs must not trigger wakeups.\n"
    result &= "  * Payload Preservation: If native wake fails or is unauthorized, queued work remains safely in the Rhizo queue. Never equate a successful enqueue with task execution.\n"
    result &= "- Upon Receiving 'RHIZO_WAKE' in this session:\n"
    result &= "  1. Inspect completed supervised listener output for delivered payloads.\n"
    result &= "  2. Drain and process pending messages: `rhizo drain 10 " & w.name & " --format json`.\n"
    result &= "  3. Execute assigned tasks according to your profile and re-arm listener: `rhizo listen " & w.name & "`.\n"
    result &= "</CRITICAL>\n\n"
  of htOpenCode, htPi:
    result &= "### 7. Multiplexed Router & In-Process Event Stream (OpenCode / Pi)\n"
    result &= "Your session registers via `rhizo open " & w.name & "` / `rhizo session register " & w.name & "` with the Multiplexed Router Service (`rhizo router`). Incoming Rhizo messages are delivered reactively through the router and native event ear. Scheduled polling and blocking shell listeners are not required.\n\n"
  of htAntigravity:
    result &= "### 7. Multiplexed Router, Continuous Ambient Ear & Lifecycle Hooks (Google Antigravity)\n"
    result &= "`rhizo open " & w.name & "` / `rhizo session register " & w.name & "` registers your session in the Redis session registry (`rhizo:agent:" & w.name & "`, `rhizo:agy_host:<machine_id>`). A single host Multiplexed Router Service (`rhizo router`) handles all message listening and routing on this machine, streaming messages directly to your conversation ID via `agentapi send-message`. Antigravity lifecycle hooks (`rhizo hook install --antigravity`) automatically provide `PostToolUse` lease renewal, `PreInvocation` context injection, and `Stop` turn-end interlocks. Manual per-turn `rhizo listen` subprocesses and scheduled polling are not required.\n\n"
  of htClaudeCode, htGeneric:
    result &= "### 7. Supervised Single-Shot Listener Discipline\n"
    result &= "Run `rhizo listen " & w.name & "` as a single-shot blocking foreground command. When a message arrives, the process exits cleanly with the delivered payload. Scheduled polling and infinite loops are strictly prohibited.\n\n"
  
  result &= "### 8. Compaction State Rider\n"
  result &= "Whenever context summarization or compaction occurs, preserve this block verbatim:\n"
  result &= "<!-- SWARM_RUNTIME_STATE: DO NOT DISCARD OR ABBREVIATE IN COMPACTION -->\n"
  result &= "- AGENT_NAME: " & w.name & " (Role: " & w.role & ")\n"
  result &= "- ORCHESTRATOR: @" & cfg.orchestrator & "\n"
  result &= "- TARGET_REPO: " & cfg.targetRepo & "\n"
  result &= "<!-- END_SWARM_RUNTIME_STATE -->\n"

proc generateSubagentBrief*(cfg: SwarmConfig, w: WorkerSpec, taskId: string = ""): string =
  ## Generates a persistent, drillable subagent brief that follows the full worker procedure
  ## (unique Rhizo identity, explicit --agent usage, isolated 1:1 Vine strand, and independent Key 3 audit).
  let tagsStr = w.tags.join(",")
  let profile = resolveWorkerProfile(w)
  let effectiveTask = if taskId.strip().len > 0: taskId.strip() else: "<task_id>"
  let profileTitle = case profile
    of wpImplementation: "Implementation & Feature Engineering"
    of wpInvestigation: "Investigation & Review (Non-Modifying / Read-Only)"
    of wpVerification: "Verification & Quality Assurance"
    of wpAudit: "Adversarial Audit (Key 3 Gate)"

  result = "# Subagent Worker Brief: " & w.persona & " (@" & w.name & " - " & w.role & ")\n\n"
  result &= "You are **" & w.persona & "**, operating as a persistent, drillable subagent worker (**" & w.role & "**) for project **" & cfg.project & "**.\n"
  result &= "The operator can click directly into this session to inspect progress or steer you interactively.\n\n"

  result &= "### 1. Identity & Registration (Explicit `--agent` Mandate)\n"
  result &= "- **Agent Name**: `" & w.name & "`"
  if w.roleSlug.len > 0:
    result &= " (routable via `@" & w.roleSlug & "` tag)"
  result &= "\n"
  result &= "- **Profile / Capability**: " & profileTitle & "\n"
  if w.opposingPriority.len > 0:
    result &= "- **Opposing Priority**: " & w.opposingPriority & "\n"
  result &= "- **Orchestrator**: `@" & cfg.orchestrator & "`\n"
  result &= "- **Target Repo**: `" & cfg.targetRepo & "`\n"
  if w.systemPrompt.len > 0:
    result &= "\n<MANDATE>\n" & w.systemPrompt & "\n</MANDATE>\n"

  result &= "\nBecause subagent shells do not persist environment variables across commands, pass `--agent \"" & w.name & "\"` (or explicit agent name `" & w.name & "`) in subsequent commands:\n"
  result &= "```bash\n"
  result &= "cd \"" & cfg.targetRepo & "\"\n"
  result &= "rhizo open \"" & w.name & "\" \"" & tagsStr & "\"\n"
  result &= "```\n\n"

  result &= "### 2. Task Claiming & Locking\n"
  if profile in [wpInvestigation, wpVerification]:
    result &= "- Claim task (read-only): `rhizo task claim \"" & effectiveTask & "\" --no-vine --agent \"" & w.name & "\" --lease 900`\n"
  elif profile == wpAudit:
    result &= "- Drain audit notification / ticket: `rhizo drain 10 \"" & w.name & "\" --format json`\n"
  else:
    result &= "- Claim task & lease: `rhizo task claim \"" & effectiveTask & "\" --agent \"" & w.name & "\" --lease 900`\n"
    result &= "- Lock shared resources before editing: `rhizo lock <resource> --fencing --agent \"" & w.name & "\"`\n"
  result &= "\n"

  case profile
  of wpImplementation:
    result &= "### 3. Implementation & Three-Key Submission Protocol\n"
    result &= "1. **Provision Isolated Vine Strand (1:1)**:\n"
    result &= "   `vine new \"" & effectiveTask & "\" --worker \"" & w.name & "\"`\n"
    result &= "2. **Two-Point Diff & Holistic Integration**:\n"
    result &= "   Implement both Provider and live Consumer call-sites inside the strand. Delete any obsolete code replaced by the change.\n"
    result &= "3. **Changelog & Gates (Keys 1 & 2)**:\n"
    result &= "   - Update changelog if present: `vine changelog \"<description>\"`\n"
    result &= "   - Run mechanical & semantic verification: `vine gate`\n"
    result &= "4. **Submit for Independent Audit**:\n"
    result &= "   - `vine submit --author \"" & w.name & "\"`\n"
    result &= "   - Notify orchestrator: `rhizo send --from \"" & w.name & "\" --to \"" & cfg.orchestrator & "\" --subject \"STRAND_SUBMITTED: " & effectiveTask & "\" --body \"Ready for independent Key 3 audit.\"`\n"
    result &= "5. **YOU ARE NOT THE AUDITOR**: Never run `vine audit approve` on your own strand. Wait for follow-up via `send_message` if Key 3 remediation is requested.\n\n"
  of wpAudit:
    result &= "### 3. Independent Key 3 Adversarial Audit Protocol\n"
    result &= "1. Drain the submitted delivery ticket: `rhizo drain 10 \"" & w.name & "\" --format json`\n"
    result &= "2. Inspect the strand under the presumption of guilt: `vine audit inspect \"" & effectiveTask & "\"`\n"
    result &= "3. Verify the Five Pillars: (1) Two-Point Diff, (2) Holistic Integration, (3) Literal Fidelity, (4) Replacement Purge, (5) Structural Assertion Rigor.\n"
    result &= "4. **Ratify or Reject**:\n"
    result &= "   - Reject if ANY defect exists: `vine audit reject \"" & effectiveTask & "\" --auditor \"" & w.name & "\" --ticket <hex> --reason \"<findings>\"`\n"
    result &= "   - Approve only with empirical proof: `vine audit approve \"" & effectiveTask & "\" --auditor \"" & w.name & "\" --ticket <hex> --evidence \"<files, call-sites, negative controls>\"`\n"
    result &= "5. Never audit your own work and never run `vine weave` (weaving belongs exclusively to the Orchestrator).\n\n"
  of wpInvestigation:
    result &= "### 3. Read-Only Empirical Investigation Protocol\n"
    result &= "1. Do NOT modify application source files, tests, or create code strands.\n"
    result &= "2. Ground every architectural conclusion in exact file paths, line numbers, AST/symbol names, and test outputs.\n"
    result &= "3. Report findings to `@" & cfg.orchestrator & "` (`rhizo send --from \"" & w.name & "\" --to \"" & cfg.orchestrator & "\" ...`) and in the return envelope.\n\n"
  of wpVerification:
    result &= "### 3. Verification & QA Protocol (Checks Only)\n"
    result &= "1. Execute test suites, linters, and reproduction scripts without mutating application source or relaxing assertions.\n"
    result &= "2. Report pass/fail matrices and negative controls to `@" & cfg.orchestrator & "` and in the return envelope.\n\n"

  result &= "### 4. Return Envelope\n"
  result &= "End your response with this structured summary (no blocking `rhizo listen` loop needed; parent resumes via `send_message`):\n"
  result &= "```text\n"
  result &= "STATUS: <READY_FOR_AUDIT | AUDIT_RATIFIED | AUDIT_REJECTED | COMPLETED | BLOCKED>\n"
  result &= "AGENT: " & w.name & "\n"
  result &= "STRAND: <strand_path_or_none>\n"
  result &= "GATE_TICKET: <hex_or_none>\n"
  result &= "CHANGED_FILES: <comma_separated_list_or_none>\n"
  result &= "VERIFICATION_EVIDENCE: <exact_commands_and_assertions_observed>\n"
  result &= "```\n"

proc buildTmuxSpawnCommand*(cfg: SwarmConfig, w: WorkerSpec, promptFilePath: string): string =
  let ht = normalizeHarness(w.harness)
  let cliBin = case ht
    of htCodex: "codex"
    of htOpenCode: "opencode"
    of htClaudeCode: "claude"
    of htPi: "pi"
    else: "codex"
  let innerCmd = cliBin & " " & quoteShell("Read and execute the bootstrap instructions in " & promptFilePath)
  result = "tmux new-window -n " & quoteShell(w.name) & " -c " & quoteShell(cfg.targetRepo) & " " & quoteShell(innerCmd)

proc getGardenTempDir*(projectName: string): string =
  let base = if dirExists("/tmp"): "/tmp" else: getTempDir()
  result = base / ("garden-" & projectName)
  createDir(result)

type
  ClusterWorkerInfo* = object
    agent*: string
    project*: string
    status*: string
    listener*: string
    state*: string
    tags*: seq[string]

  ClusterCategorization* = object
    projectActive*: seq[ClusterWorkerInfo]
    availableIdlePeers*: seq[ClusterWorkerInfo]
    busyClusterPeers*: seq[ClusterWorkerInfo]
    foreignProjectPeers*: seq[ClusterWorkerInfo]
    allAgents*: seq[ClusterWorkerInfo]

proc queryClusterAgents*(currentProject: string = "", targetWorkers: seq[WorkerSpec] = @[]): ClusterCategorization =
  var allList: seq[ClusterWorkerInfo] = @[]
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
            var tags: seq[string] = @[]
            if item.hasKey("tags"):
              if item["tags"].kind == JArray:
                for t in item["tags"]:
                  if t.kind == JString: tags.add(t.getStr())
              elif item["tags"].kind == JString:
                for t in item["tags"].getStr().split(","):
                  let clean = t.strip()
                  if clean.len > 0: tags.add(clean)
            if ag.len > 0:
              allList.add(ClusterWorkerInfo(agent: ag, project: proj, status: st, listener: lis, state: state, tags: tags))
    except CatchableError: discard

  result.allAgents = allList
  let curProjLower = currentProject.toLowerAscii()

  for ca in allList:
    let isListening = ca.listener.toUpperAscii() == "LISTENING"
    let isBusy = ca.state.toUpperAscii().startsWith("BUSY") or ca.state.toUpperAscii().contains("BUSY")
    
    if isBusy:
      result.busyClusterPeers.add(ca)

    if isListening:
      var isTarget = false
      for w in targetWorkers:
        if ca.agent.toLowerAscii() == w.name.toLowerAscii():
          isTarget = true
          break
      
      let isProjMatch = curProjLower.len > 0 and ca.project.toLowerAscii() == curProjLower
      let isUnassignedPool = ca.project.toLowerAscii() in ["", "default", "unassigned"] or
                             ("pool" in ca.tags) or ("float" in ca.tags) or ("shared" in ca.tags)

      if isProjMatch or isTarget:
        result.projectActive.add(ca)
      elif isUnassignedPool:
        if not isBusy and (ca.state.toUpperAscii().startsWith("IDLE") or ca.state.len == 0):
          result.availableIdlePeers.add(ca)
      else:
        # Dedicated worker on another named project: PROTECTED against automatic poaching!
        result.foreignProjectPeers.add(ca)

proc doPrompts*(
  projectDir: string,
  swarmFile: string,
  targetWorker: string,
  writeFileParam: string,
  jsonOutput: bool,
  optOrchAgent: string = "",
  inlineOutput: bool = false,
  forcePrompts: bool = false,
  optProject: string = "",
  workerCount: int = 0,
  optHarness: string = "",
  optMode: string = "",
  optSubagent: bool = false,
  optTmux: bool = false,
  optTaskId: string = "",
  dryRun: bool = false,
  explicitForcePrompts: bool = false,
  executeLaunch: bool = false
): int =
  let normOptMode = optMode.toLowerAscii().strip()
  if normOptMode.len > 0 and normOptMode notin ["auto", "subagent", "subagents", "tmux", "prompt", "prompts", "cards"]:
    stderr.writeLine("[garden] Error: Invalid execution mode '" & optMode & "'. Valid modes: auto, subagents, tmux, prompts.")
    return 1

  var cfg = loadSwarmConfig(projectDir, swarmFile, optOrchAgent, optProject)

  if optHarness.len > 0:
    for i in 0 ..< cfg.workers.len:
      cfg.workers[i].harness = optHarness
      let isTier1 = normalizeHarness(optHarness) in [htAntigravity, htOpenCode, htPi]
      let tagsStr = if cfg.workers[i].tags.len > 0: cfg.workers[i].tags.join(",") else: cfg.project
      cfg.workers[i].startupCommand = if isTier1: "rhizo open " & cfg.workers[i].name & " '" & tagsStr & "'"
                                      else: "rhizo open " & cfg.workers[i].name & " '" & tagsStr & "' && rhizo listen " & cfg.workers[i].name

  if workerCount > 0 and cfg.workers.len > workerCount:
    cfg.workers = cfg.workers[0 ..< workerCount]
  
  var selectedWorkers: seq[WorkerSpec] = @[]
  if targetWorker.len > 0:
    let tw = targetWorker.toLowerAscii()
    for w in cfg.workers:
      let wn = w.name.toLowerAscii()
      let wr = w.roleSlug.toLowerAscii()
      let wrole = w.role.toLowerAscii()
      if wn == tw or wn.endsWith("-" & tw) or wn.startsWith(tw & "-") or
         (wr.len > 0 and (wr == tw or wr.contains(tw))) or
         wrole.contains(tw) or
         tw in w.tags:
        selectedWorkers.add(w)
    if selectedWorkers.len == 0:
      stderr.writeLine("[garden] Error: Worker '" & targetWorker & "' not found in swarm configuration.")
      return 1
  else:
    selectedWorkers = cfg.workers

  let effectiveHarness = if optHarness.len > 0: optHarness
                         elif selectedWorkers.len > 0: selectedWorkers[0].harness
                         else: detectCurrentHarness()
  let forcePromptMode = explicitForcePrompts or (forcePrompts and not optSubagent and not optTmux and optMode.strip().len == 0)
  let effectiveConfigMode = if optMode.strip().len > 0: optMode.strip() else: cfg.executionMode
  let defaultMode = resolveExecutionMode(effectiveHarness, cfg.executionMode, forcePrompts = false, optSubagent = false, optTmux = false)
  let resolvedMode = resolveExecutionMode(effectiveHarness, effectiveConfigMode, forcePrompts = forcePromptMode, optSubagent = optSubagent, optTmux = optTmux)

  let categorization = queryClusterAgents(cfg.project, selectedWorkers)
  let projectActive = categorization.projectActive
  let availableIdlePeers = categorization.availableIdlePeers
  let busyPeers = categorization.busyClusterPeers

  # Fast-Path Check: Skip card generation if all target workers are active and listening
  var allTargetWorkersListening = false
  if selectedWorkers.len > 0:
    var matchedCount = 0
    var usedAgents: seq[string] = @[]
    for w in selectedWorkers:
      var found = false
      for ca in projectActive:
        if ca.agent in usedAgents: continue
        if ca.state.toUpperAscii().contains("BUSY"): continue
        if ca.agent.toLowerAscii() == w.name.toLowerAscii():
          usedAgents.add(ca.agent)
          found = true
          break
      if not found and w.roleSlug.len > 0:
        for ca in projectActive:
          if ca.agent in usedAgents: continue
          if ca.state.toUpperAscii().contains("BUSY"): continue
          let slugLower = w.roleSlug.toLowerAscii()
          var tagMatch = false
          for t in ca.tags:
            if t.toLowerAscii() == slugLower:
              tagMatch = true
              break
          if tagMatch or ca.agent.toLowerAscii().contains(slugLower):
            usedAgents.add(ca.agent)
            found = true
            break
      if found:
        inc matchedCount
    allTargetWorkersListening = (matchedCount >= selectedWorkers.len)

  if not forcePrompts and allTargetWorkersListening and selectedWorkers.len > 0:
    if jsonOutput:
      var jObj = newJObject()
      jObj["fast_path"] = %true
      jObj["project"] = %cfg.project
      jObj["execution_mode"] = %resolvedMode
      jObj["recommended_execution_mode"] = %defaultMode
      jObj["target_workers_count"] = %selectedWorkers.len
      jObj["active_workers_count"] = %projectActive.len
      var jActive = newJArray()
      for ca in projectActive:
        var ja = newJObject()
        ja["agent"] = %ca.agent
        ja["project"] = %ca.project
        ja["listener"] = %ca.listener
        ja["state"] = %ca.state
        jActive.add(ja)
      jObj["active_workers"] = jActive
      jObj["message"] = %("Fast-Path Activated: All target swarm workers are already active and listening on project '" & cfg.project & "'.")
      echo pretty(jObj)
      return 0

    echo "================================================================================"
    echo "  GARDEN SWARM FAST-PATH ACTIVATED: " & cfg.project
    echo "================================================================================"
    echo "All " & $selectedWorkers.len & " target swarm worker(s) are already active and listening on project '" & cfg.project & "':"
    for ca in projectActive:
      echo "  - @" & ca.agent & " (listener: " & ca.listener & ", state: " & (if ca.state.len > 0: ca.state else: "IDLE") & ")"
    echo ""
    echo "Zero prompt copying or terminal tab opening required!"
    echo "Proceed directly to work queue dispatch or germination:"
    echo "  garden germinate dispatch <seed>"
    echo "  rhizo enqueue queue:" & cfg.project & ":tasks --subject \"<subj>\" --body \"<body>\""
    echo "================================================================================"
    return 0

  let tempBaseDir = getGardenTempDir(cfg.project)
  let allWorkersFilePath = tempBaseDir / "all-workers.md"

  type GeneratedCard = object
    worker: WorkerSpec
    filePath: string
    subagentFilePath: string
    subagentBrief: string
    tmuxCommand: string
    execMode: string
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
    let subagentBriefText = generateSubagentBrief(cfg, w, optTaskId)
    let roleSlugPart = if w.roleSlug.len > 0: " (@" & w.roleSlug & ")" else: ""
    let header = "--- WORKER " & $(idx + 1) & " of " & $selectedWorkers.len & ": @" & w.name & roleSlugPart & " (" & w.persona & " - " & w.role & ") ---"
    let subheader = "Recommended Harness: " & w.harness & " | Model: " & w.model
    let promptBlock = PromptFence10 & "markdown\n" & promptText & "\n" & PromptFence10 & "\n"
    
    let workerFilePath = tempBaseDir / (w.name & ".md")
    writeFile(workerFilePath, promptText)
    if w.roleSlug.len > 0 and w.roleSlug != w.name:
      let roleWorkerFilePath = tempBaseDir / (w.roleSlug & "-" & w.name & ".md")
      writeFile(roleWorkerFilePath, promptText)

    let subagentFilePath = tempBaseDir / ("subagent-" & w.name & ".md")
    writeFile(subagentFilePath, subagentBriefText)

    let tmuxCmd = buildTmuxSpawnCommand(cfg, w, workerFilePath)
    let wExecMode = resolveExecutionMode(w.harness, effectiveConfigMode, forcePrompts = forcePromptMode, optSubagent = optSubagent, optTmux = optTmux)

    allWorkersBuf &= "## " & header & "\n\n"
    allWorkersBuf &= "**" & subheader & "**\n\n"
    allWorkersBuf &= promptBlock & "\n\n"

    generatedCards.add(GeneratedCard(
      worker: w,
      filePath: workerFilePath,
      subagentFilePath: subagentFilePath,
      subagentBrief: subagentBriefText,
      tmuxCommand: tmuxCmd,
      execMode: wExecMode,
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

  var suggestedRepurposeCmds: seq[string] = @[]
  if availableIdlePeers.len > 0:
    var peerNames: seq[string] = @[]
    for p in availableIdlePeers:
      peerNames.add(p.agent)
      if peerNames.len >= max(1, selectedWorkers.len - projectActive.len):
        break
    suggestedRepurposeCmds.add("garden repurpose " & peerNames.join(" ") & " --project " & cfg.project & " --self-tag")
    for i, p in peerNames:
      if i < selectedWorkers.len:
        let w = selectedWorkers[i]
        suggestedRepurposeCmds.add("garden repurpose " & p & " --project " & cfg.project & " --role " & quoteShell(w.role) & " --tags " & quoteShell(w.tags.join(",")))

  if jsonOutput:
    var jObj = newJObject()
    jObj["fast_path"] = %false
    jObj["project"] = %cfg.project
    jObj["target_repo"] = %cfg.targetRepo
    jObj["orchestrator"] = %cfg.orchestrator
    if cfg.orchestratorAgent.len > 0:
      jObj["orchestrator_agent"] = %cfg.orchestratorAgent
    jObj["execution_mode"] = %resolvedMode
    jObj["recommended_execution_mode"] = %defaultMode
    jObj["supports_drillable_subagents"] = %supportsDrillableSubagents(effectiveHarness)
    jObj["supports_tmux"] = %supportsTmuxFactory(effectiveHarness)
    jObj["count"] = %selectedWorkers.len
    jObj["temp_dir"] = %tempBaseDir
    jObj["all_file_path"] = %allWorkersFilePath
    
    var jAlready = newJArray()
    for pa in projectActive: jAlready.add(%pa.agent)
    jObj["already_listening"] = jAlready
    
    var jIdle = newJArray()
    for ip in availableIdlePeers: jIdle.add(%ip.agent)
    jObj["idle_cluster_peers"] = jIdle

    var jForeign = newJArray()
    for fp in categorization.foreignProjectPeers:
      var jf = newJObject()
      jf["agent"] = %fp.agent
      jf["project"] = %fp.project
      jf["tags"] = %fp.tags
      jForeign.add(jf)
    jObj["foreign_project_peers"] = jForeign

    var jBusy = newJArray()
    for bp in busyPeers: jBusy.add(%bp.agent)
    jObj["busy_cluster_peers"] = jBusy

    var jCmds = newJArray()
    for sc in suggestedRepurposeCmds: jCmds.add(%sc)
    jObj["suggested_repurpose_commands"] = jCmds

    var jPrompts = newJArray()
    for card in generatedCards:
      var jw = newJObject()
      jw["name"] = %card.worker.name
      jw["role_slug"] = %card.worker.roleSlug
      jw["persona"] = %card.worker.persona
      jw["role"] = %card.worker.role
      jw["harness"] = %card.worker.harness
      jw["model"] = %card.worker.model
      jw["tags"] = %card.worker.tags
      jw["execution_mode"] = %card.execMode
      jw["file_path"] = %card.filePath
      if card.worker.roleSlug.len > 0 and card.worker.roleSlug != card.worker.name:
        jw["role_file_path"] = %(tempBaseDir / (card.worker.roleSlug & "-" & card.worker.name & ".md"))
      jw["subagent_role"] = %(card.worker.persona & " - " & card.worker.role & " (@" & card.worker.name & ")")
      jw["subagent_file_path"] = %card.subagentFilePath
      jw["subagent_brief"] = %card.subagentBrief
      jw["tmux_command"] = %card.tmuxCommand
      jw["prompt"] = %card.promptText
      jPrompts.add(jw)
    jObj["workers"] = jPrompts
    echo pretty(jObj)
    return 0

  if inlineOutput:
    echo "================================================================================"
    echo "  GARDEN SWARM BOOTSTRAP: " & cfg.project
    echo "================================================================================"
    echo "Execution Mode: " & resolvedMode & " (harness default: " & defaultMode & ")"
    echo "Generated " & $selectedWorkers.len & " worker bootstrap prompt(s)."
    echo "Copy and paste each prompt block below into a separate session"
    echo "(Claude Code CLI, OpenCode, Antigravity, Pi, etc.)."
    echo ""
    if projectActive.len > 0:
      echo "  ACTIVE & LISTENING WORKERS IN THIS PROJECT (No Prompt Paste Needed!):"
      for pa in projectActive:
        echo "    - @" & pa.agent & " is ALREADY active and listening"
      echo ""
    if availableIdlePeers.len > 0:
      echo "  AVAILABLE IDLE CLUSTER WORKERS (Can be repurposed without opening new tabs):"
      for ip in availableIdlePeers:
        let curProj = if ip.project.len > 0: ip.project else: "unassigned"
        echo "    - @" & ip.agent & " (current project: " & curProj & ")"
      echo ""
      echo "  Suggested Repurpose Command(s):"
      for sc in suggestedRepurposeCmds:
        echo "    " & sc
      echo ""
    elif categorization.foreignProjectPeers.len > 0:
      echo "  FOREIGN PROJECT WORKERS PROTECTED: Detected " & $categorization.foreignProjectPeers.len & " active worker(s) dedicated to other projects."
      echo "  Cross-project poaching is prohibited. Bootstrap dedicated workers below."
      echo ""
    echo "Once pasted, verify cluster registration readiness with:"
    echo "  rhizo who"
    echo ""
    echo "CRITICAL ORCHESTRATOR MANDATE:"
    echo "  - In Multiplexed Router Harnesses (Google Antigravity, OpenCode, Pi): Your session registers via `rhizo open " & cfg.orchestrator & "` / `rhizo session register`. The host Multiplexed Router Service (`rhizo router`) handles listening and routing automatically; blocking per-turn `rhizo listen` subprocesses are not required."
    echo "  - In CLI Subprocess Harnesses (Claude Code, Codex): You MUST arm your background listener NOW in this very turn before yielding:"
    echo "    rhizo listen " & cfg.orchestrator
    echo "  As soon as workers are pasted (or re-tagged), their WORKER_READY handshake will wake you!"
    echo "================================================================================\n"

    for card in generatedCards:
      echo "================================================================================"
      echo card.header
      echo card.subheader
      echo "--------------------------------------------------------------------------------"
      echo card.promptBlock
      if optSubagent:
        echo "--- SUBAGENT BRIEF: @" & card.worker.name & " ---"
        echo PromptFence10 & "markdown\n" & card.subagentBrief & "\n" & PromptFence10 & "\n"
      echo "================================================================================\n"
  else:
    echo "================================================================================"
    echo "  GARDEN SWARM BOOTSTRAP: " & cfg.project
    echo "================================================================================"
    echo "Adaptive Swarm On-Ramp Telemetry:"
    echo "Execution Mode: " & resolvedMode & " (harness default: " & defaultMode & ")"
    echo "Target Workers: " & $selectedWorkers.len & " | Currently Active in Project: " & $projectActive.len
    echo ""
    if availableIdlePeers.len > 0:
      echo "Two On-Ramp Pathways Available:"
      echo ""
      echo "--------------------------------------------------------------------------------"
      echo "PATHWAY A: DYNAMIC WORKER REPURPOSING (Recommended - Zero New Tabs!)"
      echo "--------------------------------------------------------------------------------"
      echo "Detected " & $availableIdlePeers.len & " active idle listener(s) standing by in the cluster:"
      for p in availableIdlePeers:
        let curProj = if p.project.len > 0: p.project else: "unassigned"
        echo "  - @" & p.agent & " (current project: " & curProj & ")"
      echo ""
      echo "Repurpose them immediately into '" & cfg.project & "' without opening new terminal windows:"
      for cmd in suggestedRepurposeCmds:
        echo "  " & cmd
      echo ""
      echo "--------------------------------------------------------------------------------"
      echo "PATHWAY B: FRESH SESSION BOOTSTRAPPING (Prompt Card Files)"
      echo "--------------------------------------------------------------------------------"
    elif categorization.foreignProjectPeers.len > 0:
      echo "Detected " & $categorization.foreignProjectPeers.len & " active worker(s) dedicated to other projects (protected from poaching)."
      echo "Bootstrap dedicated workers for project '" & cfg.project & "' below:"
      echo ""
    echo "Generated " & $selectedWorkers.len & " worker bootstrap prompt card(s) in:"
    echo "  " & tempBaseDir & "/"
    echo ""
    for idx, card in generatedCards:
      let w = card.worker
      let roleSlugPart = if w.roleSlug.len > 0: " (@" & w.roleSlug & ")" else: ""
      echo "  " & $(idx + 1) & ". @" & w.name & roleSlugPart & " (" & w.persona & " - " & w.role & ")"
      echo "     Harness:        " & w.harness & " | Model: " & w.model
      echo "     Prompt File:    " & card.filePath
      if w.roleSlug.len > 0 and w.roleSlug != w.name:
        echo "     Role File:      " & (tempBaseDir / (w.roleSlug & "-" & w.name & ".md"))
      echo "     Subagent Brief: " & card.subagentFilePath
      if supportsTmuxFactory(w.harness) or resolvedMode == "tmux":
        echo "     Tmux Command:   " & card.tmuxCommand
      echo ""
    echo "  All Cards Combined:"
    echo "     File: " & allWorkersFilePath
    echo ""
    if projectActive.len > 0:
      echo "  Active & Listening in Project (No Prompt Paste Needed!):"
      for pa in projectActive:
        echo "    - @" & pa.agent & " (ALREADY LISTENING)"
      echo ""

    if executeLaunch and resolvedMode == "tmux" and not dryRun:
      if getEnv("TMUX", "").len > 0 and findExe("tmux").len > 0:
        echo "Launching tmux worker windows:"
        for card in generatedCards:
          let (tOut, tCode) = execCmdEx(card.tmuxCommand)
          if tCode == 0:
            echo "  [SPAWNED] tmux window '" & card.worker.name & "'"
          else:
            stderr.writeLine("  [WARN] Failed to spawn tmux window '" & card.worker.name & "': " & tOut.strip())
        echo ""
      else:
        echo "Tmux commands ready to run (set $TMUX or run inside a tmux session to auto-spawn):"
        for card in generatedCards:
          echo "  " & card.tmuxCommand
        echo ""
    elif resolvedMode == "subagents":
      echo "Instructions for operator / orchestrator (Drillable Subagent Mode):"
      echo "  1. Spawn persistent drillable subagent sessions (Antigravity invoke_subagent / OpenCode child sessions)"
      echo "     using each worker's Subagent Brief above."
      echo "  2. Surface clickable session links (e.g. [Worker](conversation://<id>)) in chat for live inspection."
      echo "  3. Enforce 1:1 Vine strand isolation (vine new) and independent Key 3 audit before vine weave."
      echo ""
    else:
      echo "Instructions for operator:"
      echo "  1. Open a new terminal tab / session for each worker in your detected harness."
      echo "  2. Pass each worker's prompt file into its session (e.g. paste the file path)."
      echo "  3. Verify cluster registration: rhizo who"
      echo ""
    echo "CRITICAL ORCHESTRATOR MANDATE:"
    echo "  - In Multiplexed Router Harnesses (Google Antigravity, OpenCode, Pi): Your session registers via `rhizo open " & cfg.orchestrator & "` / `rhizo session register`. The host Multiplexed Router Service (`rhizo router`) handles listening and routing automatically; blocking per-turn `rhizo listen` subprocesses are not required."
    echo "  - In CLI Subprocess Harnesses (Claude Code, Codex): You MUST arm your background listener NOW in this very turn before yielding:"
    echo "    rhizo listen " & cfg.orchestrator
    echo "  As soon as workers are pasted (or re-tagged), their WORKER_READY handshake will wake you!"
    echo "================================================================================"

  return 0

proc doLaunch*(
  projectDir: string,
  swarmFile: string,
  targetWorker: string,
  writeFileParam: string,
  jsonOutput: bool,
  optOrchAgent: string = "",
  inlineOutput: bool = false,
  forcePrompts: bool = false,
  optProject: string = "",
  workerCount: int = 0,
  optHarness: string = "",
  optMode: string = "",
  optSubagent: bool = false,
  optTmux: bool = false,
  optTaskId: string = "",
  dryRun: bool = false,
  explicitForcePrompts: bool = false
): int =
  return doPrompts(
    projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput,
    optOrchAgent, inlineOutput, forcePrompts, optProject, workerCount,
    optHarness, optMode, optSubagent, optTmux, optTaskId, dryRun,
    explicitForcePrompts, executeLaunch = true
  )

proc doRepurpose*(
  workers: seq[string],
  projectParam: string = "",
  roleParam: string = "",
  tagsParam: string = "",
  selfTag: bool = false,
  expectedTagsParam: string = "",
  force: bool = false,
  swarmFileParam: string = "",
  jsonOutput: bool = false,
  allowCrossProject: bool = false
): int =
  let root = findProjectRoot()
  let hasGardenToml = fileExists(root / DefaultConfigFileName) or fileExists(root / "garden.toml")
  let targetProj = if projectParam.len > 0: projectParam.strip()
                   elif hasGardenToml and root.lastPathPart.toLowerAscii.replace(" ", "-") != "default":
                     root.lastPathPart.toLowerAscii.replace(" ", "-")
                   else: ""

  if workers.len == 0:
    let errMsg = "Missing required worker(s). Specify worker names positionally or via --worker <name>."
    if jsonOutput:
      echo $(%*{"status": "error", "error": errMsg})
    else:
      stderr.writeLine("[garden repurpose] Error: " & errMsg)
    return 1

  if targetProj.len == 0 or targetProj == "default":
    let errMsg = "Missing required --project <project> for garden repurpose (no garden.toml found in project root)."
    if jsonOutput:
      echo $(%*{"status": "error", "error": errMsg})
    else:
      stderr.writeLine("[garden repurpose] Error: " & errMsg)
    return 1

  if roleParam.strip().len == 0 and not selfTag:
    let errMsg = "Missing required role assignment. Specify --role <role> or --self-tag for garden repurpose."
    if jsonOutput:
      echo $(%*{"status": "error", "error": errMsg})
    else:
      stderr.writeLine("[garden repurpose] Error: " & errMsg)
    return 1

  let cfg = loadSwarmConfig(root, swarmFileParam)
  let categorization = queryClusterAgents(targetProj, cfg.workers)

  var targetWorkers = workers

  # Check for cross-project worker hijacking unless --allow-cross-project is passed
  if not allowCrossProject:
    for tw in targetWorkers:
      let twLower = tw.toLowerAscii()
      for ca in categorization.allAgents:
        if ca.agent.toLowerAscii() == twLower:
          let caProjLower = ca.project.toLowerAscii()
          let isForeignProject = caProjLower.len > 0 and
                                 caProjLower != targetProj.toLowerAscii() and
                                 caProjLower notin ["", "default", "unassigned"] and
                                 not (("pool" in ca.tags) or ("float" in ca.tags) or ("shared" in ca.tags))
          if isForeignProject:
            let errMsg = "Worker '@" & tw & "' is currently assigned to project '" & ca.project & "'. Cross-project worker hijacking is prohibited. Generate dedicated workers for project '" & targetProj & "' via 'garden prompts' or pass --allow-cross-project to override."
            if jsonOutput:
              echo $(%*{"status": "error", "error": errMsg, "agent": tw, "project": ca.project, "target_project": targetProj})
            else:
              stderr.writeLine("[garden repurpose] Error: " & errMsg)
            return 1
          break

  # Check for busy workers unless force is enabled (Negative Control)
  for tw in targetWorkers:
    let twLower = tw.toLowerAscii()
    for bp in categorization.busyClusterPeers:
      if bp.agent.toLowerAscii() == twLower:
        if not force:
          let errMsg = "Worker '@" & tw & "' is currently BUSY (" & bp.state & "). Use --force to override."
          if jsonOutput:
            echo $(%*{"status": "error", "error": errMsg, "agent": tw, "state": bp.state})
          else:
            stderr.writeLine("[garden repurpose] Error: " & errMsg)
          return 1

  var candidateRolesJson = newJArray()
  if cfg.workers.len > 0:
    for w in cfg.workers:
      var jw = newJObject()
      jw["role"] = %w.role
      jw["persona"] = %w.persona
      jw["tags"] = %(w.tags)
      candidateRolesJson.add(jw)
  else:
    candidateRolesJson.add(%*{
      "role": "Staff Systems Architect",
      "persona": pickWhimsicalPersona("architect", targetProj),
      "tags": @[targetProj, "architect", "systems", "architecture", "invariants"]
    })
    candidateRolesJson.add(%*{
      "role": "Verification & Adversarial Auditor",
      "persona": pickWhimsicalPersona("auditor", targetProj),
      "tags": @[targetProj, "auditor", "qa", "audit", "verifier", "purist"]
    })
    candidateRolesJson.add(%*{
      "role": "DevEx & Implementation Lead",
      "persona": pickWhimsicalPersona("implementer", targetProj),
      "tags": @[targetProj, "implementer", "dev", "devex", "build", "implementation"]
    })

  var expectedTagsSeq: seq[string] = @[]
  if expectedTagsParam.len > 0:
    for t in expectedTagsParam.split(","):
      let clean = t.strip()
      if clean.len > 0: expectedTagsSeq.add(clean)

  type RepurposedResult = object
    agent: string
    role: string
    tags: seq[string]
    mode: string
    status: string

  var results: seq[RepurposedResult] = @[]

  for idx, tw in targetWorkers:
    var assignedRole = roleParam
    var assignedTags: seq[string] = @[]
    if tagsParam.len > 0:
      for t in tagsParam.split(","):
        let clean = t.strip()
        if clean.len > 0: assignedTags.add(clean)

    if assignedRole.len == 0:
      if idx < cfg.workers.len:
        assignedRole = cfg.workers[idx].role
        if assignedTags.len == 0:
          assignedTags = cfg.workers[idx].tags
      else:
        assignedRole = "Swarm Worker"
        if assignedTags.len == 0:
          assignedTags = @[targetProj, "worker"]

    if assignedTags.len == 0:
      assignedTags = @[targetProj, assignedRole.toLowerAscii().replace(" ", "-")]

    let mode = if selfTag: "self_tag" else: "direct"
    let tagsCsv = assignedTags.join(",")

    var reassignCmd = "rhizo reassign " & quoteShell(tw) & " --project " & quoteShell(targetProj) & " --role " & quoteShell(assignedRole) & " --tags " & quoteShell(tagsCsv)
    try:
      discard execCmdEx(reassignCmd)
    except CatchableError:
      discard

    if selfTag:
      var offerObj = newJObject()
      offerObj["type"] = %"directive"
      offerObj["subject"] = %"SWARM_REPURPOSE_OFFER"
      var bodyObj = newJObject()
      bodyObj["target_project"] = %targetProj
      bodyObj["mode"] = %"self_tag"
      bodyObj["assigned_role"] = %assignedRole
      bodyObj["candidate_roles"] = candidateRolesJson
      if expectedTagsSeq.len > 0:
        bodyObj["expected_tags"] = %expectedTagsSeq
      offerObj["body"] = bodyObj

      let sendCmd = "rhizo send --to " & quoteShell(tw) & " --subject " & quoteShell("SWARM_REPURPOSE_OFFER") & " --body " & quoteShell($offerObj)
      try:
        discard execCmdEx(sendCmd)
      except CatchableError:
        discard

    results.add(RepurposedResult(
      agent: tw,
      role: assignedRole,
      tags: assignedTags,
      mode: mode,
      status: "REASSIGNED"
    ))

  if jsonOutput:
    var jObj = newJObject()
    jObj["status"] = %"ok"
    jObj["action"] = %"repurpose"
    jObj["project"] = %targetProj
    jObj["repurposed_count"] = %results.len
    var jRes = newJArray()
    for r in results:
      var jr = newJObject()
      jr["agent"] = %r.agent
      jr["role"] = %r.role
      jr["tags"] = %r.tags
      jr["mode"] = %r.mode
      jr["status"] = %r.status
      jRes.add(jr)
    jObj["repurposed_workers"] = jRes
    echo pretty(jObj)
    return 0

  echo "================================================================================"
  echo "  GARDEN WORKER REPURPOSING: " & targetProj
  echo "================================================================================"
  echo "Successfully dispatched repurposing directive(s) to " & $results.len & " worker(s):"
  for r in results:
    echo "  - @" & r.agent & " -> Role: " & r.role & " (Tags: " & r.tags.join(", ") & ")"
    if r.mode == "self_tag":
      echo "      (Self-Tagging Capability Handshake offer dispatched)"
  echo ""
  echo "Workers will announce WORKER_READY once enrolled."
  echo "Verify with: rhizo who"
  echo "================================================================================"
  return 0

proc doInit*(targetDir: string, force: bool, optOrchAgent: string = ""): int =
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
execution_mode = "auto" # auto, subagents, tmux, prompts
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

  echo "[garden] Initialization complete for " & root
  return 0

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

proc validateRosterSender*(cfg: SwarmConfig, sender: string, whoList: JsonNode = nil): bool =
  let normSender = sender.toLowerAscii.strip()
  if normSender.len == 0: return false
  if normSender == cfg.orchestrator.toLowerAscii.strip(): return true
  if cfg.orchestratorAgent.len > 0 and normSender == cfg.orchestratorAgent.toLowerAscii.strip(): return true
  for w in cfg.workers:
    if normSender == w.name.toLowerAscii.strip(): return true
    if w.roleSlug.len > 0:
      if normSender == (cfg.project.toLowerAscii & "-" & w.roleSlug.toLowerAscii) or normSender == w.roleSlug.toLowerAscii:
        return true

  # Dynamic Redis discovery fallback (when sender is not in static config)
  const roleKeywords = ["orchestrator", "lead", "worker", "implementer", "architect", "auditor", "reviewer", "dev", "engineer", "botanist", "keeper"]
  try:
    var wJson = whoList
    if wJson.isNil:
      let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let trimmed = whoOut.strip()
        if trimmed.startsWith("["):
          wJson = parseJson(trimmed)
        elif trimmed.startsWith("{"):
          let obj = parseJson(trimmed)
          if obj.hasKey("agents") and obj["agents"].kind == JArray:
            wJson = obj["agents"]
    if not wJson.isNil and wJson.kind == JArray:
      for item in wJson:
        let itemProj = if item.hasKey("project"): item["project"].getStr().toLowerAscii() else: ""
        let itemAgent = if item.hasKey("agent"): item["agent"].getStr().strip() elif item.hasKey("name"): item["name"].getStr().strip() else: ""
        if itemAgent.toLowerAscii == normSender:
          if cfg.project.len > 0 and itemProj.len > 0 and itemProj != cfg.project.toLowerAscii():
            return false
          var roleOrTagOk = false
          for r in roleKeywords:
            if normSender.contains(r):
              roleOrTagOk = true
              break
          if not roleOrTagOk and item.hasKey("tags") and item["tags"].kind == JArray:
            for t in item["tags"]:
              let lowTag = t.getStr().toLowerAscii()
              if (cfg.project.len > 0 and lowTag == cfg.project.toLowerAscii()) or lowTag in roleKeywords:
                roleOrTagOk = true
                break
              for r in roleKeywords:
                if lowTag.contains(r):
                  roleOrTagOk = true
                  break
              if roleOrTagOk: break
          if not roleOrTagOk and item.hasKey("role"):
            let lowRole = item["role"].getStr().toLowerAscii()
            for r in roleKeywords:
              if lowRole.contains(r):
                roleOrTagOk = true
                break
          return roleOrTagOk
  except CatchableError:
    discard

  return false

proc doRosterGuard*(sender: string, jsonOutput: bool = false, swarmFile: string = "", projectDir: string = "", fix: bool = false, optProject: string = ""): int =
  let cfg = loadSwarmConfig(projectDir, swarmFile, optProject = optProject)
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
            if validateRosterSender(cfg, ag, parsedList):
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
  let root = if projectDir.len > 0: canonicalizePath(projectDir) else: findProjectRoot()
  let gardenDir = root / ".garden"
  let sessionFile = gardenDir / "session.json"
  if fileExists(sessionFile):
    try: removeFile(sessionFile) except CatchableError: discard

  let projName = if root.len > 0: root.splitPath.tail.toLowerAscii().replace(" ", "-") else: getCurrentDir().splitPath.tail.toLowerAscii().replace(" ", "-")

  let effectiveAgent = if agentName.len > 0: agentName else: getEnv("RHIZO_AGENT_NAME", "")
  let effectiveRole = if role.len > 0: role else: "worker"
  let effectiveOrch = if orchestrator.len > 0: orchestrator
                      else: (let o = discoverOrchestrator(projName); if o.len > 0: o else: "orchestrator")

  case action.toLowerAscii()
  of "save", "set":
    let data = %*{
      "agent": effectiveAgent,
      "project": projName,
      "role": effectiveRole,
      "orchestrator": effectiveOrch,
      "workspace": root,
      "on_disk_json": false,
      "updated_at": now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    }
    if jsonOutput:
      echo pretty(data)
    else:
      echo "[garden session] Active session (session.json eliminated; managed dynamically): @" & effectiveAgent
    return 0

  of "load", "get", "show":
    let data = %*{
      "agent": effectiveAgent,
      "project": projName,
      "role": effectiveRole,
      "orchestrator": effectiveOrch,
      "workspace": root,
      "on_disk_json": false
    }
    if jsonOutput:
      echo pretty(data)
    else:
      echo "Active Garden Session (Dynamic Redis/Environment):"
      echo "  Agent       : @" & effectiveAgent
      echo "  Project     : " & projName
      echo "  Role        : " & effectiveRole
      echo "  Orchestrator: @" & effectiveOrch
    return 0

  of "clear", "rm", "delete":
    if jsonOutput:
      echo $(%*{"status": "ok", "message": "Session state cleared (session.json purged)"})
    else:
      echo "[garden session] Cleared session state (session.json purged)"
    return 0

  else:
    stderr.writeLine("[garden session] Unknown action: " & action & " (valid: save, load, clear)")
    return 1

proc doTeardown*(swarmFileParam: string = "", projectDir: string = "", optProject: string = ""): int =
  let root = if projectDir.len > 0: canonicalizePath(projectDir) else: findProjectRoot()
  let cfg = loadSwarmConfig(root, swarmFileParam, optProject = optProject)
  let proj = cfg.project

  # 1. Purge legacy garden-swarm.json if present
  let legacySwarm = root / "garden-swarm.json"
  if fileExists(legacySwarm):
    try: removeFile(legacySwarm) except CatchableError: discard

  # 2. Redis-native dynamic discovery of active project workers
  let cluster = queryClusterAgents(proj, cfg.workers)
  var closed: seq[string] = @[]
  if cluster.projectActive.len > 0:
    for ca in cluster.projectActive:
      echo "[garden] Closing active project agent @" & ca.agent & " in Redis..."
      discard execCmdEx("rhizo close " & quoteShell(ca.agent))
      closed.add(ca.agent)

  # Close configured swarm workers and default triad fallbacks if not already closed
  for w in cfg.workers:
    if w.name.len > 0 and w.name notin closed:
      echo "[garden] Closing agent @" & w.name & " in Redis..."
      try:
        discard execCmdEx("rhizo close " & quoteShell(w.name))
        closed.add(w.name)
      except CatchableError:
        discard

  for role in ["architect", "auditor", "implementer"]:
    let wname = proj & "-" & role
    if wname notin closed:
      echo "[garden] Closing agent @" & wname & " in Redis..."
      try:
        discard execCmdEx("rhizo close " & quoteShell(wname))
        closed.add(wname)
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

    # Auto-sync ROADMAP.md from botanical seeds if present
    try:
      let rm = buildRoadmap(root)
      if fileExists(root / "ROADMAP.md"):
        discard saveRoadmap(rm, root, writeMarkdown = true)
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

  # In-memory botanical roadmap compilation: zero JSON written to disk!
  var mdPath = ""
  if writeMarkdown:
    let (_, mPath) = saveRoadmap(rm, root, writeMarkdown = true, markdownPath = markdownPath)
    mdPath = mPath

  if jsonOutput:
    echo pretty(rm.toJson())
  elif writeMarkdown:
    echo "[garden roadmap] Wrote re-entrant Markdown roadmap to " & mdPath
  else:
    echo rm.toMarkdown()
  return 0

proc unknownOptionError*(subcmd, opt, validOpts, usage: string) =
  stderr.writeLine("Error: Unknown option " & opt & " for garden " & subcmd)
  if validOpts.len > 0:
    stderr.writeLine("Valid options: " & validOpts)
  if usage.len > 0:
    stderr.writeLine("Usage: " & usage)
  quit(2)

proc hasHelpFlag*(args: seq[string]): bool =
  for a in args:
    if a == "--":
      return false
    if a in ["--help", "-h", "help"]:
      return true
  return false

proc printSubcommandHelp*(subcmd: string, args: seq[string] = @[]): bool =
  let cmd = subcmd.toLowerAscii
  case cmd
  of "init":
    echo "Usage: garden init [dir] [--force/-f] [--orchestrator/-a <agent>]"
    echo ""
    echo "Options:"
    echo "  [dir]                    Target directory (default: current directory)"
    echo "  --force, -f              Force overwrite existing garden.toml"
    echo "  --orchestrator, -a <name> Set default orchestrator agent name"
    return true
  of "plant":
    echo "Usage: garden plant <title> [--season <name>] [--sunlight <level>] [--tags <csv>] [--id <id>] [--project-dir <dir>] [--list] [--json]"
    echo ""
    echo "Options:"
    echo "  --title, --description, --prompt, -m <text> Explicit feature title (can also be positional)"
    echo "  --season, --milestone, --release, -s <name>  Seasonal allocation (e.g. spring, summer, autumn, winter)"
    echo "  --sunlight, --priority, -S <level>           Priority sunlight requirement (low, medium, high, blazing)"
    echo "  --tags, -t <csv>         Comma-separated taxonomy tags"
    echo "  --id <id>                Explicit custom seed identifier"
    echo "  --project-dir, -p <dir>  Target project directory"
    echo "  --list, -l               List all sown seeds"
    echo "  --json, -j               Output result as structured JSON"
    return true
  of "roadmap":
    echo "Usage: garden roadmap [--season <name>] [--markdown] [--write [path]] [--sync] [--project-dir <dir>] [--json]"
    echo ""
    echo "Options:"
    echo "  --season, -S <name>      Filter roadmap to specific season/milestone"
    echo "  --markdown, -m           Print formatted markdown roadmap to stdout (default)"
    echo "  --write, -w [path]       Write ROADMAP.md to project root or specified path"
    echo "  --sync, -s               Synchronize ROADMAP.md from botanical seeds"
    echo "  --project-dir, -p <dir>  Target project directory"
    echo "  --json, -j               Output structured roadmap as JSON"
    return true
  of "germinate":
    echo "Usage: garden germinate <dispatch|prompt|inline|status> <seed_id> [options...]"
    echo ""
    echo "Options:"
    echo "  --seed, --id, -s <id>    Explicit seed identifier (can also be positional)"
    echo "  --worker, -w <name>      Filter prompt generation to target worker (for 'prompt')"
    echo "  --queue, -q <name>       Target queue for 'dispatch' (default: queue:<project>:tasks)"
    echo "  --inline, -i             Print raw 10-backtick prompt cards directly to stdout"
    echo "  --project-dir, -p <dir>  Target project directory"
    echo "  --json, -j               Output result as structured JSON"
    return true
  of "repurpose":
    echo "Usage: garden repurpose [workers...] [--project <proj>] [--role <role>] [--tags <csv>] [--self-tag] [--expected-tags <csv>] [--allow-cross-project] [--force] [--json]"
    echo ""
    echo "Options:"
    echo "  --worker, --workers, --agent, --to <csv> Target worker name(s) (can also be positional)"
    echo "  --project, -p <proj>     Target project codename (required if no garden.toml exists)"
    echo "  --role, -r <role>        Target role assignment (required unless --self-tag is passed)"
    echo "  --tags, -t <csv>         Target taxonomy tags"
    echo "  --self-tag, -s           Offer candidate roles and allow worker to self-select matching tags"
    echo "  --expected-tags <csv>    Expected capabilities or tools required"
    echo "  --allow-cross-project    Allow repurposing a worker currently assigned to another project"
    echo "  --force, -f              Force repurposing even if worker is currently BUSY"
    echo "  --json, -j               Output result as structured JSON"
    return true
  of "prompts", "launch":
    echo "Usage: garden " & cmd & " [--workers <n>] [--harness <h>] [--mode <mode>] [--subagent] [--tmux] [--task <id>] [--dry-run] [--project <p>] [--worker <name>] [--force] [--write [file]] [--inline] [--json]"
    echo ""
    echo "Options:"
    echo "  --workers, --count <n>   Target worker count (defaults to full triad)"
    echo "  --harness <h>            Harness override for all workers (e.g. 'Claude Code CLI')"
    echo "  --mode <mode>            Execution mode override (auto, subagents, tmux, prompts)"
    echo "  --subagent, --subagents  Generate drillable subagent briefs (execution_mode=subagents)"
    echo "  --tmux                   Spawn/prepare tmux worker windows for CLI harnesses"
    echo "  --task <task_id>         Bind a specific task ID in generated subagent briefs"
    echo "  --dry-run                Prepare commands and metadata without spawning tmux windows"
    echo "  --project, -p <proj>     Target project codename or project directory"
    echo "  --worker, -w <name>      Filter prompt output to a specific worker"
    echo "  --force, --force-prompts Force prompt card generation (skips fast-path)"
    echo "  --write, -o [file]       Write generated prompts to markdown file (default: garden-prompts.md)"
    echo "  --inline, -i             Print raw 10-backtick prompt cards directly to stdout"
    echo "  --project-dir <dir>      Target project directory (default: current root)"
    echo "  --json                   Output prompts as JSON"
    return true
  of "status":
    echo "Usage: garden status [--json]"
    return true
  of "guide":
    echo "Usage: garden guide <install|check|uninstall> [path]"
    return true
  of "roster-guard":
    echo "Usage: garden roster-guard <sender> [--json] [--fix] [--swarm-file <file>] [--project-dir <dir>] [--project <proj>]"
    return true
  of "session":
    echo "Usage: garden session <save|load|clear> [options...]"
    echo "  save   [--agent <name>] [--role <role>] [--orchestrator <orch>]"
    echo "  load   [--json]"
    echo "  clear  [--json]"
    return true
  of "update":
    echo "Usage: garden update [--check] [--apply] [--skip <pkg@ver>] [--disable] [--enable] [--json]"
    return true
  of "teardown":
    echo "Usage: garden teardown [--project <name>]"
    return true
  else:
    return false

proc main*(customParams: seq[string] = @[], useCustomParams: bool = false) =
  let params = if useCustomParams: customParams else: commandLineParams()
  if params.len == 0 or params[0] in ["help", "-h", "--help"]:
    if params.len > 1 and printSubcommandHelp(params[1], params[2..^1]):
      quit(0)
    printHelp()
    quit(0)

  let subcmd = params[0].toLowerAscii()

  if hasHelpFlag(params[1..^1]):
    if printSubcommandHelp(subcmd, params[1..^1]):
      quit(0)
    printHelp()
    quit(0)

  case subcmd
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
    const plantValidOpts = "--title, --description, --prompt, -m, --season, --milestone, --release, -s, --sunlight, --priority, -S, --tags, -t, --id, --project-dir, -p, --list, -l, --json, -j"
    const plantUsage = "garden plant <title> [--season <name>] [--sunlight <level>] [--tags <csv>] [--id <id>] [--project-dir <dir>] [--list] [--json]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--list", "-l"]:
        listMode = true
      elif (a in ["--title", "--description", "--prompt", "-m"]) and i + 1 < params.len:
        inc i
        if title.len == 0: title = params[i]
        else: title &= " " & params[i]
      elif a.startsWith("--title="):
        let val = a[8..^1]
        if title.len == 0: title = val else: title &= " " & val
      elif a.startsWith("--description="):
        let val = a[14..^1]
        if title.len == 0: title = val else: title &= " " & val
      elif a.startsWith("--prompt="):
        let val = a[9..^1]
        if title.len == 0: title = val else: title &= " " & val
      elif a.startsWith("-m="):
        let val = a[3..^1]
        if title.len == 0: title = val else: title &= " " & val
      elif (a in ["--season", "--milestone", "--release", "-s"]) and i + 1 < params.len:
        inc i; season = params[i]
      elif a.startsWith("--season="):
        season = a[9..^1]
      elif a.startsWith("--milestone="):
        season = a[12..^1]
      elif a.startsWith("--release="):
        season = a[10..^1]
      elif (a in ["--sunlight", "--priority", "-S"]) and i + 1 < params.len:
        inc i; sunlight = params[i]
      elif a.startsWith("--sunlight="):
        sunlight = a[11..^1]
      elif a.startsWith("--priority="):
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
      elif a.startsWith("-"):
        unknownOptionError("plant", a, plantValidOpts, plantUsage)
      else:
        if title.len == 0:
          title = a
        else:
          title &= " " & a
      inc i
    if title.strip().len == 0 and not listMode:
      stderr.writeLine("Error: Missing required description for garden plant.")
      stderr.writeLine("Usage: " & plantUsage)
      quit(1)
    quit(doPlant(title, season, sunlight, tagsCsv, customId, projectDir, listMode, jsonOutput))
  of "roadmap":
    var season = ""
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var jsonOutput = false
    var writeMarkdown = false
    var markdownPath = ""
    const rmValidOpts = "--season, -S, --markdown, -m, --write, -w, --sync, -s, --project-dir, -p, --json, -j"
    const rmUsage = "garden roadmap [--season <name>] [--markdown] [--write [path]] [--sync] [--project-dir <dir>] [--json]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
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
      elif a.startsWith("-"):
        unknownOptionError("roadmap", a, rmValidOpts, rmUsage)
      inc i
    quit(doRoadmap(season, projectDir, jsonOutput, writeMarkdown, markdownPath))
  of "germinate":
    const germValidOpts = "--seed, --id, -s, --worker, -w, --queue, -q, --project-dir, -p, --inline, -i, --json, -j"
    const germUsage = "garden germinate <dispatch|prompt|inline|status> <seed_id> [options...]"
    if params.len < 2:
      stderr.writeLine("Error: Missing germinate action.")
      stderr.writeLine("Usage: " & germUsage)
      quit(1)
    if params[1].startsWith("-"):
      unknownOptionError("germinate", params[1], germValidOpts, germUsage)
    let action = params[1].toLowerAscii()
    if action notin ["dispatch", "prompt", "inline", "status"]:
      stderr.writeLine("Error: Unknown germinate action '" & action & "'. Valid actions: dispatch, prompt, inline, status.")
      stderr.writeLine("Usage: " & germUsage)
      quit(1)
    var seedId = ""
    var targetWorker = ""
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var jsonOutput = false
    var inlineOutput = false
    var customQueue = ""
    var i = 2
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--inline", "-i"]:
        inlineOutput = true
      elif (a in ["--seed", "--id", "-s"]) and i + 1 < params.len:
        inc i; seedId = params[i]
      elif a.startsWith("--seed="):
        seedId = a[7..^1]
      elif a.startsWith("--id="):
        seedId = a[5..^1]
      elif a.startsWith("-s="):
        seedId = a[3..^1]
      elif (a in ["--worker", "-w"]) and i + 1 < params.len:
        inc i; targetWorker = params[i]
      elif a.startsWith("--worker="):
        targetWorker = a[9..^1]
      elif (a in ["--queue", "-q"]) and i + 1 < params.len:
        inc i; customQueue = params[i]
      elif a.startsWith("--queue="):
        customQueue = a[8..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif a.startsWith("-"):
        unknownOptionError("germinate", a, germValidOpts, germUsage)
      elif not a.startsWith("-") and seedId.len == 0:
        seedId = a
      inc i

    if seedId.len == 0:
      stderr.writeLine("Error: Missing required <seed_id> for garden germinate " & action & ".")
      stderr.writeLine("Usage: garden germinate " & action & " <seed_id> [options...]")
      let root = if projectDir.len > 0: projectDir else: findProjectRoot()
      try:
        let seeds = listSeeds(root)
        if seeds.len > 0:
          stderr.writeLine("\nAvailable seeds:")
          for s in seeds:
            stderr.writeLine("  - " & s.id & " (" & s.title & ") [" & s.status & "]")
        else:
          stderr.writeLine("\nNo seeds found. Sow one first with 'garden plant <title>'.")
      except CatchableError:
        discard
      quit(1)

    quit(doGerminate(action, seedId, targetWorker, projectDir, jsonOutput, inlineOutput, customQueue))
  of "repurpose":
    var workers: seq[string] = @[]
    var projectParam = ""
    var roleParam = ""
    var tagsParam = ""
    var selfTag = false
    var expectedTagsParam = ""
    var force = false
    var allowCrossProject = false
    var swarmFileParam = getEnv("GARDEN_SWARM_FILE", "")
    var jsonOutput = false
    const repValidOpts = "--worker, --workers, --agent, --agents, --to, --project, -p, --role, -r, --tags, -t, --self-tag, -s, --expected-tags, --allow-cross-project, --cross-project, --force, -f, --swarm-file, -S, --json, -j"
    const repUsage = "garden repurpose [workers...] [--project <proj>] [--role <role>] [--tags <csv>] [--self-tag] [--expected-tags <csv>] [--allow-cross-project] [--force] [--json]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
        jsonOutput = true
      elif a in ["--self-tag", "-s"]:
        selfTag = true
      elif a in ["--force", "-f"]:
        force = true
      elif a in ["--allow-cross-project", "--cross-project"]:
        allowCrossProject = true
      elif (a in ["--worker", "--workers", "--agent", "--agents", "--to"]) and i + 1 < params.len:
        inc i
        for item in params[i].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif a.startsWith("--worker="):
        for item in a[9..^1].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif a.startsWith("--workers="):
        for item in a[10..^1].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif a.startsWith("--agent="):
        for item in a[8..^1].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif a.startsWith("--agents="):
        for item in a[9..^1].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif a.startsWith("--to="):
        for item in a[5..^1].split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      elif (a in ["--project", "-p"]) and i + 1 < params.len:
        inc i; projectParam = params[i]
      elif a.startsWith("--project="):
        projectParam = a[10..^1]
      elif (a in ["--role", "-r"]) and i + 1 < params.len:
        inc i; roleParam = params[i]
      elif a.startsWith("--role="):
        roleParam = a[7..^1]
      elif (a in ["--tags", "-t"]) and i + 1 < params.len:
        inc i; tagsParam = params[i]
      elif a.startsWith("--tags="):
        tagsParam = a[7..^1]
      elif a == "--expected-tags" and i + 1 < params.len:
        inc i; expectedTagsParam = params[i]
      elif a.startsWith("--expected-tags="):
        expectedTagsParam = a[16..^1]
      elif (a in ["--swarm-file", "-S"]) and i + 1 < params.len:
        inc i; swarmFileParam = params[i]
      elif a.startsWith("--swarm-file="):
        swarmFileParam = a[13..^1]
      elif a.startsWith("-"):
        unknownOptionError("repurpose", a, repValidOpts, repUsage)
      else:
        for item in a.split(','):
          let trimmed = item.strip().strip(chars = {'@'})
          if trimmed.len > 0: workers.add(trimmed)
      inc i

    if workers.len == 0:
      let errMsg = "Missing required worker(s). Specify worker names positionally or via --worker <name>."
      if jsonOutput:
        echo $(%*{"status": "error", "error": errMsg})
      else:
        stderr.writeLine("Error: " & errMsg)
        stderr.writeLine("Usage: " & repUsage)
      quit(1)

    let root = findProjectRoot()
    let hasGardenToml = fileExists(root / DefaultConfigFileName) or fileExists(root / "garden.toml")
    let targetProj = if projectParam.len > 0: projectParam.strip()
                     elif hasGardenToml and root.lastPathPart.toLowerAscii.replace(" ", "-") != "default":
                       root.lastPathPart.toLowerAscii.replace(" ", "-")
                     else: ""

    if targetProj.len == 0 or targetProj == "default":
      let errMsg = "Missing required --project <project> for garden repurpose (no garden.toml found in project root)."
      if jsonOutput:
        echo $(%*{"status": "error", "error": errMsg})
      else:
        stderr.writeLine("Error: " & errMsg)
        stderr.writeLine("Usage: " & repUsage)
      quit(1)

    if roleParam.strip().len == 0 and not selfTag:
      let errMsg = "Missing required role assignment. Specify --role <role> or --self-tag for garden repurpose."
      if jsonOutput:
        echo $(%*{"status": "error", "error": errMsg})
      else:
        stderr.writeLine("Error: " & errMsg)
        stderr.writeLine("Usage: " & repUsage)
      quit(1)

    quit(doRepurpose(workers, targetProj, roleParam, tagsParam, selfTag, expectedTagsParam, force, swarmFileParam, jsonOutput, allowCrossProject))
  of "init":
    var targetDir = ""
    var force = false
    var optOrchAgent = ""
    const initValidOpts = "--force, -f, --orchestrator, -o, -a, --orchestrator-agent"
    const initUsage = "garden init [dir] [--force] [--orchestrator <name>]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--force", "-f"]:
        force = true
      elif (a in ["--orchestrator", "-o", "--orchestrator-agent", "-a"]) and i + 1 < params.len:
        inc i; optOrchAgent = params[i]
      elif a.startsWith("--orchestrator="):
        optOrchAgent = a[15..^1]
      elif a.startsWith("--orchestrator-agent="):
        optOrchAgent = a[21..^1]
      elif a.startsWith("-"):
        unknownOptionError("init", a, initValidOpts, initUsage)
      else:
        if targetDir.len == 0:
          targetDir = a
      inc i
    quit(doInit(targetDir, force, optOrchAgent))
  of "prompts", "launch":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var targetWorker = ""
    var writeFileParam = ""
    var jsonOutput = false
    var inlineOutput = false
    var forcePrompts = false
    var explicitForcePrompts = false
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var optOrchAgent = ""
    var optProject = ""
    var workerCount = 0
    var optHarness = ""
    var optMode = ""
    var optSubagent = false
    var optTmux = false
    var optTaskId = ""
    var dryRun = false
    const pValidOpts = "--workers, --count, --harness, --mode, --subagent, --subagents, --tmux, --task, --dry-run, --project, --force, --force-prompts, --cards, --worker, -w, --role, -r, --write, -o, --inline, -i, --project-dir, -p, --swarm-file, -f, --orchestrator, -a, --orchestrator-agent, --json"
    let pUsage = "garden " & subcmd & " [--workers <n>] [--harness <h>] [--mode <mode>] [--subagent] [--tmux] [--task <id>] [--dry-run] [--project <p>] [--worker <name>] [--role <role>] [--force] [--write [file]] [--inline] [--json]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif (a in ["--swarm-file", "-f"]) and i + 1 < params.len:
        inc i; swarmFile = params[i]
      elif a.startsWith("--swarm-file="):
        swarmFile = a[13..^1]
      elif (a in ["--worker", "-w", "--role", "-r"]) and i + 1 < params.len:
        inc i; targetWorker = params[i]
      elif a.startsWith("--worker="):
        targetWorker = a[9..^1]
      elif a.startsWith("--role="):
        targetWorker = a[7..^1]
      elif (a in ["--orchestrator", "-a", "--orchestrator-agent"]) and i + 1 < params.len:
        inc i; optOrchAgent = params[i]
      elif a.startsWith("--orchestrator="):
        optOrchAgent = a[15..^1]
      elif a.startsWith("--orchestrator-agent="):
        optOrchAgent = a[21..^1]
      elif a == "--force":
        forcePrompts = true
      elif a in ["--force-prompts", "--cards"]:
        forcePrompts = true
        explicitForcePrompts = true
      elif a in ["--subagent", "--subagents"]:
        optSubagent = true
      elif a == "--tmux":
        optTmux = true
      elif a == "--dry-run":
        dryRun = true
      elif a == "--mode" and i + 1 < params.len:
        inc i; optMode = params[i]
      elif a.startsWith("--mode="):
        optMode = a[7..^1]
      elif a == "--task" and i + 1 < params.len:
        inc i; optTaskId = params[i]
      elif a.startsWith("--task="):
        optTaskId = a[7..^1]
      elif a in ["--write", "-o"]:
        if i + 1 < params.len and not params[i+1].startsWith("-"):
          inc i; writeFileParam = params[i]
        else:
          writeFileParam = "garden-prompts.md"
      elif a.startsWith("--write="):
        writeFileParam = a[8..^1]
      elif a == "--json":
        jsonOutput = true
      elif a in ["--inline", "-i"]:
        inlineOutput = true
      elif (a in ["--workers", "--count"]) and i + 1 < params.len:
        inc i
        try: workerCount = parseInt(params[i]) except CatchableError: discard
      elif a.startsWith("--workers="):
        try: workerCount = parseInt(a[10..^1]) except CatchableError: discard
      elif a.startsWith("--count="):
        try: workerCount = parseInt(a[8..^1]) except CatchableError: discard
      elif a == "--harness" and i + 1 < params.len:
        inc i; optHarness = params[i]
      elif a.startsWith("--harness="):
        optHarness = a[10..^1]
      elif a == "--project" and i + 1 < params.len:
        inc i; optProject = params[i]
      elif a.startsWith("--project="):
        optProject = a[10..^1]
      elif a == "--project-dir" and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a == "-p" and i + 1 < params.len:
        inc i
        let val = params[i]
        if dirExists(val) or '/' in val or '\\' in val: projectDir = val else: optProject = val
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif a in ["--mode", "--task", "--harness", "--project"] and i + 1 >= params.len:
        stderr.writeLine("[garden " & subcmd & "] Error: Missing required value for " & a & "\nUsage: " & pUsage)
        quit(1)
      elif a.startsWith("-"):
        unknownOptionError(subcmd, a, pValidOpts, pUsage)
      inc i
    if subcmd == "launch":
      quit(doLaunch(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput, forcePrompts, optProject, workerCount, optHarness, optMode, optSubagent, optTmux, optTaskId, dryRun, explicitForcePrompts))
    else:
      quit(doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput, forcePrompts, optProject, workerCount, optHarness, optMode, optSubagent, optTmux, optTaskId, dryRun, explicitForcePrompts))
  of "status":
    var jsonOutput = false
    const statValidOpts = "--json, -j"
    const statUsage = "garden status [--json]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
        jsonOutput = true
      elif a.startsWith("-"):
        unknownOptionError("status", a, statValidOpts, statUsage)
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
    var projectDir = ""
    var optProject = ""
    const tdValidOpts = "--swarm-file, -f, --project-dir, -p, --project"
    const tdUsage = "garden teardown [--swarm-file <file>] [--project-dir <dir>] [--project <name>]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif (a in ["--swarm-file", "-f"]) and i + 1 < params.len:
        inc i; swarmFile = params[i]
      elif a.startsWith("--swarm-file="):
        swarmFile = a[13..^1]
      elif a == "--project-dir" and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a == "-p" and i + 1 < params.len:
        inc i
        let val = params[i]
        if dirExists(val) or '/' in val or '\\' in val: projectDir = val else: optProject = val
      elif a.startsWith("--project-dir="):
        projectDir = a[14..^1]
      elif a == "--project" and i + 1 < params.len:
        inc i; optProject = params[i]
      elif a.startsWith("--project="):
        optProject = a[10..^1]
      elif a.startsWith("-"):
        unknownOptionError("teardown", a, tdValidOpts, tdUsage)
      inc i
    quit(doTeardown(swarmFile, projectDir, optProject))
  of "roster-guard", "validate-sender", "ingest-guard":
    var sender = ""
    var jsonOutput = false
    var fix = false
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var projectDir = getEnv("GARDEN_PROJECT_DIR", "")
    var optProject = ""
    const rgValidOpts = "--json, -j, --fix, -F, --audit, -a, --swarm-file, -f, --project-dir, -p, --project, -P"
    const rgUsage = "garden roster-guard <sender> [--json] [--fix] [--project <proj>]"
    var i = 1
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]: jsonOutput = true
      elif a in ["--fix", "-F"]: fix = true
      elif a in ["--audit", "-a"]: discard
      elif (a in ["--swarm-file", "-f"]) and i + 1 < params.len:
        inc i; swarmFile = params[i]
      elif a.startsWith("--swarm-file="): swarmFile = a[13..^1]
      elif (a in ["--project-dir", "-p"]) and i + 1 < params.len:
        inc i; projectDir = params[i]
      elif a.startsWith("--project-dir="): projectDir = a[14..^1]
      elif (a in ["--project", "-P"]) and i + 1 < params.len:
        inc i; optProject = params[i]
      elif a.startsWith("--project="): optProject = a[10..^1]
      elif a.startsWith("-"):
        unknownOptionError("roster-guard", a, rgValidOpts, rgUsage)
      elif not a.startsWith("-") and sender.len == 0:
        sender = a
      inc i
    quit(doRosterGuard(sender, jsonOutput, swarmFile, projectDir, fix, optProject))
  of "session":
    const sessValidOpts = "--agent, -a, --role, -r, --orchestrator, -o, --project-dir, -p, --json, -j"
    const sessUsage = "garden session <save|load|clear> [options...]\n  save   [--agent <name>] [--role <role>] [--orchestrator <orch>]\n  load   [--json]\n  clear  [--json]"
    if params.len < 2:
      stderr.writeLine("Usage: " & sessUsage)
      quit(1)
    if params[1].startsWith("-"):
      unknownOptionError("session", params[1], sessValidOpts, sessUsage)
    let action = params[1].toLowerAscii()
    if action notin ["save", "set", "load", "get", "show", "clear", "rm", "delete"]:
      stderr.writeLine("[garden session] Unknown action: " & action & " (valid: save, load, clear)")
      quit(1)
    var agentName = ""
    var role = ""
    var orch = ""
    var projectDir = ""
    var jsonOutput = false
    var i = 2
    while i < params.len:
      let a = params[i]
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]: jsonOutput = true
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
      elif a.startsWith("-"):
        unknownOptionError("session", a, sessValidOpts, sessUsage)
      inc i
    quit(doSession(action, agentName, role, orch, projectDir, jsonOutput))
  of "guide":
    const guideValidOpts = ""
    const guideUsage = "garden guide <install|check|uninstall> [path]"
    if params.len < 2:
      stderr.writeLine("Usage: " & guideUsage)
      quit(1)
    if params[1].startsWith("-"):
      unknownOptionError("guide", params[1], guideValidOpts, guideUsage)
    let action = params[1].toLowerAscii()
    if params.len > 2 and params[2].startsWith("-"):
      unknownOptionError("guide", params[2], guideValidOpts, guideUsage)
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
      of gsInstalled:
        if readFile(target).contains(CanonicalGuideContent.strip()):
          echo "[INSTALLED] Garden Guide is installed in: " & target
        else:
          stderr.writeLine("[OUTDATED] Garden Guide in " & target & " does not match canonical " & GuideVersion & " content (run 'garden guide install').")
          quit(1)
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
