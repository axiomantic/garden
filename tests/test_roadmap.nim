# tests/test_roadmap.nim
# Unit and integration tests for Garden Roadmap and Procedural Persona Generation.

import std/[unittest, os, osproc, strutils, json]
import ../src/[seed, roadmap, garden]

suite "Garden Roadmap & Procedural Persona Suite":

  setup:
    let testDir = getTempDir() / "garden_roadmap_test_" & $getCurrentProcessId()
    createDir(testDir)
    createDir(testDir / ".garden" / "seeds")

  teardown:
    try:
      removeDir(testDir)
    except CatchableError:
      discard

  test "Procedural persona generation generates dynamic non-human monikers":
    var generated: seq[string] = @[]
    for i in 1 .. 20:
      let arch = pickWhimsicalPersona("architect", "test-project-" & $i)
      let audit = pickWhimsicalPersona("auditor", "test-project-" & $i)
      let impl = pickWhimsicalPersona("implementer", "test-project-" & $i)
      
      check arch.contains("-")
      check audit.contains("-")
      check impl.contains("-")

      # Invariant: Must not be static single names or human names
      check arch notin ["Marcus Vance", "Elena Rostova", "Caleb Thorne", "Bramblestitch"]
      check audit notin ["Marcus Vance", "Elena Rostova", "Caleb Thorne", "Prickle-Thistle"]
      check impl notin ["Marcus Vance", "Elena Rostova", "Caleb Thorne", "Moss-Weaver"]

      generated.add(arch)
      generated.add(audit)
      generated.add(impl)

    # Check high diversity across 60 generated names
    var uniqueSet: seq[string] = @[]
    for g in generated:
      if g notin uniqueSet: uniqueSet.add(g)
    check uniqueSet.len > 10

  test "Build roadmap groups seeds by season and computes metrics":
    var s1 = plantSeed("Task Alpha", testDir, season = "v1.0", tags = @["core"])
    var s2 = plantSeed("Task Beta", testDir, season = "v1.0", tags = @["api"])
    s2.status = "WOVEN"
    discard saveSeed(s2, testDir)

    var s3 = plantSeed("Task Gamma", testDir, season = "v2.0", tags = @["ui"])

    let rm = buildRoadmap(testDir)
    check rm.project.len > 0
    check rm.seasons.len == 2

    # Season v1.0 has 1 completed out of 2 (50%)
    var v1Found = false
    for s in rm.seasons:
      if s.name == "v1.0":
        v1Found = true
        check s.total == 2
        check s.completed == 1
        check s.pct == 50
    check v1Found

  test "Roadmap outputs structured JSON and re-entrant Markdown with checkboxes":
    var s1 = plantSeed("Feature One", testDir, season = "v1.0", tags = @["backend"])
    s1.status = "WOVEN"
    discard saveSeed(s1, testDir)

    var s2 = plantSeed("Feature Two", testDir, season = "v1.0", tags = @["frontend"])

    let rm = buildRoadmap(testDir)
    let j = rm.toJson()
    check j.hasKey("project")
    check j.hasKey("seasons")
    check j["seasons"].len == 1

    let md = rm.toMarkdown()
    check md.contains("# Project Roadmap:")
    check md.contains("## Season: v1.0 (50% Complete")
    check md.contains("- [x] **[WOVEN]** Feature One")
    check md.contains("- [ ] **[SOWN]** Feature Two")
    check md.contains("## Milestone & Version History")
    check md.contains("Feature One")

  test "saveRoadmap writes ROADMAP.md directly without JSON caching":
    var s1 = plantSeed("Feature Stored", testDir, season = "spring")
    let rm = buildRoadmap(testDir)
    let (jPath, mPath) = saveRoadmap(rm, testDir, writeMarkdown = true)

    check jPath.len == 0
    check not fileExists(testDir / ".garden" / "roadmap.json")
    check fileExists(mPath)
    check fileExists(testDir / "ROADMAP.md")
    let mdContent = readFile(mPath)
    check mdContent.contains("Feature Stored")

  test "Negative controls: corrupted TOML seeds recovery":
    # 1. Plant a valid seed
    let validSeed = plantSeed("Valid Task", testDir, season = "v1.0")
    
    # 2. Plant a corrupt TOML seed file
    let corruptFile = testDir / ".garden" / "seeds" / "corrupt-seed.toml"
    writeFile(corruptFile, "THIS IS TOTAL GARBAGE == NOT TOML {[[[[")

    # 3. buildRoadmap must recover gracefully and still include valid seed with zero JSON caching
    let rm = buildRoadmap(testDir)
    check rm.seasons.len >= 1
    var foundValid = false
    for s in rm.seasons:
      for it in s.items:
        if it.id == validSeed.id:
          foundValid = true
    check foundValid
    check not fileExists(testDir / ".garden" / "roadmap.json")

    # 4. Serialization of recovered roadmap must succeed
    let j = rm.toJson()
    check j.hasKey("project")
    let md = rm.toMarkdown()
    check md.contains("Valid Task")
