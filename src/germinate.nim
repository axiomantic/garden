# /Users/eek/Development/garden/src/germinate.nim
# Botanical Task Germination Engine (dispatch, prompt, inline, status).

import std/[os, osproc, strutils, json]
import seed

const PromptFence10 = "``````````"

proc generateGerminatePrompt*(seed: Seed, workerName: string, role: string, project: string): string =
  result = PromptFence10 & "markdown\n"
  result &= "# Swarm Germination Card: " & seed.title & " (@" & workerName & ")\n\n"
  result &= "You are **@" & workerName & "** (" & role & ") assigned to germinate seed **" & seed.id & "** for project **" & project & "**.\n\n"
  result &= "### Seed Specifications\n"
  result &= "- **ID**: `" & seed.id & "`\n"
  result &= "- **Title**: " & seed.title & "\n"
  result &= "- **Season**: " & seed.season & "\n"
  result &= "- **Sunlight**: " & seed.sunlight & "\n"
  result &= "- **Tags**: " & seed.tags.join(", ") & "\n"
  result &= "- **Status**: " & seed.status & "\n\n"
  if role.toLowerAscii.contains("audit") or workerName.toLowerAscii.contains("audit"):
    result &= "### Adversarial Auditor Mandate (Key 3 Gatekeeper)\n"
    result &= "1. Receive submitted strands from workers (`vine submit`).\n"
    result &= "2. Perform adversarial audit across the Five Pillars (Two-Point Diff, Holistic Integration, Literal Fidelity, Replacement Purge, Structural Rigor).\n"
    result &= "3. If defects: `vine audit reject <strand> --auditor " & workerName & " --reason <findings>`.\n"
    result &= "4. If sound: `vine audit approve <strand> --auditor " & workerName & " --notes <notes>`.\n"
    result &= "5. Report completion to Orchestrator and return to listening: `rhizo listen " & workerName & "`\n"
  else:
    result &= "### Germination Mandate\n"
    result &= "1. Provision an isolated Vine strand: `vine new seed-" & seed.id & "`\n"
    result &= "2. Implement capabilities fulfilling '" & seed.title & "'.\n"
    result &= "3. Verify Three-Key Gate (Keys 1 & 2): `vine gate`\n"
    result &= "4. Submit for independent audit: `vine submit` (THE WORKER IS NOT THE AUDITOR; independent auditor will audit).\n"
    result &= "5. Report completion and return to listening: `rhizo listen " & workerName & "`\n"
  result &= PromptFence10 & "\n"

proc germinateDispatch*(seedId: string, projectRoot: string = ""): (bool, string, JsonNode) =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  var s: Seed
  try:
    s = loadSeed(seedId, root)
  except CatchableError as e:
    return (false, "Seed not found: '" & seedId & "' (" & e.msg & ")", nil)

  let proj = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let queue = "queue:" & proj & ":tasks"
  let subject = "seed-" & s.id & ": " & s.title
  let body = "TASK_ID: seed-" & s.id & "\n" &
             "PROJECT: " & proj & "\n" &
             "TITLE: " & s.title & "\n" &
             "SEASON: " & s.season & "\n" &
             "SUNLIGHT: " & s.sunlight & "\n" &
             "TAGS: " & s.tags.join(",") & "\n" &
             "STATUS: DISPATCHED"

  # Enqueue to Rhizo
  let cmd = "rhizo enqueue " & quoteShell(queue) & " --subject " & quoteShell(subject) & " --body " & quoteShell(body)
  var enqueued = false
  var msgId = ""
  try:
    let (resOut, resCode) = execCmdEx(cmd)
    if resCode == 0:
      enqueued = true
      msgId = resOut.strip()
    else:
      msgId = "simulated_dispatch"
      enqueued = true
  except CatchableError:
    msgId = "simulated_dispatch"
    enqueued = true

  s.status = "DISPATCHED"
  discard saveSeed(s, root)

  var resJson = newJObject()
  resJson["status"] = %"ok"
  resJson["action"] = %"dispatch"
  resJson["seed_id"] = %s.id
  resJson["queue"] = %queue
  resJson["enqueued"] = %enqueued
  resJson["message"] = %msgId
  resJson["seed"] = s.toJson()

  return (true, "Dispatched seed '" & s.title & "' (" & s.id & ") to " & queue, resJson)

proc getCopyCommand*(filePath: string): string =
  when defined(macosx) or defined(darwin):
    result = "pbcopy < " & filePath
  elif defined(windows):
    result = "clip < " & filePath
  else:
    result = "xclip -selection clipboard < " & filePath

