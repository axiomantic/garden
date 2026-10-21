# /Users/eek/Development/garden/src/roadmap.nim
# Botanical Project Roadmap & Re-entrant Markdown Generator.

import std/[os, strutils, json, times, tables]
import seed

type
  RoadmapItem* = object
    id*: string
    title*: string
    season*: string
    sunlight*: string
    tags*: seq[string]
    status*: string
    createdAt*: string
    updatedAt*: string
    completedAt*: string
    strand*: string

  RoadmapSeason* = object
    name*: string
    total*: int
    completed*: int
    inProgress*: int
    planned*: int
    pct*: int
    items*: seq[RoadmapItem]

  Roadmap* = object
    project*: string
    generatedAt*: string
    seasons*: seq[RoadmapSeason]

proc isCompletedStatus*(status: string): bool =
  let s = status.toUpperAscii().strip()
  s in ["WOVEN", "HARVESTED", "BLOOMED", "COMPLETED", "DONE"]

proc isInProgressStatus*(status: string): bool =
  let s = status.toUpperAscii().strip()
  s in ["GERMINATING", "GERMINATED", "DISPATCHED", "PROMPTED", "IN_PROGRESS", "SPROUTED", "CLAIMED", "RUNNING"]

proc isPlannedStatus*(status: string): bool =
  let s = status.toUpperAscii().strip()
  s in ["SOWN", "PLANNED", "PENDING", "SEED"]

proc getRoadmapJsonPath*(projectRoot: string = ""): string =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  result = root / ".garden" / "roadmap.json"

proc getRoadmapMarkdownPath*(projectRoot: string = ""): string =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  result = root / "ROADMAP.md"

proc buildRoadmap*(projectRoot: string = "", filterSeason: string = ""): Roadmap =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  let proj = root.lastPathPart.toLowerAscii().replace(" ", "-")

  result.project = proj
  result.generatedAt = now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  result.seasons = @[]

  # 1. Collect all seeds from .garden/seeds/
  let seeds = listSeeds(root)
  var seasonsMap = initOrderedTable[string, seq[RoadmapItem]]()

  # 2. Check if .garden/roadmap.json has existing history not in seeds
  let jsonPath = getRoadmapJsonPath(root)
  var knownIds: seq[string] = @[]

  for s in seeds:
    knownIds.add(s.id)
    let itemSeason = if s.season.len > 0: s.season else: "backlog"
    if filterSeason.len > 0 and itemSeason.toLowerAscii() != filterSeason.toLowerAscii():
      continue

    var item = RoadmapItem(
      id: s.id,
      title: s.title,
      season: itemSeason,
      sunlight: s.sunlight,
      tags: s.tags,
      status: s.status,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      completedAt: if isCompletedStatus(s.status): s.updatedAt else: "",
      strand: ""
    )
    if not seasonsMap.hasKey(itemSeason):
      seasonsMap[itemSeason] = @[]
    seasonsMap[itemSeason].add(item)

  # Check existing roadmap.json for any historical/archived items
  if fileExists(jsonPath):
    try:
      let prevJson = parseJson(readFile(jsonPath))
      if prevJson.hasKey("seasons") and prevJson["seasons"].kind == JArray:
        for sj in prevJson["seasons"]:
          let sName = sj.getOrDefault("name").getStr("backlog")
          if filterSeason.len > 0 and sName.toLowerAscii() != filterSeason.toLowerAscii():
            continue
          if sj.hasKey("items") and sj["items"].kind == JArray:
            for ij in sj["items"]:
              let id = ij.getOrDefault("id").getStr("")
              if id.len > 0 and id notin knownIds:
                knownIds.add(id)
                var tags: seq[string] = @[]
                if ij.hasKey("tags") and ij["tags"].kind == JArray:
                  for t in ij["tags"]: tags.add(t.getStr())
                let histItem = RoadmapItem(
                  id: id,
                  title: ij.getOrDefault("title").getStr(id),
                  season: sName,
                  sunlight: ij.getOrDefault("sunlight").getStr("medium"),
                  tags: tags,
                  status: ij.getOrDefault("status").getStr("WOVEN"),
                  createdAt: ij.getOrDefault("created_at").getStr(""),
                  updatedAt: ij.getOrDefault("updated_at").getStr(""),
                  completedAt: ij.getOrDefault("completed_at").getStr(""),
                  strand: ij.getOrDefault("strand").getStr("")
                )
                if not seasonsMap.hasKey(sName):
                  seasonsMap[sName] = @[]
                seasonsMap[sName].add(histItem)
    except CatchableError:
      discard

  # 3. Assemble seasons with metrics
  for sName, items in seasonsMap:
    var comp = 0
    var inProg = 0
    var plan = 0
    for it in items:
      if isCompletedStatus(it.status): inc comp
      elif isInProgressStatus(it.status): inc inProg
      else: inc plan

    let total = items.len
    let pct = if total > 0: (comp * 100) div total else: 0
    result.seasons.add(RoadmapSeason(
      name: sName,
      total: total,
      completed: comp,
      inProgress: inProg,
      planned: plan,
      pct: pct,
      items: items
    ))

