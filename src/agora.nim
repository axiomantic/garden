# /Users/eek/Development/agora/src/agora.nim
# The Agora Multi-Agent Swarm Orchestration Engine CLI.

import std/[os, osproc, strutils, json, parseopt]
import guide

const
  AgoraVersion = "0.1.0"
  DefaultConfigFileName = "agora.toml"

proc printHelp() =
  echo """
Agora: Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies
Version: """ & AgoraVersion & """

Usage:
  agora <subcommand> [arguments...] [options...]

Subcommands:
  init [dir]               Initialize Agora configuration and install guides
  launch [options]         Provision tmux worker swarm and launch terminal viewer
  status [options]         Unified cluster telemetry (tmux, Locu heartbeats, Braid strands)
  guide <action> [path]    Manage Agora Coordination Guide (install, check, uninstall)
  teardown [options]       Gracefully close swarm agents and terminate tmux session
  version, -v, --version   Print Agora version and exit
  help, -h, --help         Print this help message

Options for 'launch':
  --session-name <name>    Custom tmux session name (default: agora-<project>)
  --swarm-file <file>      Path to agora-swarm.json manifest
  --terminal-app <app>     Terminal viewer app: Ghostty | Terminal | iTerm | none
  --force                  Kill existing session if running

Options for 'status':
  --json                   Output telemetry as JSON
  --session-name <name>    Specific tmux session to inspect

Options for 'teardown':
  --session-name <name>    Specific tmux session to terminate
  --swarm-file <file>      Path to agora-swarm.json to close mapped agents
"""

proc findProjectRoot(startDir: string = getCurrentDir()): string =
  var dir = startDir
  while dir.len > 0:
    if fileExists(dir / "agora.toml") or fileExists(dir / "agora-swarm.json") or dirExists(dir / ".git"):
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
    echo "[agora] Config file already exists: " & configFile & " (use --force to overwrite)"
  else:
    let configContent = """[project]
name = """" & projName & """"
preferred_terminal = "auto" # Ghostty, Terminal, iTerm, none

[swarm]
session_prefix = "agora"
default_triad = ["architect", "auditor", "implementer"]
"""
    writeFile(configFile, configContent)
    echo "[agora] Created " & configFile

  # Create directories
  createDir(root / "docs" / "addenda")
  echo "[agora] Verified docs/addenda/ directory"

  # Install Agora Guide into AGENTS.md
  let agentsPath = root / "AGENTS.md"
  let (ok, msg) = installGuide(agentsPath)
  if ok:
    echo "[agora] " & msg
  else:
    stderr.writeLine("[agora] " & msg)

  echo "[agora] Initialization complete for " & root
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
    stderr.writeLine("[agora] Error: launch_tmux_swarm.sh not found.")
    return 1

  var cmd = quoteShell(scriptPath) & " --project-dir " & quoteShell(root)
  if sessionName.len > 0:
    cmd &= " --session-name " & quoteShell(sessionName)
  if swarmFile.len > 0:
    cmd &= " --swarm-file " & quoteShell(swarmFile)
  elif fileExists(root / "agora-swarm.json"):
    cmd &= " --swarm-file " & quoteShell(root / "agora-swarm.json")
  if terminalApp.len > 0:
    cmd &= " --terminal-app " & quoteShell(terminalApp)
  if force:
    cmd &= " --force"

  let exitCode = execCmd(cmd)
  return exitCode

