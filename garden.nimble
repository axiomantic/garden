# Package
version       = "0.2.11"
author        = "Axiomantic"
description   = "Multi-Agent Swarm Orchestration, Empirical Dialectics & Ceremonies on top of Rhizo & Vine"
license       = "MIT"
srcDir        = "src"
bin           = @["garden"]
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"

task test, "Run the Garden test suite":
  exec "nim r tests/test_garden.nim"

after build:
  when defined(macosx) or defined(darwin):
    echo "[BUILD] Ad-hoc codesigning binary on macOS to prevent AMFI SIGKILL..."
    exec "codesign -s - -f bin/garden"
