# tests/test_garden.nim
# Comprehensive unit & integration tests for Garden CLI and Guide management engine.

import std/[os, osproc, strutils, json, unittest]
import ../src/guide
import ../src/seed
import ../src/garden
import ../src/update
import ./test_helpers

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
    check CanonicalGuideContent.contains("* **Capability-Aware Harness Execution & Worker Modes**:")
    check CanonicalGuideContent.contains("Drillable Persistent Subagents (`subagents`")
    check CanonicalGuideContent.contains("Automated `tmux` Pane Factory (`tmux`")
    check not CanonicalGuideContent.contains("Sovereign Sessions & Subagent Prohibition")
    check readFile(getCurrentDir() / "AGENTS.md").replace("\r\n", "\n").contains(CanonicalGuideContent.strip().replace("\r\n", "\n"))

suite "Garden CLI Compilation & Telemetry Suite":

  test "Garden binary compiles and outputs clean --help and --version":
    let (hOut, hCode) = runGardenInProcess(@["--help"])
    check hCode == 0
    check hOut.contains("Usage:")
    check hOut.contains("subcommand")
    check hOut.contains("launch")
    check hOut.contains("status")

    let (vOut, vCode) = runGardenInProcess(@["--version"])
    check vCode == 0
    check vOut.contains("garden v")
    check vOut.contains("0.2.31")

  test "Garden init generates garden.toml and installs guide":
    let tmpDir = getTempDir() / ("garden_test_init_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let (_, initCode) = captureRet(proc (): int = doInit(tmpDir, false))
    check initCode == 0
    check fileExists(tmpDir / "garden.toml")
    check fileExists(tmpDir / "AGENTS.md")
    check dirExists(tmpDir / "docs" / "addenda")
    check readFile(tmpDir / "garden.toml").contains("preferred_terminal")
    check readFile(tmpDir / "AGENTS.md").contains(BeginMarker)

  test "Garden status outputs valid JSON with --json":
    let (sOut, sCode) = captureRet(proc (): int = doStatus(true))
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
    let (pOut, pCode) = captureRet(proc (): int = doPrompts("", "", "", "", false))
    check pCode == 0
    check pOut.contains("GARDEN SWARM BOOTSTRAP")
    check pOut.toLowerAscii.contains("architect")
    check pOut.toLowerAscii.contains("auditor")
    check pOut.toLowerAscii.contains("implement")
    check pOut.contains(".md")

    # Verify temp directory and worker files were created with both unique ID and role-prefixed names
    let tmpGarden = (if dirExists("/tmp"): "/tmp" else: getTempDir()) / "garden-garden"
    check dirExists(tmpGarden)
    check fileExists(tmpGarden / "all-workers.md")

    let (jOut, _) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    let j = parseJson(jOut.strip())
    check j["workers"].len == 3
    for w in j["workers"]:
      let name = w["name"].getStr()
      let slug = w["role_slug"].getStr()
      check fileExists(tmpGarden / (name & ".md"))
      check fileExists(tmpGarden / (slug & "-" & name & ".md"))
      let content = readFile(tmpGarden / (name & ".md"))
      check content.contains("Unique Listener ID (agent_id)")
      check content.contains("Triad Role")
      check content.contains("export RHIZO_AGENT_ID=")
      check content.contains("export RHIZO_AGENT_NAME=")
      check content.contains("rhizo open")
      check content.contains("Continuous Ambient Ear")
      check content.contains("agentapi send-message")

    # Verify --inline flag produces raw 10-backtick fence blocks in stdout
    let (iOut, iCode) = captureRet(proc (): int = doPrompts("", "", "", "", false, inlineOutput = true))
    check iCode == 0
    check iOut.contains("``````````markdown")
    check iOut.contains("SWARM_RUNTIME_STATE")

  test "Garden prompts --worker and --role filter output to target worker":
    let (pOut, pCode) = captureRet(proc (): int = doPrompts("", "", "auditor", "", false))
    check pCode == 0
    check pOut.contains("auditor")
    check pOut.toLowerAscii.contains("auditor")
    check pOut.contains("Verification & Adversarial Auditor")
    check not pOut.contains("Staff Systems Architect")
    check not pOut.contains("DevEx & Implementation Lead")

    let (rOut, rCode) = captureRet(proc (): int = doPrompts("", "", "architect", "", false))
    check rCode == 0
    check rOut.contains("architect")
    check rOut.toLowerAscii.contains("architect")
    check rOut.contains("Staff Systems Architect")
    check not rOut.contains("DevEx & Implementation Lead")

  test "Garden prompts --json outputs structured json telemetry with decoupled roles and unique UIDs":
    let (jOut, jCode) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j["count"].getInt() == 3
    check j["workers"].len == 3
    check j["workers"][0]["role_slug"].getStr() == "architect"
    check j["workers"][0]["name"].getStr().startsWith("garden-")
    check j["workers"][0]["name"].getStr() != "garden-architect"
    check j.hasKey("temp_dir")
    check j["workers"][0].hasKey("file_path")
    check not j["workers"][0].hasKey("copy_command")
    check fileExists(j["workers"][0]["file_path"].getStr())
    check j["workers"][0].hasKey("role_file_path")
    check fileExists(j["workers"][0]["role_file_path"].getStr())
    check j["workers"][0]["persona"].getStr().len > 0
    check j["workers"][0]["prompt"].getStr().contains(j["workers"][0]["name"].getStr())
    check j["workers"][0]["prompt"].getStr().contains("Unique Listener ID (agent_id)")

  test "Garden prompts --write outputs prompts to file":
    let tmpDir = getTempDir() / ("garden_test_prompts_write_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let outFile = tmpDir / "swarm-cards.md"
    let (_, pCode) = captureRet(proc (): int = doPrompts("", "", "", outFile, false))
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
    let (lOut, lCode) = captureRet(proc (): int = doLaunch("", "", "implementer", "", false))
    check lCode == 0
    check lOut.contains("DevEx & Implementation Lead")
    check lOut.contains(".md")
    check lOut.contains("CRITICAL ORCHESTRATOR MANDATE")
    check lOut.contains("rhizo listen")

    let (iOut, iCode) = captureRet(proc (): int = doLaunch("", "", "implementer", "", false, inlineOutput = true))
    check iCode == 0
    check iOut.contains("DevEx & Implementation Lead")
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

    putEnv("GARDEN_SWARM_FILE", customSwarm)
    putEnv("GARDEN_PROJECT_DIR", tmpDir)
    defer:
      delEnv("GARDEN_SWARM_FILE")
      delEnv("GARDEN_PROJECT_DIR")

    let (pOut, pCode) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode == 0
    let j = parseJson(pOut.strip())
    check j["count"].getInt() == 1
    check j["workers"][0]["name"].getStr() == "env-worker"
    check j["workers"][0]["prompt"].getStr().contains("Custom Env Persona")

  test "Garden auto-detects current harness from environment variables":
    let harnessEnvVars = ["ANTIGRAVITY_APP_DIR", "CLAUDE_CODE", "OPENCODE_DESKTOP", "OPENCODE_SESSION_ID", "CODEX_CLI", "CODEX_SESSION_ID", "PI_SESSION_ID"]
    var savedEnv: seq[tuple[k, v: string, present: bool]] = @[]
    for k in harnessEnvVars:
      savedEnv.add((k, getEnv(k, ""), existsEnv(k)))
      delEnv(k)
    defer:
      for item in savedEnv:
        if item.present: putEnv(item.k, item.v)
        else: delEnv(item.k)

    # 1. Antigravity IDE
    putEnv("ANTIGRAVITY_APP_DIR", "/Applications/Antigravity.app")
    let (pOut1, pCode1) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode1 == 0
    let j1 = parseJson(pOut1.strip())
    check j1["workers"][0]["harness"].getStr() == "Antigravity IDE"
    delEnv("ANTIGRAVITY_APP_DIR")

    # 2. Claude Code CLI
    putEnv("CLAUDE_CODE", "1")
    let (pOut2, pCode2) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode2 == 0
    let j2 = parseJson(pOut2.strip())
    check j2["workers"][0]["harness"].getStr() == "Claude Code CLI"
    delEnv("CLAUDE_CODE")

    # 3. OpenCode
    putEnv("OPENCODE_SESSION_ID", "sess_12345")
    let (pOut3, pCode3) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode3 == 0
    let j3 = parseJson(pOut3.strip())
    check j3["workers"][0]["harness"].getStr() == "OpenCode"
    delEnv("OPENCODE_SESSION_ID")

    # 4. ChatGPT Desktop / Codex
    putEnv("CODEX_SESSION_ID", "codex_67890")
    let (pOut4, pCode4) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode4 == 0
    let j4 = parseJson(pOut4.strip())
    check j4["workers"][0]["harness"].getStr() == "ChatGPT Desktop / Codex"
    delEnv("CODEX_SESSION_ID")

    # 5. Pi
    putEnv("PI_SESSION_ID", "pi_abcde")
    let (pOut5, pCode5) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check pCode5 == 0
    let j5 = parseJson(pOut5.strip())
    check j5["workers"][0]["harness"].getStr() == "Pi"
    delEnv("PI_SESSION_ID")

  test "Garden prompts references actual orchestrator without touching Redis aliases":
    let (pOut, pCode) = captureRet(proc (): int = doPrompts("", "", "", "", true, optOrchAgent = "custom-orch-lead"))
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
    let (vOut, vCode) = captureRet(proc (): int = doRosterGuard("garden-architect", jsonOutput = true))
    check vCode == 0
    let vJson = parseJson(vOut.strip())
    check vJson["valid"].getBool() == true
    check vJson["status"].getStr() == "ROSTER_VERIFIED"

    let (aOut, aCode) = captureRet(proc (): int = doRosterGuard("totally-alien-agent", jsonOutput = true))
    check aCode != 0
    let aJson = parseJson(aOut.strip())
    check aJson["valid"].getBool() == false
    check aJson["status"].getStr() == "ALIEN_QUARANTINED"

    # Cluster audit mode
    let (auditOut, _) = captureRet(proc (): int = doRosterGuard("", jsonOutput = true))
    let auditJson = parseJson(auditOut.strip())
    check auditJson.hasKey("audit")
    check auditJson["audit"].getStr() == "ROSTER_AUDIT"
    check auditJson.hasKey("verified_count")
    check auditJson.hasKey("alien_count")

  test "Garden session save, load, and clear lifecycle (zero on-disk JSON)":
    let tmpDir = getTempDir() / ("garden_session_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let (_, sCode) = captureRet(proc (): int = doSession("save", agentName = "test-gardener", role = "architect", projectDir = tmpDir))
    check sCode == 0
    check not fileExists(tmpDir / ".garden" / "session.json")

    let (lOut, lCode) = captureRet(proc (): int = doSession("load", projectDir = tmpDir, jsonOutput = true))
    check lCode == 0
    let lJson = parseJson(lOut.strip())
    check lJson["on_disk_json"].getBool() == false

    let (_, cCode) = captureRet(proc (): int = doSession("clear", projectDir = tmpDir))
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
    let (jOut, jCode) = captureRet(proc (): int = doPrompts("", "", "", "", true))
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j.hasKey("fast_path")
    check j.hasKey("already_listening")
    check j.hasKey("idle_cluster_peers")
    check j.hasKey("foreign_project_peers")
    check j.hasKey("busy_cluster_peers")
    check j.hasKey("suggested_repurpose_commands")

  test "Garden repurpose CLI reassigns workers and emits structured JSON":
    let (rOut, rCode) = captureRet(proc (): int =
      doRepurpose(@["test-idle-agent"], projectParam = "test-garden-proj", roleParam = "Staff Systems Architect", tagsParam = "test,systems", jsonOutput = true)
    )
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
    let (sOut, sCode) = captureRet(proc (): int =
      doRepurpose(@["test-handshake-agent"], projectParam = "test-garden-proj", selfTag = true, expectedTagsParam = "nim,qa,audit", jsonOutput = true)
    )
    check sCode == 0
    let sJson = parseJson(sOut.strip())
    check sJson["status"].getStr() == "ok"
    check sJson["action"].getStr() == "repurpose"
    check sJson["repurposed_workers"][0]["mode"].getStr() == "self_tag"

  proc setupMockRhizo(name, whoJsonStr: string): string =
    let mockDir = getTempDir() / ("garden_mock_rhizo_" & name & "_" & $getCurrentProcessId())
    removeDir(mockDir)
    createDir(mockDir)
    writeFile(mockDir / "who.json", whoJsonStr)
    when defined(windows):
      let script = "@echo off\r\nif \"%~1\"==\"who\" (\r\n  type \"%~dp0who.json\"\r\n  exit /b 0\r\n)\r\nexit /b 0\r\n"
      writeFile(mockDir / "rhizo.cmd", script)
      writeFile(mockDir / "rhizo.bat", script)
    else:
      let script = "#!/bin/sh\nif [ \"$1\" = \"who\" ]; then\n  cat \"$(dirname \"$0\")/who.json\"\n  exit 0\nfi\nexit 0\n"
      let exe = mockDir / "rhizo"
      writeFile(exe, script)
      setFilePermissions(exe, {fpUserRead, fpUserWrite, fpUserExec})
    result = mockDir

  test "Garden repurpose negative control: busy worker rejected without --force, overrides with --force":
    let pidStr = $getCurrentProcessId()
    let busyAgent = "garden-test-busy-" & pidStr
    let targetProj = "garden-test-proj-" & pidStr
    let whoPayload = $(%*[ %*{
      "agent": busyAgent,
      "project": targetProj,
      "status": "ACTIVE",
      "listener": "LISTENING",
      "state": "BUSY (Hermetic busy test)",
      "tags": [targetProj, "worker"]
    } ])
    let mockDir = setupMockRhizo("busy", whoPayload)
    let origPath = getEnv("PATH", "")
    putEnv("PATH", mockDir & $PathSep & origPath)
    defer:
      putEnv("PATH", origPath)
      removeDir(mockDir)

    # 1. Attempting without --force fails
    let (errOut, errCode) = runGardenInProcess(@["repurpose", busyAgent, "--project", targetProj, "--role", "Staff Systems Architect", "--json"])
    check errCode != 0
    let errJson = parseJson(errOut.strip())
    check errJson["status"].getStr() == "error"
    check errJson["error"].getStr().contains("BUSY")

    # 2. Overriding with --force succeeds
    let (fOut, fCode) = runGardenInProcess(@["repurpose", busyAgent, "--project", targetProj, "--role", "Staff Systems Architect", "--force", "--json"])
    check fCode == 0
    let fJson = parseJson(fOut.strip())
    check fJson["status"].getStr() == "ok"
    check fJson["repurposed_workers"][0]["agent"].getStr() == busyAgent

  test "Garden repurpose negative control: foreign project worker rejected without --allow-cross-project, overrides with flag":
    let pidStr = $getCurrentProcessId()
    let foreignAgent = "garden-test-foreign-" & pidStr
    let originalProj = "garden-foreign-proj-" & pidStr
    let whoPayload = $(%*[ %*{
      "agent": foreignAgent,
      "project": originalProj,
      "status": "ACTIVE",
      "listener": "LISTENING",
      "state": "IDLE",
      "tags": [originalProj, "worker"]
    } ])
    let mockDir = setupMockRhizo("foreign", whoPayload)
    let origPath = getEnv("PATH", "")
    putEnv("PATH", mockDir & $PathSep & origPath)
    defer:
      putEnv("PATH", origPath)
      removeDir(mockDir)

    # 1. Attempting without --allow-cross-project fails with cross-project rejection error
    let (errOut, errCode) = runGardenInProcess(@["repurpose", foreignAgent, "--project", "test-anti-poach-proj", "--role", "Staff Systems Architect", "--json"])
    check errCode != 0
    let errJson = parseJson(errOut.strip())
    check errJson["status"].getStr() == "error"
    check errJson["error"].getStr().contains("Cross-project")

    # 2. Overriding with --allow-cross-project succeeds
    let (fOut, fCode) = runGardenInProcess(@["repurpose", foreignAgent, "--project", "test-anti-poach-proj", "--role", "Staff Systems Architect", "--allow-cross-project", "--json"])
    check fCode == 0
    let fJson = parseJson(fOut.strip())
    check fJson["status"].getStr() == "ok"
    check fJson["repurposed_workers"][0]["agent"].getStr() == foreignAgent

  test "Garden prompts fast-path skips card generation when project active workers >= target":
    let tmpDir = getTempDir() / ("garden_fast_path_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)
    
    # Create single-worker swarm matching current active worker (garden-botanist)
    let swarmFile = tmpDir / "test-fast-swarm.json"
    writeFile(swarmFile, $(%*{
      "project": "garden",
      "target_repo": tmpDir,
      "orchestrator": "test-orch",
      "workers": [
        {
          "name": "garden-botanist",
          "role": "Ceremony & Swarm On-Ramp Lead"
        }
      ]
    }))

    # 1. Fast-Path Activated (without --force-prompts) if active garden workers exist on cluster
    var hasActiveGardenWorker = false
    try:
      let (whoOut, whoCode) = execShellCmdEx("rhizo who --project garden --json")
      if whoCode == 0 and whoOut.strip().len > 0:
        let parsed = parseJson(whoOut.strip())
        let list = if parsed.kind == JArray: parsed elif parsed.hasKey("agents"): parsed["agents"] else: newJArray()
        for item in list:
          let lis = item.getOrDefault("listener").getStr("").toUpperAscii()
          let name = item.getOrDefault("agent").getStr("")
          if lis == "LISTENING" and name == "garden-botanist":
            hasActiveGardenWorker = true
            break
    except CatchableError:
      hasActiveGardenWorker = false

    if hasActiveGardenWorker:
      let (fpOut, fpCode) = runGardenInProcess(@["prompts", "-f", swarmFile, "--json"])
      check fpCode == 0
      let fpJson = parseJson(fpOut.strip())
      check fpJson["fast_path"].getBool() == true
      check fpJson["active_workers_count"].getInt() >= 1

    # 2. Force Prompts Flag overrides fast-path
    let (forceOut, forceCode) = runGardenInProcess(@["prompts", "-f", swarmFile, "--force-prompts", "--json"])
    check forceCode == 0
    let forceJson = parseJson(forceOut.strip())
    check forceJson["fast_path"].getBool() == false
    check forceJson["count"].getInt() == 1
    check forceJson["workers"].len == 1

  test "Negative control: Zero on-disk JSON verification across init, prompts, status, roadmap":
    let tmpDir = getTempDir() / ("garden_zero_json_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    # 1. Garden init
    let (_, iCode) = captureRet(proc(): int = doInit(tmpDir, false))
    check iCode == 0
    check not fileExists(tmpDir / "garden-swarm.json")
    check not fileExists(tmpDir / ".garden" / "roadmap.json")
    check not fileExists(tmpDir / ".garden" / "session.json")

    # 2. Plant seed and run roadmap
    let (_, plCode) = captureRet(proc(): int = doPlant("Zero JSON Seed", "v1.0", "", "", "", tmpDir, false, false))
    check plCode == 0
    let (_, rCode) = captureRet(proc(): int = doRoadmap("", tmpDir, false, true))
    check rCode == 0
    check fileExists(tmpDir / "ROADMAP.md")
    check not fileExists(tmpDir / ".garden" / "roadmap.json")
    check not fileExists(tmpDir / "garden-swarm.json")
    check not fileExists(tmpDir / ".garden" / "session.json")

    # 3. Prompts generation
    let (_, pCode) = runGardenInProcess(@["prompts", "--project-dir", tmpDir, "--json"])
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
    check prompt.contains("--ticket <hex>")
    check prompt.contains("--evidence")
    check prompt.contains("--listen")
    check not prompt.contains("--weave")
    check prompt.contains("MERGE-CLERK DECOUPLING INVARIANT")
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
    check prompt.contains("Vine tracks strand identity in `.git/config`")
    check prompt.contains("zero on-disk `.vine.json` state files")
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
    check prompt.contains("Multiplexed Router & In-Process Ear Active")
    check prompt.contains("DO NOT launch a redundant blocking shell listener")
    check prompt.contains("rhizo session register")
    check not prompt.contains("Arm single-shot listener for incoming directives:\nrhizo listen")

  test "generateWorkerPrompt for Antigravity uses continuous ambient ear and lifecycle hooks":
    let cfg = SwarmConfig(
      project: "testproj",
      targetRepo: "/tmp/testproj",
      orchestrator: "lead",
      orchestratorAgent: "lead"
    )
    let w = WorkerSpec(
      name: "agy-coder",
      persona: "Sequoia",
      role: "Systems Architect",
      harness: "Antigravity IDE",
      tags: @["testproj", "systems"],
      profile: "implementation",
      systemPrompt: "Architect cleanly."
    )
    let prompt = generateWorkerPrompt(cfg, w)
    # Section 2 checks
    check prompt.contains("rhizo hook install --antigravity --agent \"agy-coder\"")
    check prompt.contains("Multiplexed Router & Session Registry Active")
    check prompt.contains("Continuous Ambient Ear & Hooks")
    check prompt.contains("agentapi send-message")
    check prompt.contains("rhizo session register")
    check not prompt.contains("Arm single-shot listener for incoming directives:\nrhizo listen")
    # Section 3 checks: no obsolete manual run_command WaitMsBeforeAsync=500 non-yield invariant
    check not prompt.contains("MANDATORY ANTIGRAVITY NON-YIELD INVARIANT")
    check not prompt.contains("run_command(WaitMsBeforeAsync=500)")
    check prompt.contains("MULTIPLEXED ROUTER EXECUTION")
    # Section 4 checks
    check prompt.contains("Multiplexed Router & Session Registry Active")
    check not prompt.contains("Single-Shot Blocking")
    # Section 7 checks
    check prompt.contains("Multiplexed Router")
    check prompt.contains("Continuous Ambient Ear")
    check prompt.contains("rhizo router")

  test "generateWorkerPrompt for Claude Code and Codex retain single-shot blocking listener discipline":
    let cfg = SwarmConfig(
      project: "testproj",
      targetRepo: "/tmp/testproj",
      orchestrator: "lead",
      orchestratorAgent: "lead"
    )
    let wClaude = WorkerSpec(
      name: "claude-coder",
      persona: "Briar",
      role: "Systems Architect",
      harness: "Claude Code CLI",
      tags: @["testproj", "systems"],
      profile: "implementation",
      systemPrompt: "Build cleanly."
    )
    let pClaude = generateWorkerPrompt(cfg, wClaude)
    check pClaude.contains("Arm single-shot listener for incoming directives:\nrhizo listen \"claude-coder\"")
    check pClaude.contains("Single-Shot Blocking")
    check pClaude.contains("rhizo listen")
    check not pClaude.contains("Continuous Ambient Ear")

    let wCodex = WorkerSpec(
      name: "codex-coder",
      persona: "Cedar",
      role: "Systems Architect",
      harness: "ChatGPT Desktop / Codex",
      tags: @["testproj", "systems"],
      profile: "implementation",
      systemPrompt: "Build cleanly."
    )
    let pCodex = generateWorkerPrompt(cfg, wCodex)
    check pCodex.contains("Arm single-shot listener for incoming directives:\nrhizo listen \"codex-coder\"")
    check pCodex.contains("Single-Shot Blocking")
    check pCodex.contains("RHIZO_WAKE")

  test "SKILL.md is reconciled with skills/garden/SKILL.md":
    let rootSkill = readFile(getCurrentDir() / "SKILL.md").replace("\r\n", "\n")
    let pkgSkill = readFile(getCurrentDir() / "skills" / "garden" / "SKILL.md").replace("\r\n", "\n")
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
    let subcmds = @["init", "plant", "roadmap", "germinate", "repurpose", "prompts", "launch", "status", "guide", "update"]
    for s in subcmds:
      let (outp, code) = runGardenInProcess(@[s, "--help"])
      check code == 0
      check outp.contains("Usage: garden " & s)

    # Test help <subcmd> syntax
    let (outp2, code2) = runGardenInProcess(@["help", "init"])
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
    check cfg.workers[1].roleSlug == "auditor"
    check cfg.workers[1].profile == "audit"

    # Verify generated prompt for investigator does NOT contain strand creation or commit
    let invPrompt = generateWorkerPrompt(cfg, cfg.workers[0])
    check invPrompt.contains("Profile / Capability**: Investigation & Review (Non-Modifying / Read-Only)")
    check not invPrompt.contains("vine new <task_id>")
    check not invPrompt.contains("vine changelog")

suite "Strict Unknown Flag Rejection & Intuitive Synonyms Suite":

  test "Strict Unknown Flag Rejection (exit code 2) across all subcommands":
    let subcmds = @[
      "plant", "roadmap", "germinate", "repurpose", "prompts",
      "launch", "init", "status", "teardown", "roster-guard",
      "session", "guide", "update"
    ]
    for subcmd in subcmds:
      let (outp, code) = runGardenInProcess(@[subcmd, "--bogus"])
      check code == 2
      check outp.contains("Error: Unknown option --bogus for garden " & subcmd)

  test "Fail-Fast Required Arguments (exit code 1) on plant, germinate, and repurpose":
    # 1. plant without title and without --list
    let (pOut, pCode) = runGardenInProcess(@["plant"])
    check pCode == 1
    check pOut.contains("Missing required description for garden plant")

    # 2. germinate without seed_id
    let (gOut, gCode) = runGardenInProcess(@["germinate", "dispatch"])
    check gCode == 1
    check gOut.contains("Missing required <seed_id> for garden germinate dispatch")

    # 3. germinate with nonexistent seed_id
    let (gOut2, gCode2) = runGardenInProcess(@["germinate", "dispatch", "nonexistent-seed-12345"])
    check gCode2 == 1
    check gOut2.contains("Seed not found")

    # 4. repurpose without worker
    let (rOut1, rCode1) = runGardenInProcess(@["repurpose"])
    check rCode1 == 1
    check rOut1.contains("Missing required worker(s)")

    # 5. repurpose without project (when no garden.toml exists)
    let (rOut2, rCode2) = runGardenInProcess(@["repurpose", "test-worker-1"])
    check rCode2 == 1
    check rOut2.contains("Missing required --project")

    # 6. repurpose without role or self-tag
    let (rOut3, rCode3) = runGardenInProcess(@["repurpose", "test-worker-1", "--project", "test-custom-proj"])
    check rCode3 == 1
    check rOut3.contains("Missing required role assignment")

  test "Intuitive Flag Synonyms on garden plant (--title, --description, --prompt, -m, --priority, --milestone, --release)":
    let tmpDir = getTempDir() / ("garden_plant_aliases_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: (try: removeDir(tmpDir) except CatchableError: discard)

    # --title and --priority
    let (out1, code1) = runGardenInProcess(@["plant", "--title", "Feature Alpha", "--priority", "blazing", "--milestone", "v1.0.0", "--project-dir", tmpDir, "--json"])
    check code1 == 0
    let j1 = parseJson(out1.strip())
    check j1["title"].getStr() == "Feature Alpha"
    check j1["sunlight"].getStr() == "blazing"
    check j1["season"].getStr() == "v1.0.0"

    # --description and --release
    let (out2, code2) = runGardenInProcess(@["plant", "--description", "Feature Beta", "--release", "v1.1.0", "--project-dir", tmpDir, "--json"])
    check code2 == 0
    let j2 = parseJson(out2.strip())
    check j2["title"].getStr() == "Feature Beta"
    check j2["season"].getStr() == "v1.1.0"

    # --prompt
    let (out3, code3) = runGardenInProcess(@["plant", "--prompt", "Feature Gamma", "--project-dir", tmpDir, "--json"])
    check code3 == 0
    let j3 = parseJson(out3.strip())
    check j3["title"].getStr() == "Feature Gamma"

    # -m
    let (out4, code4) = runGardenInProcess(@["plant", "-m", "Feature Delta", "--project-dir", tmpDir, "--json"])
    check code4 == 0
    let j4 = parseJson(out4.strip())
    check j4["title"].getStr() == "Feature Delta"

  test "Intuitive Flag Synonyms on garden germinate (--seed, --id, -s)":
    let tmpDir = getTempDir() / ("garden_germ_aliases_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: (try: removeDir(tmpDir) except CatchableError: discard)

    # Sow a seed to germinate
    let (_, pCode) = runGardenInProcess(@["plant", "Germinate Seed Target", "--id", "seed-target-01", "--project-dir", tmpDir])
    check pCode == 0

    # germinate status via --seed
    let (gOut1, gCode1) = runGardenInProcess(@["germinate", "status", "--seed", "seed-target-01", "--project-dir", tmpDir, "--json"])
    check gCode1 == 0
    let j1 = parseJson(gOut1.strip())
    check j1["seed_id"].getStr() == "seed-target-01"

    # germinate status via --id
    let (gOut2, gCode2) = runGardenInProcess(@["germinate", "status", "--id", "seed-target-01", "--project-dir", tmpDir, "--json"])
    check gCode2 == 0
    let j2 = parseJson(gOut2.strip())
    check j2["seed_id"].getStr() == "seed-target-01"

    # germinate status via -s
    let (gOut3, gCode3) = runGardenInProcess(@["germinate", "status", "-s", "seed-target-01", "--project-dir", tmpDir, "--json"])
    check gCode3 == 0
    let j3 = parseJson(gOut3.strip())
    check j3["seed_id"].getStr() == "seed-target-01"

  test "Intuitive Flag Synonyms on garden repurpose (--worker, --workers, --agent, --to)":
    # --workers and --project and --role
    let (rOut1, rCode1) = runGardenInProcess(@["repurpose", "--workers", "test-worker-a,test-worker-b", "--project", "test-synonym-proj", "--role", "Staff Systems Architect", "--json"])
    check rCode1 == 0
    let j1 = parseJson(rOut1.strip())
    check j1["repurposed_count"].getInt() == 2
    check j1["repurposed_workers"][0]["agent"].getStr() == "test-worker-a"
    check j1["repurposed_workers"][1]["agent"].getStr() == "test-worker-b"

    # --agent and --to
    let (rOut2, rCode2) = runGardenInProcess(@["repurpose", "--agent", "test-worker-c", "--to", "test-worker-d", "--project", "test-synonym-proj", "--self-tag", "--json"])
    check rCode2 == 0
    let j2 = parseJson(rOut2.strip())
    check j2["repurposed_count"].getInt() == 2
    check j2["repurposed_workers"][0]["agent"].getStr() == "test-worker-c"
    check j2["repurposed_workers"][1]["agent"].getStr() == "test-worker-d"

  test "Intuitive Flag Synonyms on garden prompts and launch (--workers, --count, --harness, --project, --force)":
    # --count 2 and --harness and --project
    let (pOut1, pCode1) = runGardenInProcess(@["prompts", "--count", "2", "--project", "test-p-proj", "--harness", "Custom Harness", "--force", "--json"])
    check pCode1 == 0
    let j1 = parseJson(pOut1.strip())
    check j1["project"].getStr() == "test-p-proj"
    check j1["workers"].len == 2
    check j1["workers"][0]["harness"].getStr() == "Custom Harness"

    # garden launch with --workers 1 and --force
    let (lOut, lCode) = runGardenInProcess(@["launch", "--workers", "1", "--project", "test-l-proj", "--force", "--json"])
    check lCode == 0
    let j2 = parseJson(lOut.strip())
    check j2["project"].getStr() == "test-l-proj"
    check j2["workers"].len == 1

suite "Capability-Aware Execution Modes, Subagent Briefs & Tmux Suite":

  test "resolveExecutionMode selects drillable subagents, tmux, and prompts by harness capability":
    # 1. Antigravity IDE and OpenCode default to drillable subagents
    check supportsDrillableSubagents("Antigravity IDE") == true
    check supportsDrillableSubagents("OpenCode") == true
    check supportsDrillableSubagents("OpenCode Desktop") == true
    check supportsDrillableSubagents("ChatGPT Desktop / Codex") == false
    check supportsDrillableSubagents("Codex CLI") == false
    check supportsDrillableSubagents("Claude Code CLI") == false

    check resolveExecutionMode("Antigravity IDE", inTmux = false) == "subagents"
    check resolveExecutionMode("OpenCode", inTmux = false) == "subagents"
    check resolveExecutionMode("OpenCode Desktop", inTmux = false) == "subagents"

    # 2. Codex Desktop defaults to prompt cards
    check supportsTmuxFactory("ChatGPT Desktop / Codex") == false
    check supportsTmuxFactory("Antigravity IDE") == false
    check supportsTmuxFactory("Codex CLI") == true
    check supportsTmuxFactory("Claude Code CLI") == true
    check resolveExecutionMode("ChatGPT Desktop / Codex", inTmux = false) == "prompts"

    # 3. Codex CLI / Claude Code CLI select tmux only when inTmux or optTmux; forcePrompts overrides to prompts
    check resolveExecutionMode("Codex CLI", inTmux = true) == "tmux"
    check resolveExecutionMode("Codex CLI", inTmux = false) == "prompts"
    check resolveExecutionMode("Codex CLI", optTmux = true, inTmux = false) == "tmux"
    check resolveExecutionMode("Codex CLI", optSubagent = true, inTmux = false) == "subagents"
    check resolveExecutionMode("Claude Code CLI", inTmux = true) == "tmux"
    check resolveExecutionMode("Claude Code CLI", inTmux = false) == "prompts"
    check resolveExecutionMode("Codex CLI", configuredMode = "subagents", inTmux = false) == "subagents"
    check resolveExecutionMode("Antigravity IDE", configuredMode = "tmux", inTmux = false) == "tmux"
    check resolveExecutionMode("Codex CLI", forcePrompts = true, optTmux = true, inTmux = true) == "prompts"
    check resolveExecutionMode("Antigravity IDE", forcePrompts = true, optSubagent = true) == "prompts"

  test "garden prompts --subagent --task generates structured briefs and subagent execution mode":
    let tmpProj = "test-subagent-proj-" & $getCurrentProcessId()
    defer: (try: removeDir(getGardenTempDir(tmpProj)) except CatchableError: discard)
    let (sOut, sCode) = runGardenInProcess(@["prompts", "--project", tmpProj, "--harness", "Codex CLI", "--subagent", "--task", "task-123", "--force", "--json"])
    check sCode == 0
    let j = parseJson(sOut.strip())
    check j["execution_mode"].getStr() == "subagents"
    check j["supports_drillable_subagents"].getBool() == false
    check j["workers"].len == 3

    var foundArch = false
    var foundImpl = false
    var foundAudit = false
    for w in j["workers"]:
      let roleSlug = w["role_slug"].getStr()
      let brief = w["subagent_brief"].getStr()
      let subPath = w["subagent_file_path"].getStr()
      check fileExists(subPath)
      check readFile(subPath) == brief
      check w["execution_mode"].getStr() == "subagents"
      check brief.contains("--agent \"" & w["name"].getStr() & "\"")
      if roleSlug == "architect":
        foundArch = true
        check brief.contains("rhizo task claim \"task-123\" --no-vine")
      elif roleSlug == "implementer":
        foundImpl = true
        check brief.contains("vine new \"task-123\"")
        check brief.contains("vine submit")
        check brief.contains("YOU ARE NOT THE AUDITOR")
      elif roleSlug == "auditor":
        foundAudit = true
        check brief.contains("vine audit inspect \"task-123\"")
        check brief.contains("vine audit approve \"task-123\"")
    check foundArch
    check foundImpl
    check foundAudit

    # Negative control: --force-prompts overrides --subagent back to prompts even on Antigravity IDE
    let (fpOut, fpCode) = runGardenInProcess(@["prompts", "--project", tmpProj, "--harness", "Antigravity IDE", "--subagent", "--force-prompts", "--json"])
    check fpCode == 0
    let fpJson = parseJson(fpOut.strip())
    check fpJson["supports_drillable_subagents"].getBool() == true
    check fpJson["execution_mode"].getStr() == "prompts"

  test "garden launch --tmux --dry-run outputs tmux execution mode and worker spawn commands":
    let tmpProj = "test-tmux-proj-" & $getCurrentProcessId()
    defer: (try: removeDir(getGardenTempDir(tmpProj)) except CatchableError: discard)
    let (tOut, tCode) = runGardenInProcess(@["launch", "--project", tmpProj, "--harness", "Codex CLI", "--tmux", "--dry-run", "--force", "--json"])
    check tCode == 0
    let j = parseJson(tOut.strip())
    check j["execution_mode"].getStr() == "tmux"
    check j["supports_tmux"].getBool() == true
    check j["workers"].len == 3
    for w in j["workers"]:
      let tmuxCmd = w["tmux_command"].getStr()
      let promptPath = w["file_path"].getStr()
      let expectedInner = "codex " & quoteShell("Read and execute the bootstrap instructions in " & promptPath)
      let expectedTmux = "tmux new-window -n " & quoteShell(w["name"].getStr()) & " -c " & quoteShell(j["target_repo"].getStr()) & " " & quoteShell(expectedInner)
      check tmuxCmd == expectedTmux

    # Negative controls: unknown option (exit 2), invalid --mode value (exit 1), missing --mode value (exit 1)
    let (_, badCode) = runGardenInProcess(@["launch", "--tmux", "--bogus-mode-flag"])
    check badCode == 2

    let (badModeOut, badModeCode) = runGardenInProcess(@["launch", "--mode", "bogus"])
    check badModeCode == 1
    check badModeOut.contains("Invalid execution mode 'bogus'")

    let (missingModeOut, missingModeCode) = runGardenInProcess(@["prompts", "--mode"])
    check missingModeCode == 1
    check missingModeOut.contains("Missing required value for --mode")

  test "garden.toml execution_mode parsing and garden init default":
    let tmpDir = getTempDir() / ("garden_exec_mode_test_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: (try: removeDir(tmpDir) except CatchableError: discard)

    let (_, iCode) = captureRet(proc(): int = doInit(tmpDir, false))
    check iCode == 0
    check readFile(tmpDir / "garden.toml").contains("execution_mode = \"auto\"")

    writeFile(tmpDir / "garden.toml", "[project]\nname = \"exec-mode-proj\"\n\n[swarm]\nexecution_mode = \"prompts\"\n")
    let cfg = loadSwarmConfig(projectDir = tmpDir)
    check cfg.project == "exec-mode-proj"
    check cfg.workers.len == 3
    check "exec-mode-proj" in cfg.workers[0].tags
    check cfg.executionMode == "prompts"
    check resolveExecutionMode("Antigravity IDE", cfg.executionMode) == "prompts"

suite "Garden Bin Riders Verification Suite":

  test "bin/*.js riders exist and target @axiomantic packages and rift-snapshot":
    let runJs = getCurrentDir() / "bin" / "run.js"
    check fileExists(runJs)
    check readFile(runJs).contains("garden")

    let expectedRiders = [
      ("bin" / "rhizo.js", "@axiomantic/rhizo"),
      ("bin" / "vine.js", "@axiomantic/vine"),
      ("bin" / "rift.js", "rift-snapshot")
    ]
    for (relPath, pkgName) in expectedRiders:
      let fullPath = getCurrentDir() / relPath
      check fileExists(fullPath)
      let content = readFile(fullPath)
      check content.contains(pkgName)
      check content.startsWith("#!/usr/bin/env node")

    for staleFile in ["test_garden", "test_seed", "test_germinate", "test_roadmap", "test_update", "test_riders.js"]:
      check not fileExists(getCurrentDir() / "tests" / staleFile)






