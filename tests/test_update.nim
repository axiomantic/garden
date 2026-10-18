# /Users/eek/Development/garden/tests/test_update.nim
# Unit and integration tests for Garden Triad Update Subsystem.

import std/[os, strutils, json, unittest]
import ../src/update

suite "Garden Triad Update Subsystem Suite":

  test "Semver parsing and comparative ordering":
    check isNewerSemver("0.2.18", "0.2.17") == true
    check isNewerSemver("0.3.0", "0.2.17") == true
    check isNewerSemver("1.0.0", "0.9.9") == true
    check isNewerSemver("0.2.17", "0.2.17") == false
    check isNewerSemver("0.2.16", "0.2.17") == false
    check isNewerSemver("v0.2.18", "v0.2.17") == true
    check isNewerSemver("0.2.18-beta", "0.2.17") == true

  test "Config serialization and settings lifecycle":
    let origDir = getAxiomanticConfigDir()
    let testConfigDir = getTempDir() / "garden_update_test_" & $getCurrentProcessId()
    createDir(testConfigDir)
    defer: removeDir(testConfigDir)

    var cfg = %*{
      "last_checked_at": 1729190000,
      "settings": {
        "update_check": "daily",
        "prompt_rider": true,
        "ignored_versions": {
          "garden": "",
          "rhizo": "",
          "vine": ""
        }
      }
    }
    let testPath = testConfigDir / "updates.json"
    writeFile(testPath, pretty(cfg))
    check fileExists(testPath)

    let loaded = parseJson(readFile(testPath))
    check loaded["settings"]["update_check"].getStr() == "daily"
    check loaded["settings"]["prompt_rider"].getBool() == true

  test "Install kind detection detects dev repo and binary paths":
    # 1. Hermetically test dev source detection using temporary test package
    let tmpDevDir = getTempDir() / "garden_mock_dev_repo"
    createDir(tmpDevDir / "bin")
    writeFile(tmpDevDir / "mockpkg.nimble", "version = \"0.1.0\"\n")
    let binExt = if defined(windows): ".cmd" else: ""
    let mockBin = tmpDevDir / "bin" / ("mockpkg" & binExt)
    writeFile(mockBin, if defined(windows): "@echo 0.1.0\r\n" else: "#!/bin/sh\necho 0.1.0\n")
    setFilePermissions(mockBin, {fpUserExec, fpUserRead, fpUserWrite})

    let origPath = getEnv("PATH")
    putEnv("PATH", (tmpDevDir / "bin") & PathSep & origPath)
    defer:
      putEnv("PATH", origPath)
      removeDir(tmpDevDir)

    let devDetection = detectInstallKind("mockpkg")
    check devDetection.kind == ikDevSource
    check "git -C" in devDetection.updateCommand
    check "nimble build" in devDetection.updateCommand

    # 2. Test against non-existent binary
    let unknownDetection = detectInstallKind("non_existent_binary_xyz_123")
    check unknownDetection.kind == ikGlobalNpm
    check unknownDetection.updateCommand.contains("npm install -g")

  test "Autonomous mode suppresses prompt rider":
    putEnv("AUTONOMOUS_MODE", "1")
    defer: delEnv("AUTONOMOUS_MODE")
    check isAutonomousModeActive() == true
    let rider = getUpdatePromptRider("0.2.17")
    check rider.len == 0

  test "CLI doUpdateCommand settings flags":
    # Test --skip flag
    let skipCode = doUpdateCommand(@["--skip", "vine@99.9.9"], "0.2.17")
    check skipCode == 0
    let cfgAfterSkip = loadUpdatesConfig()
    check cfgAfterSkip["settings"]["ignored_versions"]["vine"].getStr() == "99.9.9"

    # Test --disable flag
    let disableCode = doUpdateCommand(@["--disable"], "0.2.17")
    check disableCode == 0
    let cfgAfterDisable = loadUpdatesConfig()
    check cfgAfterDisable["settings"]["prompt_rider"].getBool() == false
    check cfgAfterDisable["settings"]["update_check"].getStr() == "never"

    # Test --enable flag
    let enableCode = doUpdateCommand(@["--enable"], "0.2.17")
    check enableCode == 0
    let cfgAfterEnable = loadUpdatesConfig()
    check cfgAfterEnable["settings"]["prompt_rider"].getBool() == true
    check cfgAfterEnable["settings"]["update_check"].getStr() == "daily"

    # Reset ignored version
    cfgAfterEnable["settings"]["ignored_versions"]["vine"] = %""
    saveUpdatesConfig(cfgAfterEnable)
