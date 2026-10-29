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

  test "Guide v2.7 incorporates Autonomous Dispatch, ask_question discipline, and Project-Scoped Fleet Mandate":
    check GuideVersion == "v2.7"
    check CanonicalGuideContent.contains("<!-- BEGIN GARDEN GUIDE [v2.7] -->")
    check CanonicalGuideContent.contains("Pre-Authorized Directives & Autonomous Dispatch")
    check CanonicalGuideContent.contains("Mandatory `ask_question` Tool Discipline")
    check CanonicalGuideContent.contains("Project-Scoped Fleet Mandate & Anti-Hijacking Invariant")
    check CanonicalGuideContent.contains("Orchestrator Non-Implementation Invariant")
    check CanonicalGuideContent.contains("Dumping numbered multiple-choice lists (1, 2, 3) or raw option text directly into the chat stream is STRICTLY PROHIBITED")
    check CanonicalGuideContent.contains("Cross-project worker poaching is strictly prohibited")

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
    check j.hasKey("foreign_project_peers")
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
    var busyAgent = ""
    var busyAgentProj = ""
    try:
      let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let parsed = parseJson(whoOut.strip())
        let list = if parsed.kind == JArray: parsed elif parsed.hasKey("agents"): parsed["agents"] else: newJArray()
        for item in list:
          let state = item.getOrDefault("state").getStr("")
          if state.toUpperAscii().startsWith("BUSY"):
            busyAgent = item.getOrDefault("agent").getStr("")
            busyAgentProj = item.getOrDefault("project").getStr("")
            if busyAgent.len > 0: break
    except CatchableError: discard

    if busyAgent.len > 0:
      let targetProj = if busyAgentProj.len > 0: busyAgentProj else: "test-proj"
      # 1. Attempting without --force fails
      let (errOut, errCode) = execCmdEx(exePath & " repurpose " & busyAgent & " --project " & targetProj & " --json")
      check errCode != 0
      let errJson = parseJson(errOut.strip())
      check errJson["status"].getStr() == "error"
      check errJson["error"].getStr().contains("BUSY")

      # 2. Overriding with --force succeeds
      let (fOut, fCode) = execCmdEx(exePath & " repurpose " & busyAgent & " --project " & targetProj & " --force --json")
      check fCode == 0
      let fJson = parseJson(fOut.strip())
      check fJson["status"].getStr() == "ok"
      check fJson["repurposed_workers"][0]["agent"].getStr() == busyAgent

  test "Garden repurpose negative control: foreign project worker rejected without --allow-cross-project, overrides with flag":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    
    # Query cluster to find an actual foreign worker on a different project
    var foreignAgent = ""
    var originalProj = ""
    var originalTags: seq[string] = @[]
    try:
      let (whoOut, whoCode) = execCmdEx("rhizo who --all --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let parsed = parseJson(whoOut.strip())
        let list = if parsed.kind == JArray: parsed elif parsed.hasKey("agents"): parsed["agents"] else: newJArray()
        for item in list:
          let proj = item.getOrDefault("project").getStr("")
          let ag = item.getOrDefault("agent").getStr("")
          let st = item.getOrDefault("state").getStr("")
          if proj.len > 0 and proj != "test-anti-poach-proj" and not st.toUpperAscii().startsWith("BUSY"):
            foreignAgent = ag
            originalProj = proj
            if item.hasKey("tags") and item["tags"].kind == JArray:
              for t in item["tags"]: originalTags.add(t.getStr())
            break
    except CatchableError: discard

    if foreignAgent.len > 0:
      # 1. Attempting without --allow-cross-project fails with cross-project rejection error
      let (errOut, errCode) = execCmdEx(exePath & " repurpose " & foreignAgent & " --project test-anti-poach-proj --json")
      check errCode != 0
      let errJson = parseJson(errOut.strip())
      check errJson["status"].getStr() == "error"
      check errJson["error"].getStr().contains("Cross-project")

      # 2. Overriding with --allow-cross-project succeeds
      let (fOut, fCode) = execCmdEx(exePath & " repurpose " & foreignAgent & " --project test-anti-poach-proj --allow-cross-project --json")
      check fCode == 0
      let fJson = parseJson(fOut.strip())
      check fJson["status"].getStr() == "ok"
      check fJson["repurposed_workers"][0]["agent"].getStr() == foreignAgent

      # Restore worker back to original project and tags
      let restoreCmd = "rhizo reassign " & quoteShell(foreignAgent) & " --project " & quoteShell(originalProj) & " --tags " & quoteShell(originalTags.join(","))
      discard execCmdEx(restoreCmd)

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

    # 1. Fast-Path Activated (without --force-prompts) if active garden workers exist on cluster
    var hasActiveGardenWorker = false
    try:
      let (whoOut, whoCode) = execCmdEx("rhizo who --project garden --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let parsed = parseJson(whoOut.strip())
        let list = if parsed.kind == JArray: parsed elif parsed.hasKey("agents"): parsed["agents"] else: newJArray()
        hasActiveGardenWorker = list.len > 0
    except CatchableError:
      hasActiveGardenWorker = false

    if hasActiveGardenWorker:
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

suite "Role-Aware Bootstrap & Harness Wakeup Suite":

  test "resolveWorkerProfile correctly handles explicit profiles":
    var wImpl = WorkerSpec(name: "worker-1", role: "Custom", profile: "implementation")
    check resolveWorkerProfile(wImpl) == wpImplementation

    var wInvestig = WorkerSpec(name: "worker-2", role: "Custom", profile: "investigation")
    check resolveWorkerProfile(wInvestig) == wpInvestigation

    var wVerif = WorkerSpec(name: "worker-3", role: "Custom", profile: "verification")
    check resolveWorkerProfile(wVerif) == wpVerification

    var wAudit = WorkerSpec(name: "worker-4", role: "Custom", profile: "audit")
    check resolveWorkerProfile(wAudit) == wpAudit

  test "resolveWorkerProfile correctly handles custom role with no 'audit' in name":
    var wSentinel = WorkerSpec(name: "sentinel", role: "Security Arbiter", profile: "audit")
    check resolveWorkerProfile(wSentinel) == wpAudit

    var wReviewer = WorkerSpec(name: "reviewer", role: "Architecture Reviewer", profile: "investigation")
    check resolveWorkerProfile(wReviewer) == wpInvestigation

    var wBench = WorkerSpec(name: "benchmarker", role: "Performance Tester", profile: "verification")
    check resolveWorkerProfile(wBench) == wpVerification

  test "resolveWorkerProfile legacy fallback without explicit profile":
    var wAuditRole = WorkerSpec(name: "worker-a", role: "Verification & Adversarial Auditor")
    check resolveWorkerProfile(wAuditRole) == wpAudit

    var wVerifTags = WorkerSpec(name: "worker-b", role: "Tester", tags: @["qa", "test"])
    check resolveWorkerProfile(wVerifTags) == wpVerification

    var wInvestigRole = WorkerSpec(name: "worker-c", role: "Research & Analysis")
    check resolveWorkerProfile(wInvestigRole) == wpInvestigation

    var wDefault = WorkerSpec(name: "worker-d", role: "General Lead")
    check resolveWorkerProfile(wDefault) == wpImplementation

  test "generateWorkerPrompt for investigator does NOT contain strand creation, changelog, or submit":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "analyst",
      persona: "Briar",
      role: "Architecture Investigator",
      harness: "Claude Code CLI",
      tags: @["testproj", "investigation"],
      profile: "investigation",
      systemPrompt: "Investigate contracts."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("Profile / Capability**: Investigation & Review (Non-Modifying / Read-Only)")
    check prompt.contains("NON-IMPLEMENTING / READ-ONLY")
    check prompt.contains("You MUST NOT edit application source files")
    check not prompt.contains("vine new")
    check not prompt.contains("vine submit")
    check not prompt.contains("CHANGELOG.md")
    check not prompt.contains("vine changelog")

  test "generateWorkerPrompt for verifier allows running checks, forbids modifying source/tests":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "tester",
      persona: "Thistle",
      role: "Performance Verifier",
      harness: "Claude Code CLI",
      tags: @["testproj", "qa"],
      profile: "verification",
      systemPrompt: "Verify test suite."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("Profile / Capability**: Verification & Quality Assurance")
    check prompt.contains("VERIFICATION & QA ENGINEER")
    check prompt.contains("Execute test suites, linters, static analyzers")
    check prompt.contains("You must NEVER modify application source code")
    check not prompt.contains("vine submit")
    check not prompt.contains("vine new")
    check not prompt.contains("vine changelog")

  test "generateWorkerPrompt for auditor contains Key 3 Five-Pillar audit and prohibits self-audit":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "sentinel", # Notice: NO 'audit' in name!
      persona: "Rowan",
      role: "Integrity Gatekeeper", # Notice: NO 'audit' in role!
      harness: "Claude Code CLI",
      tags: @["testproj", "gate"],
      profile: "audit",
      systemPrompt: "Enforce Key 3."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("Profile / Capability**: Adversarial Audit (Key 3 Gate)")
    check prompt.contains("Key 3 Adversarial Auditor Protocol")
    check prompt.contains("vine audit reject")
    check prompt.contains("vine audit approve")
    check prompt.contains("SELF-AUDIT IS STRICTLY FORBIDDEN")
    check prompt.contains("ZERO IMPLEMENTATION EDITING")
    check not prompt.contains("vine submit")
    check not prompt.contains("vine new")

  test "generateWorkerPrompt for implementer contains strand, changelog, gate, submit":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "builder",
      persona: "Fern",
      role: "DevEx Lead",
      harness: "Claude Code CLI",
      tags: @["testproj", "dev"],
      profile: "implementation",
      systemPrompt: "Implement cleanly."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("Profile / Capability**: Implementation & Feature Engineering")
    check prompt.contains("vine new <task_id>")
    check prompt.contains("vine changelog")
    check prompt.contains("vine gate")
    check prompt.contains("vine submit")
    check prompt.contains("Two-Point Diff Mandate")
    check prompt.contains("YOU ARE NOT THE AUDITOR")

  test "generateWorkerPrompt for Codex uses RHIZO_WAKE, distinguishes payload from wake, and forbids scheduled polling":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "builder",
      persona: "Fern",
      role: "DevEx Lead",
      harness: "ChatGPT Desktop / Codex",
      tags: @["testproj", "dev"],
      profile: "implementation",
      systemPrompt: "Implement cleanly."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("Codex Native Wakeup Protocol (`RHIZO_WAKE`)")
    check prompt.contains("send_message_to_thread")
    check prompt.contains("Distinguish Payload Transport from Idle Wakeup")
    check prompt.contains("Scheduled Polling & Watchdogs PROHIBITED")
    check not prompt.contains("STEP 1: INSPECT COMPLETED BACKGROUND LISTENER")
    # Verify hook install is commented or optional, not unconditionally executed
    check prompt.contains("# rhizo hook install --codex")

  test "generateWorkerPrompt for OpenCode / Pi does not instruct worker to run blocking listener":
    let cfg = SwarmConfig(project: "testproj", targetRepo: "/tmp/testrepo", orchestrator: "orch")
    let w = WorkerSpec(
      name: "builder",
      persona: "Fern",
      role: "DevEx Lead",
      harness: "OpenCode",
      tags: @["testproj", "dev"],
      profile: "implementation",
      systemPrompt: "Implement cleanly."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    check prompt.contains("In-Process Ear Active")
    check prompt.contains("DO NOT launch a redundant blocking shell listener")
    check not prompt.contains("Arm single-shot listener for incoming directives:\nrhizo listen")

  test "SKILL.md is reconciled with skills/garden/SKILL.md":
    let rootSkill = readFile(getCurrentDir() / "SKILL.md")
    let pkgSkill = readFile(getCurrentDir() / "skills" / "garden" / "SKILL.md")
    check rootSkill == pkgSkill

  test "hasHelpFlag detects --help, -h, help and respects -- barrier":
    check hasHelpFlag(@["--help"])
    check hasHelpFlag(@["-h"])
    check hasHelpFlag(@["help"])
    check hasHelpFlag(@["some", "--help"])
    check not hasHelpFlag(@["some", "--"])
    check not hasHelpFlag(@["some", "--", "--help"])
    check not hasHelpFlag(@["some", "--other"])

  test "garden binary handles --help on subcommands without executing them":
    let binPath = getCurrentDir() / "bin" / "garden"
    let subcmds = @["init", "plant", "roadmap", "germinate", "repurpose", "prompts", "launch", "status", "guide", "update"]
    for s in subcmds:
      let (outp, code) = execCmdEx(binPath & " " & s & " --help")
      check code == 0
      check outp.contains("Usage: garden " & s)

    # Test help <subcmd> syntax
    let (outp2, code2) = execCmdEx(binPath & " help init")
    check code2 == 0
    check outp2.contains("Usage: garden init")

  test "parseTomlSwarmConfig extracts worker profile and capability correctly":
    let toml = """
[project]
name = "custom-toml-proj"

[orchestrator]
name = "lead"
agent = "lead-orch"

[[workers]]
name = "reviewer"
persona = "Sage"
role = "Code Reviewer"
profile = "investigation"
harness = "Claude Code CLI"
system_prompt = "Review code carefully."
opposing_priority = "Thoroughness"
tags = ["custom-toml-proj", "reviewer"]

[[workers]]
name = "tester"
persona = "Flint"
role = "Test Verifier"
capability = "verification"
tags = ["custom-toml-proj", "tester"]

[[workers]]
name = "auditor"
persona = "Adversary"
role = "Security Auditor"
profile = "audit"
"""
    let j = parseTomlSwarmConfig(toml)
    check j["project"].getStr() == "custom-toml-proj"
    check j["orchestrator"]["name"].getStr() == "lead"
    check j["workers"].len == 3

    check j["workers"][0]["name"].getStr() == "reviewer"
    check j["workers"][0]["profile"].getStr() == "investigation"
    check j["workers"][0]["role"].getStr() == "Code Reviewer"

    check j["workers"][1]["name"].getStr() == "tester"
    check j["workers"][1]["capability"].getStr() == "verification"

    check j["workers"][2]["name"].getStr() == "auditor"
    check j["workers"][2]["profile"].getStr() == "audit"

  test "loadSwarmConfig parses profile from custom swarm TOML file":
    let tmpDir = getTempDir() / "garden_toml_test_" & $getCurrentProcessId()
    createDir(tmpDir)
    defer: (try: removeDir(tmpDir) except CatchableError: discard)

    let tomlPath = tmpDir / "swarm.toml"
    let tomlContent = """
[project]
name = "toml-swarm-test"

[[workers]]
name = "investigator"
persona = "Sherlock"
role = "Read-Only Inspector"
profile = "investigation"
harness = "Claude Code CLI"

[[workers]]
name = "auditor"
persona = "Judge"
role = "Independent Auditor"
profile = "audit"
"""
    writeFile(tomlPath, tomlContent)

    let cfg = loadSwarmConfig(projectDir = tmpDir, swarmFilePath = tomlPath)
    check cfg.project == "toml-swarm-test"
    check cfg.workers.len == 2
    check cfg.workers[0].name.endsWith("investigator")
    check cfg.workers[0].profile == "investigation"
    check cfg.workers[1].name.endsWith("auditor")
    check cfg.workers[1].profile == "audit"

    # Verify generated prompt for investigator does NOT contain strand creation or commit
    let invPrompt = generateWorkerPrompt(cfg, cfg.workers[0])
    check invPrompt.contains("Profile / Capability**: Investigation & Review (Non-Modifying / Read-Only)")
    check not invPrompt.contains("vine new <task_id>")
    check not invPrompt.contains("vine changelog")