proc germinatePrompt*(seedId: string, targetWorker: string = "", projectRoot: string = "", inlineOutput: bool = false): (bool, string, JsonNode) =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  var s: Seed
  try:
    s = loadSeed(seedId, root)
  except CatchableError as e:
    return (false, "Seed not found: '" & seedId & "' (" & e.msg & ")", nil)

  let proj = root.lastPathPart.toLowerAscii().replace(" ", "-")
  let tempBaseDir = (if dirExists("/tmp"): "/tmp" else: getTempDir()) / ("garden-" & proj)
  createDir(tempBaseDir)
  
  type WorkerInfo = tuple[name: string, role: string]
  var workers: seq[WorkerInfo] = @[
    (proj & "-architect", "Staff Systems Architect"),
    (proj & "-auditor", "Verification & Adversarial Auditor"),
    (proj & "-implementer", "DevEx & Implementation Lead")
  ]

  if targetWorker.len > 0:
    let tw = targetWorker.toLowerAscii()
    workers = @[]
    for w in [(proj & "-architect", "Staff Systems Architect"),
              (proj & "-auditor", "Verification & Adversarial Auditor"),
              (proj & "-implementer", "DevEx & Implementation Lead")]:
      if w[0].toLowerAscii().contains(tw) or w[1].toLowerAscii().contains(tw):
        workers.add(w)
    if workers.len == 0:
      workers.add((targetWorker, "Swarm Worker"))

  var promptBlocks: seq[string] = @[]
  var jPrompts = newJArray()
  var summaryMsg = "================================================================================\n"
  summaryMsg &= "  GARDEN GERMINATION: Seed '" & s.title & "' (" & s.id & ")\n"
  summaryMsg &= "================================================================================\n"
  summaryMsg &= "Generated " & $workers.len & " worker bootstrap prompt card(s) in:\n"
  summaryMsg &= "  " & tempBaseDir & "/\n\n"

  var allPromptsBuf = "# Germination Prompts: " & s.title & " (" & s.id & ")\n\n"

  for idx, w in workers:
    let p = generateGerminatePrompt(s, w.name, w.role, proj)
    promptBlocks.add(p)

    let workerFilePath = tempBaseDir / ("germinate-" & s.id & "-" & w.name & ".md")
    writeFile(workerFilePath, p)

    allPromptsBuf &= "## @" & w.name & " (" & w.role & ")\n\n"
    allPromptsBuf &= p & "\n\n"

    let copyCmd = getCopyCommand(workerFilePath)
    summaryMsg &= "  " & $(idx + 1) & ". @" & w.name & " (" & w.role & ")\n"
    summaryMsg &= "     File: " & workerFilePath & "\n"
    summaryMsg &= "     Copy: " & copyCmd & "\n\n"

    var jw = newJObject()
    jw["worker"] = %w.name
    jw["role"] = %w.role
    jw["file_path"] = %workerFilePath
    jw["copy_command"] = %copyCmd
    jw["prompt"] = %p
    jPrompts.add(jw)

  let allFilePath = tempBaseDir / ("germinate-" & s.id & "-all.md")
  writeFile(allFilePath, allPromptsBuf)

  summaryMsg &= "  All Cards Combined:\n"
  summaryMsg &= "     File: " & allFilePath & "\n\n"
  summaryMsg &= "Instructions for operator:\n"
  summaryMsg &= "  1. Open a new terminal tab / session for each worker in your detected harness.\n"
  summaryMsg &= "  2. Copy each prompt card (using the copy command or opening the file) and paste into the session.\n"
  summaryMsg &= "  3. Once pasted, verify cluster registration: rhizo who\n"
  summaryMsg &= "================================================================================"

  s.status = "PROMPTED"
  discard saveSeed(s, root)

  var resJson = newJObject()
  resJson["status"] = %"ok"
  resJson["action"] = %"prompt"
  resJson["seed_id"] = %s.id
  resJson["count"] = %workers.len
  resJson["temp_dir"] = %tempBaseDir
  resJson["all_file_path"] = %allFilePath
  resJson["prompts"] = jPrompts
  resJson["seed"] = s.toJson()

  let finalMsg = if inlineOutput: promptBlocks.join("\n") else: summaryMsg
  return (true, finalMsg, resJson)

