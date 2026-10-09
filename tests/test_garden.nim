# tests/test_garden.nim
# Comprehensive unit & integration tests for Garden CLI and Guide management engine.

import std/[os, osproc, strutils, json, unittest]
import ../src/guide

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

  test "Garden prompts generates 10-backtick raw markdown blocks for default triad":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (pOut, pCode) = execCmdEx(exePath & " prompts")
    check pCode == 0
    check pOut.contains("GARDEN SWARM BOOTSTRAP")
    check pOut.contains("``````````markdown")
    check pOut.contains("architect")
    check pOut.contains("auditor")
    check pOut.contains("implementer")
    check pOut.contains("export RHIZO_AGENT_NAME=")
    check pOut.contains("rhizo open")
    check pOut.contains("rhizo listen")
    check pOut.contains("Single-Shot Blocking")
    check pOut.contains("SWARM_RUNTIME_STATE")

  test "Garden prompts --worker filters output to target worker":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (pOut, pCode) = execCmdEx(exePath & " prompts --worker auditor")
    check pCode == 0
    check pOut.contains("auditor")
    check pOut.contains("Caleb Thorne")
    check not pOut.contains("Marcus Vance")
    check not pOut.contains("Elena Rostova")

  test "Garden prompts --json outputs structured json telemetry":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (jOut, jCode) = execCmdEx(exePath & " prompts --json")
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j["count"].getInt() == 3
    check j["workers"].len == 3
    check j["workers"][0]["name"].getStr() == "garden-architect"
    check j["workers"][0]["prompt"].getStr().contains("Marcus Vance")

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

  test "Garden launch defaults to prompt generation without requiring tmux":
    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let (lOut, lCode) = execCmdEx(exePath & " launch --worker implementer")
    check lCode == 0
    check lOut.contains("Elena Rostova")
    check lOut.contains("``````````markdown")

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


