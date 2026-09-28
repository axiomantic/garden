# Package
version       = "0.1.0"
author        = "Axiomantic"
description   = "Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies on top of Locu & Braid"
license       = "MIT"
srcDir        = "src"
bin           = @["agora"]
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"

task test, "Run the Agora test suite":
  exec "nim r tests/test_agora.nim"
