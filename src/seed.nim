# /Users/eek/Development/garden/src/seed.nim
# Botanical Task & Roadmap Seed Sowing Module.

import std/[os, strutils, json, times, algorithm]

type
  SunlightLevel* = enum
    slLow = "low"
    slMedium = "medium"
    slHigh = "high"
    slBlazing = "blazing"

  SeedStatus* = enum
    ssSown = "SOWN"
    ssGerminated = "GERMINATED"
    ssSprouted = "SPROUTED"
    ssBloomed = "BLOOMED"
    ssHarvested = "HARVESTED"

  Seed* = object
    id*: string
    title*: string
    season*: string
    sunlight*: string
    tags*: seq[string]
    status*: string
    createdAt*: string
    updatedAt*: string
    filePath*: string

proc isValidSunlight*(s: string): bool =
  let norm = s.toLowerAscii().strip()
  norm in ["low", "medium", "high", "blazing"]

proc normalizeSunlight*(s: string): string =
  let norm = s.toLowerAscii().strip()
  if isValidSunlight(norm):
    return norm
  return "medium"

proc slugify*(s: string): string =
  var res = ""
  for c in s.toLowerAscii():
    if c in {'a'..'z', '0'..'9'}:
      res.add(c)
    elif c in {' ', '-', '_', '.', '/', '\\', ':', ';', ',', '!', '?'}:
      if res.len > 0 and res[^1] != '-':
        res.add('-')
  while res.endsWith("-"):
    res = res[0..^2]
  while res.startsWith("-"):
    res = res[1..^1]
  if res.len == 0:
    res = "seed"
  return res

proc findProjectRoot*(startDir: string = ""): string =
  let envDir = getEnv("GARDEN_PROJECT_DIR", "")
  if envDir.len > 0 and dirExists(envDir):
    return envDir.normalizedPath
  var dir = if startDir.len > 0: startDir else: getCurrentDir()
  while dir.len > 0:
    let envCfg = getEnv("GARDEN_CONFIG", "")
    if (envCfg.len > 0 and fileExists(envCfg)) or
       fileExists(dir / "garden.toml") or 
       fileExists(dir / "garden-swarm.json") or 
       dirExists(dir / ".git") or
       fileExists(dir / ".git"):
      return dir
    let parent = dir.parentDir()
    if parent == dir:
      break
    dir = parent
  return if startDir.len > 0: startDir else: getCurrentDir()

proc getSeedsDir*(projectRoot: string = ""): string =
  let root = if projectRoot.len > 0: projectRoot else: findProjectRoot()
  result = root / ".garden" / "seeds"

proc seedFilePath*(seedId: string, projectRoot: string = ""): string =
  let sDir = getSeedsDir(projectRoot)
  result = sDir / (seedId & ".toml")

proc escapeTomlString(s: string): string =
  result = "\""
  for c in s:
    case c
    of '\\': result.add("\\\\")
    of '"': result.add("\\\"")
    of '\n': result.add("\\n")
    of '\r': result.add("\\r")
    of '\t': result.add("\\t")
    else: result.add(c)
  result.add("\"")

proc unescapeTomlString(s: string): string =
  var str = s.strip()
  if str.startsWith("\"") and str.endsWith("\"") and str.len >= 2:
    str = str[1..^2]
  var res = ""
  var i = 0
  while i < str.len:
    if str[i] == '\\' and i + 1 < str.len:
      inc i
      case str[i]
      of '\\': res.add('\\')
      of '"': res.add('"')
      of 'n': res.add('\n')
      of 'r': res.add('\r')
      of 't': res.add('\t')
      else: res.add(str[i])
    else:
      res.add(str[i])
    inc i
  return res

proc toToml*(s: Seed): string =
  result = "id = " & escapeTomlString(s.id) & "\n"
  result &= "title = " & escapeTomlString(s.title) & "\n"
  result &= "season = " & escapeTomlString(s.season) & "\n"
  result &= "sunlight = " & escapeTomlString(s.sunlight) & "\n"
  var tagStrs: seq[string] = @[]
  for t in s.tags:
    tagStrs.add(escapeTomlString(t))
  result &= "tags = [" & tagStrs.join(", ") & "]\n"
  result &= "status = " & escapeTomlString(s.status) & "\n"
  result &= "created_at = " & escapeTomlString(s.createdAt) & "\n"
  result &= "updated_at = " & escapeTomlString(s.updatedAt) & "\n"

proc parseTomlSeed*(content: string, filePath: string = ""): Seed =
  result.status = "SOWN"
  result.season = "spring"
  result.sunlight = "medium"
  result.tags = @[]
  result.filePath = filePath

  for rawLine in content.splitLines():
    let line = rawLine.strip()
    if line.len == 0 or line.startsWith("#"):
      continue
    let eqIdx = line.find('=')
    if eqIdx < 0:
      continue
    let key = line[0 ..< eqIdx].strip().toLowerAscii()
    let val = line[eqIdx + 1 .. ^1].strip()

    case key
    of "id":
      result.id = unescapeTomlString(val)
    of "title":
      result.title = unescapeTomlString(val)
    of "season":
      result.season = unescapeTomlString(val)
    of "sunlight":
      result.sunlight = normalizeSunlight(unescapeTomlString(val))
    of "status":
      result.status = unescapeTomlString(val)
    of "created_at":
      result.createdAt = unescapeTomlString(val)
    of "updated_at":
      result.updatedAt = unescapeTomlString(val)
    of "tags":
      var rawTags = val
      if rawTags.startsWith("[") and rawTags.endsWith("]"):
        rawTags = rawTags[1..^2].strip()
      result.tags = @[]
      if rawTags.len > 0:
        for t in rawTags.split(','):
          let clean = unescapeTomlString(t.strip())
          if clean.len > 0:
            result.tags.add(clean)
    else:
      discard

  if result.id.len == 0 and result.title.len > 0:
    result.id = slugify(result.title)

