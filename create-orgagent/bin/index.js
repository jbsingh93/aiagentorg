#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const projectName = process.argv[2];

if (!projectName) {
  console.log(`
  Usage: npx create-orgagent <project-name>

  Example:
    npx create-orgagent my-company
    cd my-company
    claude
    # Then type: /onboard

  Creates a new AI agent organisation powered by Claude Code.
  `);
  process.exit(1);
}

const targetDir = path.resolve(process.cwd(), projectName);
const templateDir = path.resolve(__dirname, '..', 'template');

// Check if directory already exists
if (fs.existsSync(targetDir)) {
  console.error(`\n  Error: Directory "${projectName}" already exists.\n`);
  process.exit(1);
}

// Check if template directory exists
if (!fs.existsSync(templateDir)) {
  console.error(`\n  Error: Template directory not found. Package may be corrupted.\n`);
  process.exit(1);
}

console.log(`\n  Creating OrgAgent project: ${projectName}\n`);

// Copy template recursively
copyDirRecursive(templateDir, targetDir);
console.log('  \u2713 Project files created');

// Install dependencies
console.log('  \u23F3 Installing dependencies...');
try {
  execSync('npm install', { cwd: targetDir, stdio: 'inherit' });
  console.log('  \u2713 Dependencies installed');
} catch (e) {
  console.warn('  \u26A0 npm install failed — run it manually after setup');
}

// Initialize git
try {
  execSync('git init', { cwd: targetDir, stdio: 'pipe' });
  console.log('  \u2713 Git repository initialized');
} catch (e) {
  console.warn('  \u26A0 git init failed — initialize manually if needed');
}

// Print success message
console.log(`
  \u2713 OrgAgent project created successfully!

  Next steps:

    cd ${projectName}
    claude

  Then inside Claude Code, type:

    /onboard

  This starts the alignment conversation to set up your AI organisation.
  You'll define your mission, values, goals, language, budget, and more.
  The system will create your CEO and CAO agents automatically.

  After onboarding:

    /status          Show org overview
    /heartbeat       Run all agents
    /heartbeat ceo   Run just the CEO
    /approve         Review pending proposals
    /dashboard       Start the web dashboard

  Schedule automatic heartbeats:

    /loop 2h /heartbeat

  Documentation: https://github.com/yourusername/orgagent
`);

// Helper: recursively copy directory
function copyDirRecursive(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}
