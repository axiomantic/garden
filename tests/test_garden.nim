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
    check sCode == 0
    let j = parseJson(sOut.strip())
    check j.hasKey("project")
    check j.hasKey("session_name")
    check j.hasKey("tmux_active")
    check j.hasKey("windows")