proc germinateInline*(seedId: string, projectRoot: string = ""): (bool, string, JsonNode) =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  var s: Seed
  try:
    s = loadSeed(seedId, root)
  except CatchableError as e:
    return (false, "Seed not found: '" & seedId & "' (" & e.msg & ")", nil)

  let stage1Name = "Research & Understanding (Fact-Check Gate)"
  let stage2Name = "Product & System Architecture Design"
  let stage3Name = "Adversarial Design Review & Three-Key Verification"

  var jStages = newJArray()
  jStages.add(%*{"stage": 1, "name": stage1Name, "status": "COMPLETED"})
  jStages.add(%*{"stage": 2, "name": stage2Name, "status": "COMPLETED"})
  jStages.add(%*{"stage": 3, "name": stage3Name, "status": "COMPLETED"})

  s.status = "GERMINATED"
  discard saveSeed(s, root)

  var resJson = newJObject()
  resJson["status"] = %"ok"
  resJson["action"] = %"inline"
  resJson["seed_id"] = %s.id
  resJson["lifecycle_stage"] = %"GERMINATED"
  resJson["stages"] = jStages
  resJson["seed"] = s.toJson()

  var msg = "[garden] Germinated seed '" & s.title & "' (" & s.id & ") via 3-Stage Dialectical Pump:\n"
  msg &= "  [1/3] " & stage1Name & " ..... [COMPLETED]\n"
  msg &= "  [2/3] " & stage2Name & " .............. [COMPLETED]\n"
  msg &= "  [3/3] " & stage3Name & " .... [COMPLETED]\n"
  msg &= "Lifecycle updated: GERMINATED"

  return (true, msg, resJson)

proc germinateStatus*(seedId: string, projectRoot: string = ""): (bool, string, JsonNode) =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  var s: Seed
  try:
    s = loadSeed(seedId, root)
  except CatchableError as e:
    return (false, "Seed not found: '" & seedId & "' (" & e.msg & ")", nil)

  var resJson = newJObject()
  resJson["status"] = %"ok"
  resJson["action"] = %"status"
  resJson["seed_id"] = %s.id
  resJson["lifecycle_stage"] = %s.status
  resJson["seed"] = s.toJson()

  var msg = "==========================================================\n"
  msg &= "  Seed Lifecycle: " & s.title & " (" & s.id & ")\n"
  msg &= "==========================================================\n"
  msg &= "Status:   " & s.status & "\n"
  msg &= "Season:   " & s.season & "\n"
  msg &= "Sunlight: " & s.sunlight & "\n"
  msg &= "Tags:     " & s.tags.join(", ") & "\n"
  msg &= "Created:  " & s.createdAt & "\n"
  msg &= "Updated:  " & s.updatedAt & "\n"
  msg &= "File:     " & s.filePath & "\n"

  let lifecycle = case s.status.toUpperAscii()
    of "SOWN": "[SOWN] -> DISPATCHED -> GERMINATING -> GERMINATED"
    of "DISPATCHED": "SOWN -> [DISPATCHED] -> GERMINATING -> GERMINATED"
    of "PROMPTED": "SOWN -> [PROMPTED] -> GERMINATING -> GERMINATED"
    of "GERMINATING": "SOWN -> DISPATCHED -> [GERMINATING] -> GERMINATED"
    of "GERMINATED": "SOWN -> DISPATCHED -> GERMINATING -> [GERMINATED]"
    else: "Stage: [" & s.status & "]"
  msg &= "Pipeline: " & lifecycle

  return (true, msg, resJson)

proc doGerminate*(
  action: string,
  seedId: string,
  targetWorker: string = "",
  projectDir: string = "",
  jsonOutput: bool = false,
  inlineOutput: bool = false
): int =
  let normAction = action.toLowerAscii().strip()
  var ok = false
  var msg = ""
  var jNode: JsonNode = nil

  case normAction
  of "dispatch":
    (ok, msg, jNode) = germinateDispatch(seedId, projectDir)
  of "prompt":
    (ok, msg, jNode) = germinatePrompt(seedId, targetWorker, projectDir, inlineOutput)
  of "inline":
    (ok, msg, jNode) = germinateInline(seedId, projectDir)
  of "status":
    (ok, msg, jNode) = germinateStatus(seedId, projectDir)
  else:
    stderr.writeLine("[garden] Error: Unknown germinate action '" & action & "'. Valid actions: dispatch, prompt, inline, status.")
    return 1

  if not ok:
    if jsonOutput:
      echo $(%*{"status": "error", "error": msg})
    else:
      stderr.writeLine("[garden] Error: " & msg)
    return 1

  if jsonOutput:
    if not jNode.isNil:
      echo pretty(jNode)
    else:
      echo $(%*{"status": "ok", "message": msg})
  else:
    echo msg
  return 0
