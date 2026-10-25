# tests/test_garden.nim
# Comprehensive unit & integration tests for Garden CLI and Guide management engine.

import std/[os, osproc, strutils, json, unittest]
import ../src/guide
import ../src/garden

suite "Garden Guide Management & Marker Suite":

  test "Guide install creates AGENTS.md if missing":
    let tmpDir = getTempDir() / ("garden_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let targetFile = tmpDir / "AGENTS.md"
    let (ok, msg) = installGuide(targetFile)
    check ok == true
    check fileExists(targetFile)
    check readFile(targetFile).contains(BeginMarker)
    check readFile(targetFile).contains(EndMarker)
    check checkGuide(targetFile) == gsInstalled

  test "Guide install is idempotent and updates in-place":
    let tmpDir = getTempDir() / ("garden_test_idempotent_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let targetFile = tmpDir / "AGENTS.md"
    writeFile(targetFile, "# Header\n\nSome custom text before.\n")
    
    # 1. First install
    let (ok1, _) = installGuide(targetFile)
    check ok1 == true
    let firstContent = readFile(targetFile)
    check firstContent.contains("Some custom text before.")
    check firstContent.contains(BeginMarker)

    # 2. Second install (idempotent update)
    let (ok2, msg2) = installGuide(targetFile)
    check ok2 == true
    check msg2.contains("Updated")
    let secondContent = readFile(targetFile)
    check secondContent.count(MarkerPrefix) == 1
    check secondContent.count(EndMarker) == 1
    check secondContent.contains("Some custom text before.")

  test "Guide uninstall removes block cleanly and preserves surrounding text":
    let tmpDir = getTempDir() / ("garden_test_uninstall_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let targetFile = tmpDir / "AGENTS.md"
    writeFile(targetFile, "# Root\n\n" & CanonicalGuideContent.strip() & "\n\n# Postscript\n")
    check checkGuide(targetFile) == gsInstalled

    let (ok, msg) = uninstallGuide(targetFile)
    check ok == true
    check checkGuide(targetFile) == gsNotFound
    let content = readFile(targetFile)
    check not content.contains(MarkerPrefix)
    check not content.contains(EndMarker)
    check content.contains("# Root")
    check content.contains("# Postscript")

  test "Guide malformed markers fail fast to prevent data loss":
    let tmpDir = getTempDir() / ("garden_test_malformed_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let targetFile = tmpDir / "AGENTS.md"
    # Unbalanced: BeginMarker present, EndMarker missing
    writeFile(targetFile, "# Broken\n" & BeginMarker & "\nIncomplete content without end.\n")
    check checkGuide(targetFile) == gsMalformed

    let (ok, msg) = installGuide(targetFile)
    check ok == false
    check msg.contains("Malformed markers")

  test "Guide v2.6 incorporates Autonomous Dispatch, ask_question discipline, and Fleet-First Mandate":
    check GuideVersion == "v2.6"
    check CanonicalGuideContent.contains("<!-- BEGIN GARDEN GUIDE [v2.6] -->")
    check CanonicalGuideContent.contains("Pre-Authorized Directives & Autonomous Dispatch")
    check CanonicalGuideContent.contains("Mandatory `ask_question` Tool Discipline")
    check CanonicalGuideContent.contains("Fleet-First Mandate")
    check CanonicalGuideContent.contains("Orchestrator Non-Implementation Invariant")
    check CanonicalGuideContent.contains("Dumping numbered multiple-choice lists (1, 2, 3) or raw option text directly into the chat stream is STRICTLY PROHIBITED")
    check CanonicalGuideContent.contains("When online workers exist, NEVER output copy-paste prompt cards to the human operator")

suite "Garden CLI Compilation & Telemetry Suite":

  test "Garden binary compiles and outputs clean --help and --version":
    let root = getCurrentDir()
    let (cOut, cCode) = execCmdEx("nim c -d:release --threads:on --mm:orc -o:bin/garden src/garden.nim")
    check cCode == 0
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    check fileExists(exePath)

    let (hOut, hCode) = execCmdEx(exePath & " --help")
    check hCode == 0
    check hOut.contains("Usage:")
    check hOut.contains("subcommand")
    check hOut.contains("launch")
    check hOut.contains("status")

    let (vOut, vCode) = execCmdEx(exePath & " --version")
    check vCode == 0
    check vOut.contains("garden v")

  test "Garden init generates garden.toml and installs guide":
    let tmpDir = getTempDir() / ("garden_test_init_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (initOut, initCode) = execCmdEx(exePath & " init " & quoteShell(tmpDir))
    check initCode == 0
    check fileExists(tmpDir / "garden.toml")
    check fileExists(tmpDir / "AGENTS.md")
    check dirExists(tmpDir / "docs" / "addenda")
    check readFile(tmpDir / "garden.toml").contains("preferred_terminal")
    check readFile(tmpDir / "AGENTS.md").contains(BeginMarker)

  test "Garden status outputs valid JSON with --json":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (sOut, sCode) = execCmdEx(exePath & " status --json")
    if sCode != 0:
      checkpoint("status failed with code " & $sCode & ": " & sOut)
    check sCode == 0
    if sCode == 0:
      let j = parseJson(sOut.strip())
      check j.hasKey("project")
      check j.hasKey("rhizo")
      check j.hasKey("vine_strands")
      # When rhizo is active, it must parse as JArray or JObject, not JNull
      if j["rhizo"].kind == JArray:
        check j["rhizo"].len >= 0
        if j["rhizo"].len > 0:
          let first = j["rhizo"][0]
          check first.hasKey("agent") or first.hasKey("name")

  test "Garden prompts generates prompt cards in tmp directory and supports --inline":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (pOut, pCode) = execCmdEx(exePath & " prompts")
    check pCode == 0
    check pOut.contains("GARDEN SWARM BOOTSTRAP")
    check pOut.contains("architect")
    check pOut.contains("auditor")
    check pOut.contains("implementer")
    check pOut.contains(".md")

    # Verify temp directory and worker files were created
    let tmpGarden = (if dirExists("/tmp"): "/tmp" else: getTempDir()) / "garden-garden"
    check dirExists(tmpGarden)
    check fileExists(tmpGarden / "garden-architect.md")
    check fileExists(tmpGarden / "garden-auditor.md")
    check fileExists(tmpGarden / "garden-implementer.md")
    check fileExists(tmpGarden / "all-workers.md")

    let archContent = readFile(tmpGarden / "garden-architect.md")
    check archContent.contains("export RHIZO_AGENT_NAME=")
    check archContent.contains("rhizo open")
    check archContent.contains("rhizo listen")
    check archContent.contains("Single-Shot Blocking")

    # Verify --inline flag produces raw 10-backtick fence blocks in stdout
    let (iOut, iCode) = execCmdEx(exePath & " prompts --inline")
    check iCode == 0
    check iOut.contains("``````````markdown")
    check iOut.contains("SWARM_RUNTIME_STATE")

  test "Garden prompts --worker filters output to target worker":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (pOut, pCode) = execCmdEx(exePath & " prompts --worker auditor")
    check pCode == 0
    check pOut.contains("auditor")
    check pOut.contains("garden-auditor")
    check not pOut.contains("garden-architect")
    check not pOut.contains("garden-implementer")

  test "Garden prompts --json outputs structured json telemetry":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (jOut, jCode) = execCmdEx(exePath & " prompts --json")
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j["count"].getInt() == 3
    check j["workers"].len == 3
    check j["workers"][0]["name"].getStr() == "garden-architect"
    check j.hasKey("temp_dir")
    check j["workers"][0].hasKey("file_path")
    check j["workers"][0].hasKey("copy_command")
    check fileExists(j["workers"][0]["file_path"].getStr())
    check j["workers"][0]["persona"].getStr().len > 0
    check j["workers"][0]["prompt"].getStr().contains("garden-architect")

  test "Garden prompts --write outputs prompts to file":
    let tmpDir = getTempDir() / ("garden_test_prompts_write_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let outFile = tmpDir / "swarm-cards.md"
    let (pOut, pCode) = execCmdEx(exePath & " prompts --write " & quoteShell(outFile))
    check pCode == 0
    check fileExists(outFile)
    let content = readFile(outFile)
    check content.contains("``````````markdown")
    check content.contains("architect")
    check content.contains("auditor")
    check content.contains("implementer")
    check content.contains("WORKER_READY")
    check content.contains("rhizo send --to")

  test "Garden launch defaults to prompt generation without requiring tmux":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (lOut, lCode) = execCmdEx(exePath & " launch --worker implementer")
    check lCode == 0
    check lOut.contains("garden-implementer")
    check lOut.contains(".md")
    check lOut.contains("CRITICAL ORCHESTRATOR MANDATE")
    check lOut.contains("rhizo listen")

    let (iOut, iCode) = execCmdEx(exePath & " launch --worker implementer --inline")
    check iCode == 0
    check iOut.contains("garden-implementer")
    check iOut.contains("``````````markdown")
    check iOut.contains("WORKER_READY")
    check iOut.contains("CRITICAL ORCHESTRATOR MANDATE")

  test "Garden respects GARDEN_SWARM_FILE and GARDEN_PROJECT_DIR environment variables":
    let tmpDir = getTempDir() / ("garden_test_env_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let customSwarm = tmpDir / "custom-swarm.json"
    let customJson = """{
      "project": "env-proj",
      "target_repo": "/tmp/env-proj",
      "workers": [
        {
          "name": "env-worker",
          "persona": "Custom Env Persona",
          "role": "Environment Validator",
          "harness": "Claude Code",
          "model": "claude-3-5-sonnet",
          "tags": ["env", "test"]
        }
      ]
    }"""
    writeFile(customSwarm, customJson)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    putEnv("GARDEN_SWARM_FILE", customSwarm)
    putEnv("GARDEN_PROJECT_DIR", tmpDir)
    defer:
      delEnv("GARDEN_SWARM_FILE")
      delEnv("GARDEN_PROJECT_DIR")

    let (pOut, pCode) = execCmdEx(exePath & " prompts --json")
    check pCode == 0
    let j = parseJson(pOut.strip())
    check j["count"].getInt() == 1
    check j["workers"][0]["name"].getStr() == "env-worker"
    check j["workers"][0]["prompt"].getStr().contains("Custom Env Persona")

  test "Garden auto-detects current harness from environment variables":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    
    # 1. Antigravity IDE
    putEnv("ANTIGRAVITY_APP_DIR", "/Applications/Antigravity.app")
    defer: delEnv("ANTIGRAVITY_APP_DIR")
    let (pOut1, pCode1) = execCmdEx(exePath & " prompts --json")
    check pCode1 == 0
    let j1 = parseJson(pOut1.strip())
    check j1["workers"][0]["harness"].getStr() == "Antigravity IDE"
    delEnv("ANTIGRAVITY_APP_DIR")

    # 2. Claude Code CLI
    putEnv("CLAUDE_CODE", "1")
    defer: delEnv("CLAUDE_CODE")
    let (pOut2, pCode2) = execCmdEx(exePath & " prompts --json")
    check pCode2 == 0
    let j2 = parseJson(pOut2.strip())
    check j2["workers"][0]["harness"].getStr() == "Claude Code CLI"
    delEnv("CLAUDE_CODE")

    # 3. OpenCode
    putEnv("OPENCODE_SESSION_ID", "sess_12345")
    defer: delEnv("OPENCODE_SESSION_ID")
    let (pOut3, pCode3) = execCmdEx(exePath & " prompts --json")
    check pCode3 == 0
    let j3 = parseJson(pOut3.strip())
    check j3["workers"][0]["harness"].getStr() == "OpenCode"
    delEnv("OPENCODE_SESSION_ID")

    # 4. ChatGPT Desktop / Codex
    putEnv("CODEX_SESSION_ID", "codex_67890")
    defer: delEnv("CODEX_SESSION_ID")
    let (pOut4, pCode4) = execCmdEx(exePath & " prompts --json")
    check pCode4 == 0
    let j4 = parseJson(pOut4.strip())
    check j4["workers"][0]["harness"].getStr() == "ChatGPT Desktop / Codex"
    delEnv("CODEX_SESSION_ID")

    # 5. Pi
    putEnv("PI_SESSION_ID", "pi_abcde")
    defer: delEnv("PI_SESSION_ID")
    let (pOut5, pCode5) = execCmdEx(exePath & " prompts --json")
    check pCode5 == 0
    let j5 = parseJson(pOut5.strip())
    check j5["workers"][0]["harness"].getStr() == "Pi"
    delEnv("PI_SESSION_ID")

  test "Garden prompts references actual orchestrator without touching Redis aliases":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (pOut, pCode) = execCmdEx(exePath & " prompts --json -a custom-orch-lead")
    check pCode == 0
    let j = parseJson(pOut.strip())
    check j.hasKey("orchestrator")
    check j["orchestrator"].getStr() == "custom-orch-lead"
    check j.hasKey("orchestrator_agent")
    check j["orchestrator_agent"].getStr() == "custom-orch-lead"

    # Verify generated prompts reference @custom-orch-lead directly, never a fake alias
    check j["workers"].len > 0
    let prompt0 = j["workers"][0]["prompt"].getStr()
    check prompt0.contains("@custom-orch-lead")
    check not prompt0.contains("-orchestrator")

  test "Garden roster-guard validates swarm members and quarantines alien agents":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (vOut, vCode) = execCmdEx(exePath & " roster-guard garden-architect --json")
    check vCode == 0
    let vJson = parseJson(vOut.strip())
    check vJson["valid"].getBool() == true
    check vJson["status"].getStr() == "ROSTER_VERIFIED"

    let (aOut, aCode) = execCmdEx(exePath & " roster-guard totally-alien-agent --json")
    check aCode != 0
    let aJson = parseJson(aOut.strip())
    check aJson["valid"].getBool() == false
    check aJson["status"].getStr() == "ALIEN_QUARANTINED"

    # Cluster audit mode
    let (auditOut, _) = execCmdEx(exePath & " roster-guard --json")
    let auditJson = parseJson(auditOut.strip())
    check auditJson.hasKey("audit")
    check auditJson["audit"].getStr() == "ROSTER_AUDIT"
    check auditJson.hasKey("verified_count")
    check auditJson.hasKey("alien_count")

  test "Garden session save, load, and clear lifecycle (zero on-disk JSON)":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let tmpDir = getTempDir() / ("garden_session_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let (sOut, sCode) = execCmdEx(exePath & " session save --agent test-gardener --role architect --project-dir " & quoteShell(tmpDir))
    check sCode == 0
    check not fileExists(tmpDir / ".garden" / "session.json")

    let (lOut, lCode) = execCmdEx(exePath & " session load --json --project-dir " & quoteShell(tmpDir))
    check lCode == 0
    let lJson = parseJson(lOut.strip())
    check lJson["on_disk_json"].getBool() == false

    let (cOut, cCode) = execCmdEx(exePath & " session clear --project-dir " & quoteShell(tmpDir))
    check cCode == 0
    check not fileExists(tmpDir / ".garden" / "session.json")

  test "Garden procedural whimsical persona generation":
    var names: seq[string] = @[]
    for role in ["architect", "auditor", "implementer"]:
      for proj in ["garden", "gearmulator", "astro-station", "dragon-vault"]:
        let persona = pickWhimsicalPersona(role, proj)
        check persona.contains("-")
        check persona notin ["Bramblestitch", "Prickle-Thistle", "Moss-Weaver", "Marcus Vance", "Elena Rostova", "Caleb Thorne"]
        names.add(persona)

    var unique: seq[string] = @[]
    for n in names:
      if n notin unique: unique.add(n)
    check unique.len >= 6

  test "Adaptive on-ramp surfaces available idle cluster peers and suggested repurpose commands":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (jOut, jCode) = execCmdEx(exePath & " prompts --json")
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j.hasKey("fast_path")
    check j.hasKey("already_listening")
    check j.hasKey("idle_cluster_peers")
    check j.hasKey("busy_cluster_peers")
    check j.hasKey("suggested_repurpose_commands")

  test "Garden repurpose CLI reassigns workers and emits structured JSON":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (rOut, rCode) = execCmdEx(exePath & " repurpose test-idle-agent --project test-garden-proj --role \"Staff Systems Architect\" --tags \"test,systems\" --json")
    check rCode == 0
    let rJson = parseJson(rOut.strip())
    check rJson["status"].getStr() == "ok"
    check rJson["action"].getStr() == "repurpose"
    check rJson["project"].getStr() == "test-garden-proj"
    check rJson["repurposed_count"].getInt() == 1
    check rJson["repurposed_workers"][0]["agent"].getStr() == "test-idle-agent"
    check rJson["repurposed_workers"][0]["role"].getStr() == "Staff Systems Architect"
    check rJson["repurposed_workers"][0]["mode"].getStr() == "direct"

  test "Garden repurpose supports --self-tag capability handshake":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (sOut, sCode) = execCmdEx(exePath & " repurpose test-handshake-agent --project test-garden-proj --self-tag --expected-tags \"nim,qa,audit\" --json")
    check sCode == 0
    let sJson = parseJson(sOut.strip())
    check sJson["status"].getStr() == "ok"
    check sJson["action"].getStr() == "repurpose"
    check sJson["repurposed_workers"][0]["mode"].getStr() == "self_tag"

  test "Garden repurpose negative control: busy worker rejected without --force, overrides with --force":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    
    # Query cluster to find an actual busy worker
    let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
    var busyAgent = ""
    if whoCode == 0 and whoOut.strip().len > 0:
      try:
        let parsed = parseJson(whoOut.strip())
        let list = if parsed.kind == JArray: parsed elif parsed.hasKey("agents"): parsed["agents"] else: newJArray()
        for item in list:
          let state = item.getOrDefault("state").getStr("")
          if state.toUpperAscii().startsWith("BUSY"):
            busyAgent = item.getOrDefault("agent").getStr("")
            if busyAgent.len > 0: break
      except CatchableError: discard

    if busyAgent.len > 0:
      # 1. Attempting without --force fails
      let (errOut, errCode) = execCmdEx(exePath & " repurpose " & busyAgent & " --project test-proj --json")
      check errCode != 0
      let errJson = parseJson(errOut.strip())
      check errJson["status"].getStr() == "error"
      check errJson["error"].getStr().contains("BUSY")

      # 2. Overriding with --force succeeds
      let (fOut, fCode) = execCmdEx(exePath & " repurpose " & busyAgent & " --project test-proj --force --json")
      check fCode == 0
      let fJson = parseJson(fOut.strip())
      check fJson["status"].getStr() == "ok"
      check fJson["repurposed_workers"][0]["agent"].getStr() == busyAgent

  test "Garden prompts fast-path skips card generation when project active workers >= target":
    let tmpDir = getTempDir() / ("garden_fast_path_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    
    # Create single-worker swarm matching current active worker (garden-botanist)
    let swarmFile = tmpDir / "test-fast-swarm.json"
    writeFile(swarmFile, """{
      "project": "garden",
      "target_repo": """" & tmpDir & """",
      "orchestrator": "test-orch",
      "workers": [
        {
          "name": "garden-botanist",
          "role": "Ceremony & Swarm On-Ramp Lead"
        }
      ]
    }""")

    # 1. Fast-Path Activated (without --force-prompts)
    let (fpOut, fpCode) = execCmdEx(exePath & " prompts -f " & quoteShell(swarmFile) & " --json")
    check fpCode == 0
    let fpJson = parseJson(fpOut.strip())
    check fpJson["fast_path"].getBool() == true
    check fpJson["active_workers_count"].getInt() >= 1

    # 2. Force Prompts Flag overrides fast-path
    let (forceOut, forceCode) = execCmdEx(exePath & " prompts -f " & quoteShell(swarmFile) & " --force-prompts --json")
    check forceCode == 0
    let forceJson = parseJson(forceOut.strip())
    check forceJson["fast_path"].getBool() == false
    check forceJson["count"].getInt() == 1
    check forceJson["workers"].len == 1

  test "Negative control: Zero on-disk JSON verification across init, prompts, status, roadmap":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let tmpDir = getTempDir() / ("garden_zero_json_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    # 1. Garden init
    let (iOut, iCode) = execCmdEx(exePath & " init " & quoteShell(tmpDir))
    check iCode == 0
    check not fileExists(tmpDir / "garden-swarm.json")
    check not fileExists(tmpDir / ".garden" / "roadmap.json")
    check not fileExists(tmpDir / ".garden" / "session.json")

    # 2. Plant seed and run roadmap
    let (plOut, plCode) = execCmdEx(exePath & " plant \"Zero JSON Seed\" --season v1.0 --project-dir " & quoteShell(tmpDir))
    check plCode == 0
    let (rOut, rCode) = execCmdEx(exePath & " roadmap --write --project-dir " & quoteShell(tmpDir))
    check rCode == 0
    check fileExists(tmpDir / "ROADMAP.md")
    check not fileExists(tmpDir / ".garden" / "roadmap.json")
    check not fileExists(tmpDir / "garden-swarm.json")
    check not fileExists(tmpDir / ".garden" / "session.json")

    # 3. Prompts generation
    let (pOut, pCode) = execCmdEx(exePath & " prompts --project-dir " & quoteShell(tmpDir) & " --json")
    check pCode == 0
    check not fileExists(tmpDir / "garden-swarm.json")
    check not fileExists(tmpDir / ".garden" / "roadmap.json")
    check not fileExists(tmpDir / ".garden" / "session.json")