proc toJson*(s: Seed): JsonNode =
  result = newJObject()
  result["id"] = %s.id
  result["title"] = %s.title
  result["season"] = %s.season
  result["sunlight"] = %s.sunlight
  var jTags = newJArray()
  for t in s.tags:
    jTags.add(%t)
  result["tags"] = jTags
  result["status"] = %s.status
  result["created_at"] = %s.createdAt
  result["updated_at"] = %s.updatedAt
  if s.filePath.len > 0:
    result["path"] = %s.filePath

proc parseJsonSeed*(node: JsonNode): Seed =
  result.id = if node.hasKey("id"): node["id"].getStr() else: ""
  result.title = if node.hasKey("title"): node["title"].getStr() else: ""
  result.season = if node.hasKey("season"): node["season"].getStr("spring") else: "spring"
  result.sunlight = if node.hasKey("sunlight"): normalizeSunlight(node["sunlight"].getStr("medium")) else: "medium"
  result.status = if node.hasKey("status"): node["status"].getStr("SOWN") else: "SOWN"
  result.createdAt = if node.hasKey("created_at"): node["created_at"].getStr() else: ""
  result.updatedAt = if node.hasKey("updated_at"): node["updated_at"].getStr() else: ""
  result.filePath = if node.hasKey("path"): node["path"].getStr() else: ""
  result.tags = @[]
  if node.hasKey("tags") and node["tags"].kind == JArray:
    for t in node["tags"]:
      result.tags.add(t.getStr())

proc saveSeed*(s: var Seed, projectRoot: string = ""): string =
  if s.title.strip().len == 0:
    raise newException(ValueError, "Seed title cannot be empty")
  if not isValidSunlight(s.sunlight):
    raise newException(ValueError, "Invalid sunlight level: '" & s.sunlight & "'. Valid levels: low, medium, high, blazing")
  
  if s.id.len == 0:
    s.id = slugify(s.title)
  if s.status.len == 0:
    s.status = "SOWN"
  if s.season.len == 0:
    s.season = "spring"
  if s.sunlight.len == 0:
    s.sunlight = "medium"
  else:
    s.sunlight = normalizeSunlight(s.sunlight)

  let nowIso = now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  if s.createdAt.len == 0:
    s.createdAt = nowIso
  s.updatedAt = nowIso

  let sDir = getSeedsDir(projectRoot)
  createDir(sDir)
  let dest = sDir / (s.id & ".toml")
  s.filePath = dest
  let tomlContent = toToml(s)
  writeFile(dest, tomlContent)
  return dest

proc plantSeed*(
  title: string,
  projectRoot: string = "",
  season: string = "spring",
  sunlight: string = "medium",
  tags: seq[string] = @[],
  customId: string = ""
): Seed =
  let cleanTitle = title.strip()
  if cleanTitle.len == 0:
    raise newException(ValueError, "Cannot plant seed with empty title")
  
  let normSunlight = sunlight.toLowerAscii().strip()
  if not isValidSunlight(normSunlight):
    raise newException(ValueError, "Invalid sunlight level: '" & sunlight & "'. Valid levels: low, medium, high, blazing")

  let seedId = if customId.len > 0: customId.strip() else: slugify(cleanTitle)
  
  var seed = Seed(
    id: seedId,
    title: cleanTitle,
    season: if season.len > 0: season.strip() else: "spring",
    sunlight: normSunlight,
    tags: tags,
    status: "SOWN"
  )
  discard saveSeed(seed, projectRoot)
  return seed

proc loadSeed*(seedIdentifier: string, projectRoot: string = ""): Seed =
  let cleanId = seedIdentifier.strip()
  if cleanId.len == 0:
    raise newException(ValueError, "Seed identifier cannot be empty")

  # 1. Direct path check
  if fileExists(cleanId):
    let content = readFile(cleanId)
    return parseTomlSeed(content, cleanId)

  let sDir = getSeedsDir(projectRoot)
  
  # 2. Check sDir / <cleanId>
  if fileExists(sDir / cleanId):
    let p = sDir / cleanId
    return parseTomlSeed(readFile(p), p)

  # 3. Check sDir / (<cleanId> & ".toml")
  let targetFile = sDir / (cleanId & ".toml")
  if fileExists(targetFile):
    return parseTomlSeed(readFile(targetFile), targetFile)

  # 4. Check if prefixed with "seed-"
  if not cleanId.startsWith("seed-"):
    let prefFile = sDir / ("seed-" & cleanId & ".toml")
    if fileExists(prefFile):
      return parseTomlSeed(readFile(prefFile), prefFile)
  else:
    let stripFile = sDir / (cleanId[5..^1] & ".toml")
    if fileExists(stripFile):
      return parseTomlSeed(readFile(stripFile), stripFile)

  raise newException(IOError, "Seed not found: '" & cleanId & "' in " & sDir)

proc listSeeds*(projectRoot: string = ""): seq[Seed] =
  result = @[]
  let sDir = getSeedsDir(projectRoot)
  if not dirExists(sDir):
    return result
  for kind, path in walkDir(sDir):
    if kind in {pcFile, pcLinkToFile} and path.endsWith(".toml"):
      try:
        let content = readFile(path)
        let s = parseTomlSeed(content, path)
        result.add(s)
      except CatchableError:
        discard
  result.sort(proc(a, b: Seed): int =
    cmp(a.createdAt, b.createdAt)
  )
