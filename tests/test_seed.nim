# tests/test_seed.nim
# Full test coverage for Garden seed data model, TOML storage, CLI plant consumer, and negative controls.

import std/[os, osproc, strutils, json, unittest]
import ../src/seed

suite "Garden Botanical Seed Data Model & Persistence Suite":

  test "Seed schema creation with default attributes":
    let tmpDir = getTempDir() / ("garden_seed_test_defaults_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed("Botanical Core Pipeline", projectRoot = tmpDir)
    check s.title == "Botanical Core Pipeline"
    check s.id == "botanical-core-pipeline"
    check s.season == "spring"
    check s.sunlight == "medium"
    check s.status == "SOWN"
    check s.tags.len == 0
    check s.createdAt.len > 0
    check s.updatedAt.len > 0
    check s.filePath == tmpDir / ".garden" / "seeds" / "botanical-core-pipeline.toml"
    check fileExists(s.filePath)

  test "Seed custom attributes, tags, and explicit ID":
    let tmpDir = getTempDir() / ("garden_seed_test_custom_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let s = plantSeed(
      title = "P2P Task Gossip",
      projectRoot = tmpDir,
      season = "autumn",
      sunlight = "blazing",
      tags = @["p2p", "gossip", "rhizo"],
      customId = "custom-gossip-seed"
    )
    check s.title == "P2P Task Gossip"
    check s.id == "custom-gossip-seed"
    check s.season == "autumn"
    check s.sunlight == "blazing"
    check s.status == "SOWN"
    check s.tags == @["p2p", "gossip", "rhizo"]
    check fileExists(tmpDir / ".garden" / "seeds" / "custom-gossip-seed.toml")

  test "TOML serialization and deserialization round-trip":
    let orig = Seed(
      id: "auth-gateway",
      title: "Authentication Gateway & Tokens",
      season: "winter",
      sunlight: "high",
      tags: @["auth", "tokens", "security"],
      status: "SOWN",
      createdAt: "2026-10-15T20:00:00Z",
      updatedAt: "2026-10-15T21:00:00Z",
      filePath: "/tmp/auth-gateway.toml"
    )
    let tomlStr = toToml(orig)
    check tomlStr.contains("id = \"auth-gateway\"")
    check tomlStr.contains("title = \"Authentication Gateway & Tokens\"")
    check tomlStr.contains("season = \"winter\"")
    check tomlStr.contains("sunlight = \"high\"")
    check tomlStr.contains("status = \"SOWN\"")
    check tomlStr.contains("tags = [\"auth\", \"tokens\", \"security\"]")

    let parsed = parseTomlSeed(tomlStr, "/tmp/auth-gateway.toml")
    check parsed.id == orig.id
    check parsed.title == orig.title
    check parsed.season == orig.season
    check parsed.sunlight == orig.sunlight
    check parsed.status == orig.status
    check parsed.tags == orig.tags
    check parsed.createdAt == orig.createdAt
    check parsed.updatedAt == orig.updatedAt

  test "JSON serialization and deserialization":
    let orig = Seed(
      id: "json-seed",
      title: "JSON Output Seed",
      season: "summer",
      sunlight: "low",
      tags: @["json", "api"],
      status: "SOWN",
      createdAt: "2026-10-15T12:00:00Z",
      updatedAt: "2026-10-15T12:00:00Z",
      filePath: "/tmp/json-seed.toml"
    )
    let j = orig.toJson()
    check j["id"].getStr() == "json-seed"
    check j["title"].getStr() == "JSON Output Seed"
    check j["season"].getStr() == "summer"
    check j["sunlight"].getStr() == "low"
    check j["status"].getStr() == "SOWN"
    check j["tags"].len == 2
    check j["tags"][0].getStr() == "json"
    check j["tags"][1].getStr() == "api"
    check j["path"].getStr() == "/tmp/json-seed.toml"

    let fromJ = parseJsonSeed(j)
    check fromJ.id == orig.id
    check fromJ.title == orig.title
    check fromJ.season == orig.season
    check fromJ.sunlight == orig.sunlight
    check fromJ.tags == orig.tags

  test "Seed listing and loading across project root":
    let tmpDir = getTempDir() / ("garden_seed_test_list_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    check listSeeds(tmpDir).len == 0

    discard plantSeed("Seed Alpha", projectRoot = tmpDir, tags = @["a"])
    discard plantSeed("Seed Beta", projectRoot = tmpDir, tags = @["b"])
    discard plantSeed("Seed Gamma", projectRoot = tmpDir, tags = @["c"])

    let seeds = listSeeds(tmpDir)
    check seeds.len == 3
    var ids: seq[string] = @[]
    for s in seeds: ids.add(s.id)
    check "seed-alpha" in ids
    check "seed-beta" in ids
    check "seed-gamma" in ids

    # Test loadSeed via id, via file, and via seed- prefixed ID
    let loaded1 = loadSeed("seed-alpha", tmpDir)
    check loaded1.title == "Seed Alpha"
    let loaded2 = loadSeed(tmpDir / ".garden" / "seeds" / "seed-beta.toml", tmpDir)
    check loaded2.title == "Seed Beta"

  test "Negative controls: empty title, invalid sunlight, and missing seed loading":
    let tmpDir = getTempDir() / ("garden_seed_test_neg_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    expect(ValueError):
      discard plantSeed("", projectRoot = tmpDir)

    expect(ValueError):
      discard plantSeed("Valid Title", projectRoot = tmpDir, sunlight = "ultra-violet")

    expect(ValueError):
      discard plantSeed("Valid Title", projectRoot = tmpDir, sunlight = "darkness")

    expect(IOError):
      discard loadSeed("non-existent-seed-id", tmpDir)

    expect(ValueError):
      discard loadSeed("", tmpDir)

suite "Garden CLI 'garden plant' Integration & Consumer Suite":

  test "CLI garden plant creates seed file and outputs formatted report":
    let tmpDir = getTempDir() / ("garden_cli_plant_text_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let cmd = exePath & " plant \"Roadmap Telemetry\" --season summer --sunlight high --tags \"telemetry,metrics\" -p " & quoteShell(tmpDir)
    let (pOut, pCode) = execCmdEx(cmd)
    check pCode == 0
    check pOut.contains("Sowed seed 'Roadmap Telemetry'")
    check pOut.contains("Status:   SOWN")
    check pOut.contains("Season:   summer")
    check pOut.contains("Sunlight: high")
    check pOut.contains("Tags:     telemetry, metrics")

    let expectedFile = tmpDir / ".garden" / "seeds" / "roadmap-telemetry.toml"
    check fileExists(expectedFile)

  test "CLI garden plant --json outputs structured json":
    let tmpDir = getTempDir() / ("garden_cli_plant_json_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    let cmd = exePath & " plant \"Kernel Dispatcher\" --season winter --sunlight blazing --tags \"kernel,core\" --json -p " & quoteShell(tmpDir)
    let (jOut, jCode) = execCmdEx(cmd)
    check jCode == 0

    let j = parseJson(jOut.strip())
    check j["id"].getStr() == "kernel-dispatcher"
    check j["title"].getStr() == "Kernel Dispatcher"
    check j["season"].getStr() == "winter"
    check j["sunlight"].getStr() == "blazing"
    check j["status"].getStr() == "SOWN"
    check j["tags"].len == 2
    check j["tags"][0].getStr() == "kernel"
    check j["tags"][1].getStr() == "core"
    check fileExists(j["path"].getStr())

  test "CLI garden plant --list displays formatted and JSON seed rosters":
    let tmpDir = getTempDir() / ("garden_cli_plant_list_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"
    
    # 1. Empty list
    let (eOut, eCode) = execCmdEx(exePath & " plant --list -p " & quoteShell(tmpDir))
    check eCode == 0
    check eOut.contains("No seeds sown yet")

    # 2. Plant two seeds
    discard execCmdEx(exePath & " plant \"Seed One\" -p " & quoteShell(tmpDir))
    discard execCmdEx(exePath & " plant \"Seed Two\" -p " & quoteShell(tmpDir))

    # 3. Formatted list
    let (lOut, lCode) = execCmdEx(exePath & " plant --list -p " & quoteShell(tmpDir))
    check lCode == 0
    check lOut.contains("Garden Sown Seeds (2)")
    check lOut.contains("Seed One")
    check lOut.contains("Seed Two")

    # 4. JSON list
    let (jlOut, jlCode) = execCmdEx(exePath & " plant --list --json -p " & quoteShell(tmpDir))
    check jlCode == 0
    let jl = parseJson(jlOut.strip())
    check jl.kind == JArray
    check jl.len == 2

  test "CLI negative controls: missing title, invalid sunlight":
    let tmpDir = getTempDir() / ("garden_cli_plant_err_" & $getCurrentProcessId())
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let exePath = if defined(windows): "bin" / "garden.exe" else: "bin" / "garden"

    # Missing title
    let (mOut, mCode) = execCmdEx(exePath & " plant")
    check mCode != 0
    check mOut.contains("Usage: garden plant")

    # Invalid sunlight
    let (sOut, sCode) = execCmdEx(exePath & " plant \"Invalid Sun\" --sunlight radioactive -p " & quoteShell(tmpDir))
    check sCode != 0
    check sOut.contains("Invalid sunlight level 'radioactive'")
