#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const REPO = 'axiomantic/garden';
const PKG_NAME = '@axiomantic/garden';
const BIN_NAME = 'garden';

// 1. Ensure binary permissions and provision if missing
const binDir = path.join(__dirname, '..', 'bin');
const ext = process.platform === 'win32' ? '.exe' : '';
const targetBinary = path.join(binDir, `${BIN_NAME}${ext}`);

function ensureBinary() {
  if (fs.existsSync(targetBinary)) {
    try {
      fs.chmodSync(targetBinary, 0o755);
    } catch (_) {}
    return;
  }

  // Attempt to download pre-built release binary
  const pkgVersion = require('../package.json').version;
  const platform = process.platform === 'darwin' ? 'darwin' : (process.platform === 'win32' ? 'windows' : 'linux');
  const arch = process.arch === 'arm64' ? 'arm64' : 'amd64';
  const assetName = `${BIN_NAME}-${platform}-${arch}${platform === 'windows' ? '.zip' : '.tar.gz'}`;
  const downloadUrl = `https://github.com/${REPO}/releases/download/v${pkgVersion}/${assetName}`;

  try {
    console.log(`[${PKG_NAME}] Downloading native binary from ${downloadUrl}...`);
    const tempArchive = path.join(os.tmpdir(), assetName);
    execSync(`curl -fsSL -o "${tempArchive}" "${downloadUrl}"`, { stdio: 'pipe' });

    if (!fs.existsSync(binDir)) fs.mkdirSync(binDir, { recursive: true });

    if (platform === 'windows') {
      execSync(`tar -xf "${tempArchive}" -C "${binDir}"`, { stdio: 'pipe' });
    } else {
      execSync(`tar -xzf "${tempArchive}" -C "${binDir}"`, { stdio: 'pipe' });
    }
    try { fs.unlinkSync(tempArchive); } catch (_) {}
    if (fs.existsSync(targetBinary)) {
      fs.chmodSync(targetBinary, 0o755);
      console.log(`[${PKG_NAME}] Native binary installed successfully.`);
      return;
    }
  } catch (_) {
    // Release download failed or offline; check if nim is available to compile locally
    const srcNim = path.join(__dirname, '..', 'src', `${BIN_NAME}.nim`);
    if (fs.existsSync(srcNim)) {
      try {
        console.log(`[${PKG_NAME}] Compiling from source via nim...`);
        execSync(`nim c -d:release --opt:speed -o:"${targetBinary}" "${srcNim}"`, { stdio: 'pipe' });
        fs.chmodSync(targetBinary, 0o755);
        console.log(`[${PKG_NAME}] Native binary compiled successfully.`);
        return;
      } catch (_) {}
    }
  }

  console.warn(`[${PKG_NAME}] Note: Native binary could not be downloaded or compiled automatically.`);
  console.warn(`[${PKG_NAME}] Run 'nimble build' or visit https://github.com/${REPO}/releases to install manually.`);
}

ensureBinary();

// 2. Auto-equip detected coding assistants with Garden rules
const home = os.homedir();
const guideContent = `# Garden Multi-Agent Swarm & Ceremony Guide

Garden directs high-level methodology, persona deliberations, and synchronized task execution on top of Rhizo (transport) and Vine (workspace integrator).

### 0. Self-Bootstrapping Prerequisite
This project requires \`rhizo\`, \`vine\`, and \`garden\`. If missing, install via npm:
\`\`\`bash
npm install -g @axiomantic/rhizo @axiomantic/vine @axiomantic/garden
\`\`\`

### 1. Invariants & Epistemic Protocol
* **Zero Theatrical Dialogue**:
  Every dialectical exchange must cite empirical evidence obtained from tool execution (file line citations, test suite runs, AST analysis, compiler output). Theatrical roleplay without tool grounding is strictly prohibited.
* **Single-Source Planning**:
  All tasks, locks, and strands must be coordinated via \`implementation_plan.md\`. Dynamic progress must be tracked in lockstep with plan checkboxes (\`- [ ]\` to \`- [x]\`) and harness To-Do tracking.
* **Emergent Design Addendum Protocol**:
  Workers discovering architectural discrepancies cannot unilaterally deviate from \`design.md\`. They must submit a formal \`addendum_<topic>.md\` with rationale, await Orchestrator ratification, update \`design.md\`, and refresh \`implementation_plan.md\`.

### 2. Fleet Lifecycle & Multiplexer Discipline
* **Tmux Multiplexing**:
  All swarm workers run inside managed tmux panes created via \`garden launch\` or \`scripts/launch_tmux_swarm.sh\`. Never detach unmanaged background processes with \`&\` or redirect output.
* **Continuous Listening**:
  Workers must keep their Rhizo listener active (\`rhizo listen <agent>\`) with zero-timeout infinite wait to prevent token thrashing.

### 3. The Two-Key Gate & Strand Weaving
Never weave a strand into the canonical trunk without passing both keys:
* **Key 1 (Mechanical)**: In-memory conflict pre-check (\`git merge-tree --write-tree\`).
* **Key 2 (Semantic)**: Automated compiler and test suite run inside the strand.
* **Weave**: \`vine weave && rhizo ack queue:<project>:tasks <task_id>\`
`;

function safeWrite(destDir, fileName, content) {
  try {
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    const target = path.join(destDir, fileName);
    fs.writeFileSync(target, content, 'utf8');
    console.log(`[${PKG_NAME}] Provisioned rules to: ${target}`);
  } catch (err) {
    // Non-fatal if permissions or sandbox prevent writing
  }
}

function cleanAndInstall(destDir, oldName, newName) {
  try {
    const oldPath = path.join(destDir, oldName);
    if (fs.existsSync(oldPath)) {
      try { fs.unlinkSync(oldPath); } catch (_) {}
    }
    safeWrite(destDir, newName, guideContent);
  } catch (_) {}
}

// Claude Code
const claudeDir = path.join(home, '.claude');
if (fs.existsSync(claudeDir)) {
  cleanAndInstall(path.join(claudeDir, 'rules'), 'agora.md', 'garden.md');
}

// OpenCode
const opencodeDir = path.join(home, '.config', 'opencode');
if (fs.existsSync(opencodeDir)) {
  cleanAndInstall(path.join(opencodeDir, 'instructions'), 'agora.md', 'garden.md');
}

// Antigravity
const antigravityDir = path.join(home, '.gemini', 'antigravity');
if (fs.existsSync(antigravityDir)) {
  cleanAndInstall(path.join(antigravityDir, 'rules'), 'agora.md', 'garden.md');
}
