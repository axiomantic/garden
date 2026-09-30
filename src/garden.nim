# /Users/eek/Development/garden/src/garden.nim
# The Garden Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, parseopt]
import guide

const
  GardenVersion = "0.1.5"
  DefaultConfigFileName = "garden.toml"

proc printHelp() =
  echo """
Garden: Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies
Version: """ & GardenVersion & """

Usage:
  garden <subcommand> [arguments...] [options...]

Subcommands:
  init [dir]               Initialize Garden configuration and install guides
  launch [options]         Provision tmux worker swarm and launch terminal viewer
  status [options]         Unified cluster telemetry (tmux, Rhizo heartbeats, Vine strands)
  guide <action> [path]    Manage Garden Coordination Guide (install, check, uninstall)
  teardown [options]       Gracefully close swarm agents and terminate tmux session
  version, -v, --version   Print Garden version and exit
  help, -h, --help         Print this help message

Options for 'launch':
  --session-name <name>    Custom tmux session name (default: garden-<project>)
  --swarm-file <file>      Path to garden-swarm.json manifest
  --terminal-app <app>     Terminal viewer app: Ghostty | Terminal | iTerm | none
  --force                  Kill existing session if running

Options for 'status':
  --json                   Output telemetry as JSON
  --session-name <name>    Specific tmux session to inspect

Options for 'teardown':
  --session-name <name>    Specific tmux session to terminate
  --swarm-file <file>      Path to garden-swarm.json to close mapped agents
"""

proc findProjectRoot(startDir: string = getCurrentDir()): string =
  var dir = startDir
  while dir.len > 0:
    if fileExists(dir / "garden.toml") or 
       fileExists(dir / "garden-swarm.json") or 
       dirExists(dir / ".git"):
      return dir
    let parent = dir.parentDir()
    if parent == dir:
      break
    dir = parent
  return startDir

proc doInit(targetDir: string, force: bool): int =
  let root = if targetDir.len > 0: targetDir else: getCurrentDir()
  createDir(root)
  let projName = root.lastPathPart.toLowerAscii()
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

  echo "[garden] Initialization complete for " & root
  return 0

proc doLaunch(projectDir: string, sessionName: string, swarmFile: string, terminalApp: string, force: bool): int =
  let root = if projectDir.len > 0: projectDir else: findProjectRoot()
  
  # Locate launch script
  var scriptPath = root / "scripts" / "launch_tmux_swarm.sh"
  if not fileExists(scriptPath):
    # Try next to executable
    let exeDir = getAppDir()
    scriptPath = exeDir / "scripts" / "launch_tmux_swarm.sh"
    if not fileExists(scriptPath):
      scriptPath = exeDir.parentDir() / "scripts" / "launch_tmux_swarm.sh"

  if not fileExists(scriptPath):
    stderr.writeLine("[garden] Error: launch_tmux_swarm.sh not found.")
    return 1

  var cmd = quoteShell(scriptPath) & " --project-dir " & quoteShell(root)
  if sessionName.len > 0:
    cmd &= " --session-name " & quoteShell(sessionName)
  if swarmFile.len > 0:
    cmd &= " --swarm-file " & quoteShell(swarmFile)
  elif fileExists(root / "garden-swarm.json"):
    cmd &= " --swarm-file " & quoteShell(root / "garden-swarm.json")

  if terminalApp.len > 0:
    cmd &= " --terminal-app " & quoteShell(terminalApp)
  if force:
    cmd &= " --force"

  let exitCode = execCmd(cmd)
  return exitCode

