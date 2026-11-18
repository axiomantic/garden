# tests/test_germinate.nim
# Full test coverage for Garden germinate subcommands (dispatch, prompt, inline, status), invalid seed rejection, and JSON output.

import std/[os, strutils, json, unittest]
import ../src/[seed, germinate, garden]
import ./test_helpers

suite "Garden Germinate Core Engine Suite":

  test "germinateStatus returns lifecycle stage and visual pipeline":
    let tmpDir = getTempDir() / ("garden_germ_status_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed("Botanical Compiler", projectRoot = tmpDir, season = "spring", sunlight = "high")
    let (ok, msg, jNode) = germinateStatus(s.id, tmpDir)
    check ok == true
    check msg.contains("Seed Lifecycle: Botanical Compiler")
    check msg.contains("Status:   SOWN")
    check msg.contains("[SOWN] -> DISPATCHED -> GERMINATING -> GERMINATED")

    check jNode["status"].getStr() == "ok"
    check jNode["action"].getStr() == "status"
    check jNode["seed_id"].getStr() == s.id
    check jNode["lifecycle_stage"].getStr() == "SOWN"

  test "germinatePrompt generates prompt cards in tmp directory and supports --inline":
    let tmpDir = getTempDir() / ("garden_germ_prompt_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed("Gossip Bus", projectRoot = tmpDir, season = "autumn", sunlight = "blazing", tags = @["p2p", "bus"])
    let (ok, msg, jNode) = germinatePrompt(s.id, targetWorker = "architect", projectRoot = tmpDir)
    defer:
      if jNode.hasKey("temp_dir") and jNode["temp_dir"].getStr().len > 0:
        removeDir(jNode["temp_dir"].getStr())
    check ok == true
    check msg.contains("GARDEN GERMINATION: Seed 'Gossip Bus'")
    check msg.contains("Gossip Bus")
    check msg.contains(".md")

    check jNode["action"].getStr() == "prompt"
    check jNode["count"].getInt() == 1
    check jNode["prompts"][0]["prompt"].getStr().contains("``````````markdown")
    check jNode.hasKey("temp_dir")
    check jNode["prompts"][0].hasKey("file_path")
    check fileExists(jNode["prompts"][0]["file_path"].getStr())

    # Verify seed status was transitioned to PROMPTED
    let reloaded = loadSeed(s.id, tmpDir)
    check reloaded.status == "PROMPTED"

    # Test inline mode
    let (iOk, iMsg, _) = germinatePrompt(s.id, targetWorker = "architect", projectRoot = tmpDir, inlineOutput = true)
    check iOk == true
    check iMsg.contains("``````````markdown")
    check iMsg.contains("Swarm Germination Card: Gossip Bus")

  test "germinateDispatch enqueues task and updates status to DISPATCHED":
    let tmpDir = getTempDir() / ("garden_germ_disp_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed("Queue Dispatch Task", projectRoot = tmpDir, season = "winter", sunlight = "medium")
    let (ok, msg, jNode) = germinateDispatch(s.id, tmpDir)
    check ok == true
    check msg.contains("Dispatched seed 'Queue Dispatch Task'")

    check jNode["action"].getStr() == "dispatch"
    check jNode["enqueued"].getBool() == true
    check jNode["seed"]["status"].getStr() == "DISPATCHED"

    let reloaded = loadSeed(s.id, tmpDir)
    check reloaded.status == "DISPATCHED"

  test "germinateInline runs 3-stage dialectical pump and marks GERMINATED":
    let tmpDir = getTempDir() / ("garden_germ_inline_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed("Inline Engine", projectRoot = tmpDir)
    let (ok, msg, jNode) = germinateInline(s.id, tmpDir)
    check ok == true
    check msg.contains("Research & Understanding")
    check msg.contains("Product & System Architecture Design")
    check msg.contains("Adversarial Design Review")
    check msg.contains("Lifecycle updated: GERMINATED")

    check jNode["action"].getStr() == "inline"
    check jNode["lifecycle_stage"].getStr() == "GERMINATED"
    check jNode["stages"].len == 3

    let reloaded = loadSeed(s.id, tmpDir)
    check reloaded.status == "GERMINATED"

  test "Negative controls: invalid seed rejection":
    let tmpDir = getTempDir() / ("garden_germ_neg_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let (ok1, msg1, _) = germinateStatus("unknown-seed-id", tmpDir)
    check ok1 == false
    check msg1.contains("Seed not found")

    let (ok2, msg2, _) = germinateDispatch("missing-seed", tmpDir)
    check ok2 == false
    check msg2.contains("Seed not found")

    let (ok3, msg3, _) = germinatePrompt("fake-seed", projectRoot = tmpDir)
    check ok3 == false
    check msg3.contains("Seed not found")

    let (ok4, msg4, _) = germinateInline("ghost-seed", tmpDir)
    check ok4 == false
    check msg4.contains("Seed not found")

suite "Garden CLI 'garden germinate' Integration Suite":

  test "CLI garden germinate status outputs formatted text and json":
    let tmpDir = getTempDir() / ("garden_cli_germ_status_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    discard captureRet(proc (): int = doPlant("CLI Status Seed", "", "", "", "", tmpDir, false, false))

    # Formatted status
    let (sOut, sCode) = captureRet(proc (): int =
      doGerminate("status", "cli-status-seed", projectDir = tmpDir)
    )
    check sCode == 0
    check sOut.contains("Seed Lifecycle: CLI Status Seed")
    check sOut.contains("Status:   SOWN")

    # JSON status
    let (jOut, jCode) = captureRet(proc (): int =
      doGerminate("status", "cli-status-seed", projectDir = tmpDir, jsonOutput = true)
    )
    check jCode == 0
    let j = parseJson(jOut.strip())
    check j["action"].getStr() == "status"
    check j["seed_id"].getStr() == "cli-status-seed"
    check j["lifecycle_stage"].getStr() == "SOWN"

  test "CLI garden germinate prompt emits 10-backtick prompt cards":
    let tmpDir = getTempDir() / ("garden_cli_germ_prompt_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    discard captureRet(proc (): int = doPlant("CLI Prompt Seed", "summer", "high", "", "", tmpDir, false, false))

    let (pOut, pCode) = captureRet(proc (): int =
      doGerminate("prompt", "cli-prompt-seed", targetWorker = "auditor", projectDir = tmpDir)
    )
    check pCode == 0
    check pOut.contains("CLI Prompt Seed")
    check pOut.contains("Auditor")
    check pOut.contains(".md")

    # Verify --inline flag
    let (iOut, iCode) = captureRet(proc (): int =
      doGerminate("prompt", "cli-prompt-seed", targetWorker = "auditor", projectDir = tmpDir, inlineOutput = true)
    )
    check iCode == 0
    check iOut.contains("``````````markdown")
    check iOut.contains("CLI Prompt Seed")

    let (jOut, jCode) = captureRet(proc (): int =
      doGerminate("prompt", "cli-prompt-seed", projectDir = tmpDir, jsonOutput = true)
    )
    check jCode == 0
    let j = parseJson(jOut.strip())
    defer:
      if j.hasKey("temp_dir") and j["temp_dir"].getStr().len > 0:
        removeDir(j["temp_dir"].getStr())
    check j["action"].getStr() == "prompt"
    check j["prompts"].len > 0
    check j["prompts"][0].hasKey("file_path")
    check fileExists(j["prompts"][0]["file_path"].getStr())

  test "CLI garden germinate dispatch and inline execution":
    let tmpDir = getTempDir() / ("garden_cli_germ_exec_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    discard captureRet(proc (): int = doPlant("Execution Target", "", "", "", "", tmpDir, false, false))

    # Dispatch
    let (dOut, dCode) = captureRet(proc (): int =
      doGerminate("dispatch", "execution-target", projectDir = tmpDir, jsonOutput = true)
    )
    check dCode == 0
    let dJson = parseJson(dOut.strip())
    check dJson["action"].getStr() == "dispatch"
    check dJson["seed"]["status"].getStr() == "DISPATCHED"

    # Inline
    let (iOut, iCode) = captureRet(proc (): int =
      doGerminate("inline", "execution-target", projectDir = tmpDir, jsonOutput = true)
    )
    check iCode == 0
    let iJson = parseJson(iOut.strip())
    check iJson["action"].getStr() == "inline"
    check iJson["lifecycle_stage"].getStr() == "GERMINATED"
    check iJson["stages"].len == 3

  test "CLI negative controls: missing seed, unknown action, missing seed id":
    let tmpDir = getTempDir() / ("garden_cli_germ_neg_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    # Missing arguments
    let (mOut, mCode) = runGardenInProcess(@["germinate"])
    check mCode != 0
    check mOut.contains("Usage: garden germinate")

    # Missing seed id
    let (sOut, sCode) = runGardenInProcess(@["germinate", "dispatch"])
    check sCode != 0
    check sOut.contains("Usage: garden germinate dispatch")

    # Unknown action
    let (uOut, uCode) = captureRet(proc (): int =
      doGerminate("dance", "some-seed", projectDir = tmpDir)
    )
    check uCode != 0
    check uOut.contains("Unknown germinate action")

    # Non-existent seed rejection
    let (nOut, nCode) = captureRet(proc (): int =
      doGerminate("status", "non-existent-seed", projectDir = tmpDir)
    )
    check nCode != 0
    check nOut.contains("Seed not found")

    # Non-existent seed rejection with --json
    let (njOut, njCode) = captureRet(proc (): int =
      doGerminate("status", "non-existent-seed", projectDir = tmpDir, jsonOutput = true)
    )
    check njCode != 0
    let nj = parseJson(njOut.strip())
    check nj["status"].getStr() == "error"
    check nj["error"].getStr().contains("Seed not found")
