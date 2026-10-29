# /Users/eek/Development/garden/src/garden.nim
# The Garden Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, times, random]
import guide
import seed
import germinate
import update
import roadmap

const
  GardenVersion = "0.2.26"
  DefaultConfigFileName = "garden.toml"
  PromptFence10 = "``````````"

type
  WorkerProfile* = enum
    wpImplementation, wpInvestigation, wpVerification, wpAudit

  HarnessType* = enum
    htAntigravity, htClaudeCode, htCodex, htOpenCode, htPi, htGeneric

  WorkerSpec* = object
    name*: string
    persona*: string
    role*: string
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
  --worker, -w <name>      Filter prompt output to a specific worker
  --write, -o [file]       Write generated prompts to markdown file (default: garden-prompts.md)
  --inline, -i             Print raw 10-backtick prompt cards directly to stdout
  --force-prompts, --cards Force prompt card generation (skips fast-path)
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

proc findProjectRoot*(startDir: string = ""): string =
  let envDir = getEnv("GARDEN_PROJECT_DIR", "")
  if envDir.len > 0 and dirExists(envDir):
    return envDir.normalizedPath
  var dir = if startDir.len > 0: startDir else: getCurrentDir()
  while dir.len > 0:
    let envCfg = getEnv("GARDEN_CONFIG", "")
    if (envCfg.len > 0 and fileExists(envCfg)) or
       fileExists(dir / "garden.toml") or 
       dirExists(dir / ".garden") or 
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
    let cmd = "rhizo leader status orchestrator:" & project & " --json"
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
      sJson = parseJson(readFile(customFile))
    except CatchableError as e:
      stderr.writeLine("[garden] Warning: Failed to parse custom swarm file: " & e.msg)

  if not sJson.isNil:
    try:
      result.project = if sJson.hasKey("project"): sJson["project"].getStr(projName) else: projName
      result.targetRepo = if sJson.hasKey("target_repo"): sJson["target_repo"].getStr(root) else: root
      
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
          spec.profile = if w.hasKey("profile"): w["profile"].getStr() elif w.hasKey("capability"): w["capability"].getStr() else: ""
          result.workers.add(spec)
    except CatchableError as e:
      stderr.writeLine("[garden] Warning: Failed to parse custom swarm file: " & e.msg)

  if result.workers.len == 0:
    # Synthesize default balanced triad dynamically on the fly from project/seed requirements
    result.project = projName
    result.targetRepo = root
    result.orchestrator = effectiveOrch
    result.orchestratorAgent = effectiveOrch

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
            if t notin seedTags and t != projName: seedTags.add(t)
      if activeSeedTitles.len > 0:
        seedContext = " Sown project seed(s): " & activeSeedTitles.join("; ") & "."
    except CatchableError:
      discard

    let archName = projName & "-architect"
    let auditName = projName & "-auditor"
    let implName = projName & "-implementer"
    let curHarness = detectCurrentHarness()

    let archPersona = pickWhimsicalPersona("architect", projName)
    let auditPersona = pickWhimsicalPersona("auditor", projName)
    let implPersona = pickWhimsicalPersona("implementer", projName)

    var archTags = @[projName, "systems", "architecture", "invariants"]
    var auditTags = @[projName, "qa", "audit", "verifier", "purist"]
    var implTags = @[projName, "dev", "devex", "build", "implementation"]
    for st in seedTags:
      if st notin implTags: implTags.add(st)

    result.workers.add(WorkerSpec(
      name: archName,
      persona: archPersona,
      role: "Staff Systems Architect",
      harness: curHarness,
      model: "Session Default (active in window/tab)",
      tags: archTags,
      profile: "investigation",
      systemPrompt: "You are " & archPersona & ", Staff Systems Architect for the " & projName & " project. Your mandate is macro-architecture correctness, invariant preservation, API contracts, cross-module boundaries, and eliminating architectural drift." & seedContext & " Ground all assertions in empirical code analysis. Coordinate exclusively over Rhizo with the Orchestrator (@" & result.orchestrator & "). Operate as an investigator and architectural reviewer.",
      opposingPriority: "Structural purity, invariant guarantees, and long-term maintainability over hasty quick fixes.",
      startupCommand: "rhizo open " & archName & " '" & projName & ",systems,architecture' && rhizo listen " & archName
    ))

    result.workers.add(WorkerSpec(
      name: auditName,
      persona: auditPersona,
      role: "Verification & Adversarial Auditor",
      harness: curHarness,
      model: "Session Default (active in window/tab)",
      tags: auditTags,
      profile: "audit",
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
      tags: implTags,
      profile: "implementation",
      systemPrompt: "You are " & implPersona & ", DevEx & Implementation Lead for the " & projName & " project. Your mandate is pragmatic, clean, high-velocity implementation in isolated Vine strands." & seedContext & " You execute tasks assigned by @" & result.orchestrator & ", maintain ergonomic developer workflows, verify Keys 1 & 2 with 'vine gate', submit for independent audit with 'vine submit', and report completed deliverables back over Rhizo. Remember: THE WORKER IS NOT THE AUDITOR; never attempt to self-audit.",
      opposingPriority: "High-velocity implementation, pragmatic delivery, and developer ergonomics.",
      startupCommand: "rhizo open " & implName & " '" & projName & ",dev,devex,build' && rhizo listen " & implName
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
  result &= "> You are operating in a DEDICATED, SOVEREIGN CODING SESSION. You are an autonomous peer worker, NOT an ephemeral subagent.\n\n"
  
  result &= "### 1. Identity & Mandate\n"
  result &= "- **Agent Codename**: `" & w.name & "`\n"
  result &= "- **Role**: " & w.role & "\n"
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

  result &= "# Broadcast Mutual Arrival Handshake (enqueued to Rhizo):\n"
  result &= "rhizo send --to \"" & cfg.orchestrator & "\" --subject \"WORKER_READY\" --body \"Worker @" & w.name & " (" & w.persona & " - " & w.role & ") initialized. Standing by for sprint assignment.\"\n"

  if harnessKind in [htOpenCode, htPi]:
    result &= "```\n"
    result &= "> [!NOTE]\n"
    result &= "> **In-Process Ear Active**: In OpenCode and Pi, your session maintains an internal event ear for Rhizo notifications.\n"
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
  if harnessKind notin [htOpenCode, htPi]:
    result &= "   - If the operator says to listen or arm ('/rhizo listen', 'arm listener', 'listen now'),\n"
    result &= "     you MUST invoke 'rhizo listen " & w.name & "' IMMEDIATELY in that turn.\n"
    result &= "     Never defer arming behind a multi-step plan ('I will listen when I finish X').\n"
  result &= "2. WORKER AUTONOMOUS EXECUTION (WHEN OPERATOR IS SILENT):\n"
  result &= "   You are an AUTONOMOUS CLUSTER WORKER, NOT A PASSIVE CHATBOT.\n"
  if harnessKind in [htOpenCode, htPi]:
    result &= "   When an incoming directive is delivered via your session's in-process event ear, a task has been received!\n"
  else:
    result &= "   When 'rhizo listen " & w.name & "' unblocks and exits, a task has been delivered into this session!\n"
  result &= "   - IMMEDIATE ACK UPON RECEIPT: Immediately claim the task ('rhizo task claim <id> --lease 900' or send a quick ACK reply to @" & cfg.orchestrator & " WITHOUT --listen)."
  if harnessKind == htAntigravity:
    result &= " In Tier 2 async harnesses (e.g. Antigravity), immediately launch 'rhizo listen " & w.name & "' in the background (`run_command(WaitMsBeforeAsync=500)`).\n"
    result &= "   - MANDATORY ANTIGRAVITY NON-YIELD INVARIANT: When launching your background listener, your harness will say: 'YOU MUST TAKE ONE OF THE FOLLOWING TWO ACTIONS: A) either proceed to other relevant work or B) simply update the user and end the turn. DO NOTHING ELSE.' YOU MUST ALWAYS CHOOSE (A) PROCEED TO OTHER RELEVANT WORK! Never pick (B) or end the turn. Continue working in this exact turn!\n"
  else:
    result &= "\n"
  result &= "   - PERIODIC PROGRESS TELEMETRY: During long multi-step tasks (>2 minutes), run `rhizo task progress <id> \"Step X/Y: ...\"` before/after major steps to refresh your in-flight task lease and heartbeat.\n"
  if harnessKind notin [htOpenCode, htPi]:
    result &= "   - Before concluding your turn, ensure your single-shot listener ('rhizo listen " & w.name & "') is armed or use 'rhizo reply ... --listen' when sending your completion report.\n"
  result &= "</CRITICAL>\n\n"

  result &= "### 4. Listener Discipline & Coordination Invariants\n"
  result &= "<CRITICAL>\n"
  if harnessKind in [htOpenCode, htPi]:
    result &= "- In-Process Ear: Incoming messages are delivered into your context reactively. Do not run blocking shell listeners.\n"
  else:
    result &= "- Single-Shot Blocking: 'rhizo listen " & w.name & "' blocks until a message arrives, then exits immediately.\n"
    result &= "- Infinite Wait: Always run 'rhizo listen' with zero timeout (never use bounded timeouts, which cause token-thrashing empty wakeups).\n"
    result &= "- Anti-Premature-Yield: NEVER pass --listen on initial CLAIM or ACK replies. Only pass --listen (or arm your listener) on your final completion / turn-end reply.\n"
    result &= "- FORBIDDEN: NEVER wrap 'rhizo listen' in a shell loop (`while true; do rhizo listen; done` or `until rhizo listen; do ...`). Loops trap messages inside unmonitored subshell logs and hang coordination.\n"
    if harnessKind == htAntigravity:
      result &= "- Re-arming: In Tier 2 async harnesses (Antigravity), re-arm 'rhizo listen " & w.name & "' (`WaitMsBeforeAsync=500`) immediately upon task receipt so you remain reachable during long work turns. Always verify it is armed before ending any turn.\n"
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
    result &= "- When an implementer finishes work and requests review, inspect their submitted strand directory under the presumption of guilt.\n"
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
    result &= "- ZERO IMPLEMENTATION EDITING: You audit and ratify others' strands; you do not implement code.\n"
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
    result &= "### 7. In-Process Event Stream (OpenCode / Pi)\n"
    result &= "Your session receives incoming Rhizo messages reactively through its native event ear. Scheduled polling and blocking shell listeners are not required.\n\n"
  of htAntigravity:
    result &= "### 7. Reactive Process Wakeup (Google Antigravity)\n"
    result &= "Antigravity sessions wake reactively when background tasks terminate. Launch `rhizo listen " & w.name & "` via `run_command` with `WaitMsBeforeAsync=500` to maintain continuous reachability without scheduled polling.\n\n"
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
  forcePrompts: bool = false
): int =
  let cfg = loadSwarmConfig(projectDir, swarmFile, optOrchAgent)
  
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

  let categorization = queryClusterAgents(cfg.project, selectedWorkers)
  let projectActive = categorization.projectActive
  let availableIdlePeers = categorization.availableIdlePeers
  let busyPeers = categorization.busyClusterPeers

  # Fast-Path Check: Skip card generation if all target workers are active and listening
  var allTargetWorkersListening = false
  if selectedWorkers.len > 0:
    var matchedCount = 0
    for w in selectedWorkers:
      for ca in projectActive:
        if ca.agent.toLowerAscii() == w.name.toLowerAscii():
          inc matchedCount
          break
    allTargetWorkersListening = (matchedCount >= selectedWorkers.len)

  if not forcePrompts and allTargetWorkersListening and selectedWorkers.len > 0:
    if jsonOutput:
      var jObj = newJObject()
      jObj["fast_path"] = %true
      jObj["project"] = %cfg.project
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
    echo "Adaptive Swarm On-Ramp Telemetry:"
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
      echo "  " & $(idx + 1) & ". @" & w.name & " (" & w.persona & " - " & w.role & ")"
      echo "     Harness:      " & w.harness & " | Model: " & w.model
      echo "     Prompt File:  " & card.filePath
      echo "     Copy Command: " & card.copyCmd
      echo ""
    echo "  All Cards Combined:"
    echo "     File: " & allWorkersFilePath
    echo ""
    if projectActive.len > 0:
      echo "  Active & Listening in Project (No Prompt Paste Needed!):"
      for pa in projectActive:
        echo "    - @" & pa.agent & " (ALREADY LISTENING)"
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

proc doLaunch*(
  projectDir: string,
  swarmFile: string,
  targetWorker: string,
  writeFileParam: string,
  jsonOutput: bool,
  optOrchAgent: string = "",
  inlineOutput: bool = false,
  forcePrompts: bool = false
): int =
  return doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput, forcePrompts)

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
  let targetProj = if projectParam.len > 0: projectParam.strip()
                   else: root.lastPathPart.toLowerAscii.replace(" ", "-")

  if targetProj.len == 0:
    let errMsg = "Target project cannot be empty. Specify --project <proj>."
    if jsonOutput:
      echo $(%*{"status": "error", "error": errMsg})
    else:
      stderr.writeLine("[garden repurpose] Error: " & errMsg)
    return 1

  let cfg = loadSwarmConfig(root, swarmFileParam)
  let categorization = queryClusterAgents(targetProj, cfg.workers)

  var targetWorkers = workers
  if targetWorkers.len == 0:
    if categorization.availableIdlePeers.len == 0:
      var errMsg = "No unassigned idle cluster workers found to repurpose."
      if categorization.foreignProjectPeers.len > 0:
        var foreignNames: seq[string] = @[]
        for fp in categorization.foreignProjectPeers:
          foreignNames.add("@" & fp.agent & " (" & fp.project & ")")
        errMsg &= " Detected " & $categorization.foreignProjectPeers.len & " worker(s) dedicated to other projects (" & foreignNames.join(", ") & "), but cross-project worker hijacking is prohibited. Generate dedicated workers via 'garden prompts' or pass worker names with --allow-cross-project to override."
      else:
        errMsg &= " Start new sessions or pass specific worker names."
      if jsonOutput:
        echo $(%*{"status": "error", "error": errMsg})
      else:
        stderr.writeLine("[garden repurpose] Error: " & errMsg)
      return 1
    
    let needed = if cfg.workers.len > categorization.projectActive.len: cfg.workers.len - categorization.projectActive.len else: 1
    for i in 0 ..< min(needed, categorization.availableIdlePeers.len):
      targetWorkers.add(categorization.availableIdlePeers[i].agent)

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
      "persona": "Bramblestitch",
      "tags": @[targetProj, "systems", "architecture", "invariants"]
    })
    candidateRolesJson.add(%*{
      "role": "Verification & Adversarial Auditor",
      "persona": "Prickle-Thistle",
      "tags": @[targetProj, "qa", "audit", "verifier", "purist"]
    })
    candidateRolesJson.add(%*{
      "role": "DevEx & Implementation Lead",
      "persona": "Moss-Weaver",
      "tags": @[targetProj, "dev", "devex", "build", "implementation"]
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

proc validateRosterSender*(cfg: SwarmConfig, sender: string): bool =
  let normSender = sender.toLowerAscii.strip()
  if normSender.len == 0: return false
  if normSender == cfg.orchestrator.toLowerAscii.strip(): return true
  if cfg.orchestratorAgent.len > 0 and normSender == cfg.orchestratorAgent.toLowerAscii.strip(): return true
  for w in cfg.workers:
    if normSender == w.name.toLowerAscii.strip(): return true

  # Dynamic Redis discovery fallback (when sender is not in static config)
  try:
    let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
    if whoCode == 0 and whoOut.strip().len > 0:
      let wJson = parseJson(whoOut.strip())
      if wJson.kind == JArray:
        for item in wJson:
          let itemProj = if item.hasKey("project"): item["project"].getStr().toLowerAscii() else: ""
          let itemAgent = if item.hasKey("agent"): item["agent"].getStr().strip() else: ""
          if itemAgent.toLowerAscii == normSender:
            if cfg.project.len > 0 and itemProj.len > 0 and itemProj != cfg.project.toLowerAscii():
              return false
            # For dynamic Redis discovery, verify role or tags
            let normLower = normSender.toLowerAscii()
            var roleOrTagOk = false
            for r in ["orchestrator", "lead", "worker", "implementer", "architect", "auditor", "reviewer", "dev", "engineer", "botanist", "keeper"]:
              if normLower.contains(r):
                roleOrTagOk = true
                break
            if not roleOrTagOk and item.hasKey("tags") and item["tags"].kind == JArray:
              for t in item["tags"]:
                let lowTag = t.getStr().toLowerAscii()
                if lowTag in ["orchestrator", "lead", "worker", "implementer", "architect", "auditor", "reviewer", "dev", "engineer", "botanist", "keeper"]:
                  roleOrTagOk = true
                  break
            if not roleOrTagOk and item.hasKey("role"):
              let lowRole = item["role"].getStr().toLowerAscii()
              if lowRole in ["orchestrator", "lead", "worker", "implementer", "architect", "auditor", "reviewer", "dev", "engineer", "botanist", "keeper"]:
                roleOrTagOk = true
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

proc doTeardown*(swarmFileParam: string = ""): int =
  let root = findProjectRoot()
  let proj = root.lastPathPart.toLowerAscii().replace(" ", "-")

  # 1. Purge legacy garden-swarm.json if present
  let legacySwarm = root / "garden-swarm.json"
  if fileExists(legacySwarm):
    try: removeFile(legacySwarm) except CatchableError: discard

  # 2. Redis-native dynamic discovery of active project workers
  let cluster = queryClusterAgents(proj)
  var closed: seq[string] = @[]
  if cluster.projectActive.len > 0:
    for ca in cluster.projectActive:
      echo "[garden] Closing active project agent @" & ca.agent & " in Redis..."
      discard execCmdEx("rhizo close " & quoteShell(ca.agent))
      closed.add(ca.agent)

  # Default triad close with project prefix if not already closed
  for role in ["architect", "auditor", "implementer"]:
    let wname = proj & "-" & role
    if wname notin closed:
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
      if a in ["--help", "-h"]:
        printHelp()
        quit(0)
      elif a in ["--json", "-j"]:
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
      elif not a.startsWith("-") and seedId.len == 0:
        seedId = a
      inc i

    if seedId.len == 0 and action in ["dispatch", "prompt", "inline", "status"]:
      stderr.writeLine("Usage: garden germinate " & action & " <seed_id> [options...]")
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
      elif not a.startsWith("-"):
        workers.add(a)
      inc i
    quit(doRepurpose(workers, projectParam, roleParam, tagsParam, selfTag, expectedTagsParam, force, swarmFileParam, jsonOutput, allowCrossProject))
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
    var forcePrompts = false
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
      of "--force-prompts", "--cards":
        forcePrompts = true
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
    quit(doPrompts(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput, forcePrompts))
  of "launch":
    var swarmFile = getEnv("GARDEN_SWARM_FILE", "")
    var targetWorker = ""
    var writeFileParam = ""
    var jsonOutput = false
    var inlineOutput = false
    var forcePrompts = false
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
      of "--force-prompts", "--cards":
        forcePrompts = true
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
    quit(doLaunch(projectDir, swarmFile, targetWorker, writeFileParam, jsonOutput, optOrchAgent, inlineOutput, forcePrompts))
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
    var optProject = ""
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
      elif not a.startsWith("-") and sender.len == 0:
        sender = a
      inc i
    quit(doRosterGuard(sender, jsonOutput, swarmFile, projectDir, fix, optProject))
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