proc doStatus(sessionNameParam: string, jsonOutput: bool): int =
  try:
    let root = findProjectRoot()
    let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")
    let sessionName = if sessionNameParam.len > 0: sessionNameParam else: "garden-" & projBase

    var statusObj = newJObject()
    statusObj["project"] = %root
    statusObj["session_name"] = %sessionName

    # 1. Query tmux
    var tmuxActive = false
    var tmuxWindows: seq[JsonNode] = @[]
    try:
      let (tmuxOut, tmuxCode) = execCmdEx("tmux has-session -t " & quoteShell(sessionName))
      tmuxActive = (tmuxCode == 0)
      if tmuxActive:
        let (wOut, _) = execCmdEx("tmux list-windows -t " & quoteShell(sessionName) & " -F '#{window_index}:#{window_name}:#{pane_current_command}'")
        for line in wOut.strip().splitLines():
          if line.len == 0: continue
          let parts = line.split(":", 2)
          if parts.len >= 2:
            var wObj = newJObject()
            wObj["index"] = %parts[0]
            wObj["name"] = %parts[1]
            wObj["command"] = %(if parts.len > 2: parts[2] else: "")
            tmuxWindows.add(wObj)
    except CatchableError:
      discard

    statusObj["tmux_active"] = %tmuxActive
    statusObj["windows"] = %tmuxWindows

    # 2. Query Rhizo heartbeats via 'rhizo who --json'
    try:
      let (rhizoOut, rhizoCode) = execCmdEx("rhizo who --json")
      if rhizoCode == 0 and rhizoOut.strip().startsWith("{"):
        statusObj["rhizo"] = parseJson(rhizoOut.strip())
      else:
        statusObj["rhizo"] = newJNull()
    except CatchableError:
      statusObj["rhizo"] = newJNull()

    # 3. Query Vine active strands via 'vine list'
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
      echo "  Garden Swarm Telemetry: " & sessionName
      echo "=========================================================="
      echo "Project: " & root
      echo "Tmux Active: " & (if tmuxActive: "YES (" & $tmuxWindows.len & " windows)" else: "NO")
      if tmuxWindows.len > 0:
        echo "Windows:"
        for w in tmuxWindows:
          echo "  [" & w["index"].getStr() & "] " & w["name"].getStr() & " (" & w["command"].getStr() & ")"
      
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

proc doTeardown(sessionNameParam: string, swarmFileParam: string): int =
  let root = findProjectRoot()
  let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let sessionName = if sessionNameParam.len > 0: sessionNameParam else: "garden-" & projBase

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

  # 2. Terminate tmux session
  var targetSession = sessionName
  var (hasOut, hasCode) = execCmdEx("tmux has-session -t " & quoteShell(targetSession))

  if hasCode == 0:
    echo "[garden] Terminating tmux session: " & targetSession
    let (kOut, kCode) = execCmdEx("tmux kill-session -t " & quoteShell(targetSession))
    if kCode == 0:
      echo "[garden] Swarm session terminated successfully."
    else:
      stderr.writeLine("[garden] Error terminating tmux session: " & kOut)
      return kCode
  else:
    echo "[garden] No active tmux session found for: " & sessionName

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
    var i = 1
    while i < params.len:
      case params[i]
      of "--force", "-f": force = true
      else:
        if targetDir.len == 0 and not params[i].startsWith("-"):
          targetDir = params[i]
      inc i
    quit(doInit(targetDir, force))
  of "launch":
    var sessionName = ""
    var swarmFile = ""
    var terminalApp = ""
    var force = false
    var i = 1
    while i < params.len:
      case params[i]
      of "--session-name", "-s":
        inc i; if i < params.len: sessionName = params[i]
      of "--swarm-file", "-f":
        inc i; if i < params.len: swarmFile = params[i]
      of "--terminal-app", "-t":
        inc i; if i < params.len: terminalApp = params[i]
      of "--force":
        force = true
      else: discard
      inc i
    quit(doLaunch("", sessionName, swarmFile, terminalApp, force))
  of "status":
    var jsonOutput = false
    var sessionName = ""
    var i = 1
    while i < params.len:
      case params[i]
      of "--json": jsonOutput = true
      of "--session-name", "-s":
        inc i; if i < params.len: sessionName = params[i]
      else: discard
      inc i
    quit(doStatus(sessionName, jsonOutput))
  of "teardown":
    var sessionName = ""
    var swarmFile = ""
    var i = 1
    while i < params.len:
      case params[i]
      of "--session-name", "-s":
        inc i; if i < params.len: sessionName = params[i]
      of "--swarm-file", "-f":
        inc i; if i < params.len: swarmFile = params[i]
      else: discard
      inc i
    quit(doTeardown(sessionName, swarmFile))
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