proc doStatus(sessionNameParam: string, jsonOutput: bool): int =
  let root = findProjectRoot()
  let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let sessionName = if sessionNameParam.len > 0: sessionNameParam else: "agora-" & projBase

  var statusObj = newJObject()
  statusObj["project"] = %root
  statusObj["session_name"] = %sessionName

  # 1. Query tmux
  let (tmuxOut, tmuxCode) = execCmdEx("tmux has-session -t " & quoteShell(sessionName))
  let tmuxActive = (tmuxCode == 0)
  statusObj["tmux_active"] = %tmuxActive

  var tmuxWindows: seq[JsonNode] = @[]
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
  statusObj["windows"] = %tmuxWindows

  # 2. Query Locu heartbeats via 'locu who --json'
  let (locuOut, locuCode) = execCmdEx("locu who --json")
  if locuCode == 0 and locuOut.strip().startsWith("{"):
    try:
      let locuJson = parseJson(locuOut.strip())
      statusObj["locu"] = locuJson
    except CatchableError:
      statusObj["locu"] = newJNull()
  else:
    statusObj["locu"] = newJNull()

  # 3. Query Braid active strands via 'braid list'
  let (braidOut, braidCode) = execCmdEx("braid list")
  if braidCode == 0 and braidOut.strip().startsWith("{"):
    try:
      let braidJson = parseJson(braidOut.strip())
      statusObj["braid_strands"] = braidJson
    except CatchableError:
      statusObj["braid_strands"] = newJNull()
  else:
    statusObj["braid_strands"] = newJNull()

  if jsonOutput:
    echo pretty(statusObj)
  else:
    echo "=========================================================="
    echo "  Agora Swarm Telemetry: " & sessionName
    echo "=========================================================="
    echo "Project: " & root
    echo "Tmux Active: " & (if tmuxActive: "YES (" & $tmuxWindows.len & " windows)" else: "NO")
    if tmuxWindows.len > 0:
      echo "Windows:"
      for w in tmuxWindows:
        echo "  [" & w["index"].getStr() & "] " & w["name"].getStr() & " (" & w["command"].getStr() & ")"
    
    if not statusObj["locu"].isNil and statusObj["locu"].kind == JObject and statusObj["locu"].hasKey("agents"):
      let agents = statusObj["locu"]["agents"]
      echo "\nLocu Agents Online (" & $agents.len & "):"
      for a in agents:
        let aname = if a.hasKey("name"): a["name"].getStr() else: "unknown"
        let astate = if a.hasKey("state"): a["state"].getStr() else: "active"
        let atags = if a.hasKey("tags"): a["tags"].getStr() else: ""
        echo "  @" & aname & " [" & astate & "] tags: " & atags

    if not statusObj["braid_strands"].isNil and statusObj["braid_strands"].kind == JObject and statusObj["braid_strands"].hasKey("strands"):
      let strands = statusObj["braid_strands"]["strands"]
      echo "\nActive Braid Strands (" & $strands.len & "):"
      for s in strands:
        let tid = if s.hasKey("task_id"): s["task_id"].getStr() else: ""
        let branch = if s.hasKey("branch"): s["branch"].getStr() else: ""
        echo "  Strand: " & tid & " -> " & branch
    echo "=========================================================="

  return 0

proc doTeardown(sessionNameParam: string, swarmFileParam: string): int =
  let root = findProjectRoot()
  let projBase = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let sessionName = if sessionNameParam.len > 0: sessionNameParam else: "agora-" & projBase

  # 1. Gracefully close registered agents in Redis
  var swarmFile = swarmFileParam
  if swarmFile.len == 0 and fileExists(root / "agora-swarm.json"):
    swarmFile = root / "agora-swarm.json"

  if swarmFile.len > 0 and fileExists(swarmFile):
    try:
      let sJson = parseJson(readFile(swarmFile))
      if sJson.hasKey("workers"):
        for w in sJson["workers"]:
          if w.hasKey("name"):
            let wname = w["name"].getStr()
            echo "[agora] Closing agent @" & wname & " in Redis..."
            discard execCmdEx("locu close " & quoteShell(wname))
    except CatchableError: discard

  # 2. Terminate tmux session
  let (hasOut, hasCode) = execCmdEx("tmux has-session -t " & quoteShell(sessionName))
  if hasCode == 0:
    echo "[agora] Terminating tmux session: " & sessionName
    let (kOut, kCode) = execCmdEx("tmux kill-session -t " & quoteShell(sessionName))
    if kCode == 0:
      echo "[agora] Swarm session terminated successfully."
    else:
      stderr.writeLine("[agora] Error terminating tmux session: " & kOut)
      return kCode
  else:
    echo "[agora] No active tmux session found for: " & sessionName

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
    echo "agora v" & AgoraVersion
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
      stderr.writeLine("Usage: agora guide <install|check|uninstall> [path]")
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
      of gsInstalled: echo "[INSTALLED] Agora Guide is installed in: " & target
      of gsNotFound: echo "[NOT FOUND] Agora Guide not found in: " & target
      of gsMalformed: (stderr.writeLine("[MALFORMED] Unbalanced markers in: " & target); quit(1))
      of gsFileMissing: echo "[MISSING] Target file does not exist: " & target
    else:
      stderr.writeLine("Unknown guide action: " & action)
      quit(1)
  else:
    stderr.writeLine("Unknown subcommand: '" & subcmd & "'. Run 'agora --help' for usage.")
    quit(1)

when isMainModule:
  main()