proc toJson*(r: Roadmap): JsonNode =
  result = newJObject()
  result["project"] = %r.project
  result["generated_at"] = %r.generatedAt
  var jSeasons = newJArray()
  for s in r.seasons:
    var sj = newJObject()
    sj["name"] = %s.name
    sj["total"] = %s.total
    sj["completed"] = %s.completed
    sj["in_progress"] = %s.inProgress
    sj["planned"] = %s.planned
    sj["percent_complete"] = %s.pct
    var jItems = newJArray()
    for it in s.items:
      var ij = newJObject()
      ij["id"] = %it.id
      ij["title"] = %it.title
      ij["season"] = %it.season
      ij["sunlight"] = %it.sunlight
      ij["status"] = %it.status
      ij["created_at"] = %it.createdAt
      ij["updated_at"] = %it.updatedAt
      ij["completed_at"] = %it.completedAt
      if it.strand.len > 0: ij["strand"] = %it.strand
      var jt = newJArray()
      for t in it.tags: jt.add(%t)
      ij["tags"] = jt
      jItems.add(ij)
    sj["items"] = jItems
    jSeasons.add(sj)
  result["seasons"] = jSeasons

proc toMarkdown*(r: Roadmap): string =
  var lines: seq[string] = @[]
  lines.add("# Project Roadmap: " & r.project)
  lines.add("")
  lines.add("> *Autogenerated from `.garden/seeds/` and `.garden/roadmap.json` via `garden roadmap`.*  ")
  lines.add("> *Last updated: " & r.generatedAt & "*")
  lines.add("")

  if r.seasons.len == 0:
    lines.add("No roadmap items found. Plant a new seed using `garden plant <title>`.")
    return lines.join("\n") & "\n"

  # Active Seasons
  for s in r.seasons:
    lines.add("## Season: " & s.name & " (" & $s.pct & "% Complete — " & $s.completed & "/" & $s.total & ")")
    lines.add("")
    if s.items.len == 0:
      lines.add("_No items in this season._")
      lines.add("")
      continue

    # Items in season
    for it in s.items:
      let check = if isCompletedStatus(it.status): "[x]" else: "[ ]"
      let statusBadge = "[" & it.status.toUpperAscii() & "]"
      var tagStr = ""
      if it.tags.len > 0:
        tagStr = " `tags:" & it.tags.join(",") & "`"
      var extra = ""
      if isCompletedStatus(it.status) and it.completedAt.len > 0:
        extra = " *(Completed: " & it.completedAt & ")*"
      lines.add("- " & check & " **" & statusBadge & "** " & it.title & " `[" & it.id & "]`" & tagStr & extra & " <!-- id:" & it.id & " status:" & it.status & " -->")
    lines.add("")

  # Milestone & Version History
  lines.add("---")
  lines.add("")
  lines.add("## Milestone & Version History")
  lines.add("")
  for s in r.seasons:
    var compItems: seq[RoadmapItem] = @[]
    for it in s.items:
      if isCompletedStatus(it.status):
        compItems.add(it)
    if compItems.len > 0:
      lines.add("### Season: " & s.name)
      for ci in compItems:
        let dateStr = if ci.completedAt.len > 0: " on " & ci.completedAt else: ""
        lines.add("- **" & ci.title & "** (`" & ci.id & "`)" & dateStr & (if ci.tags.len > 0: " | " & ci.tags.join(", ") else: ""))
      lines.add("")

  return lines.join("\n") & "\n"

proc saveRoadmap*(r: Roadmap, projectRoot: string = "", writeMarkdown: bool = false, markdownPath: string = ""): tuple[jsonPath, mdPath: string] =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  let gDir = root / ".garden"
  createDir(gDir)
  let jPath = gDir / "roadmap.json"
  writeFile(jPath, pretty(r.toJson()))
  result.jsonPath = jPath

  if writeMarkdown:
    let mPath = if markdownPath.len > 0: markdownPath else: getRoadmapMarkdownPath(root)
    writeFile(mPath, r.toMarkdown())
    result.mdPath = mPath
