# OpenCode

## What it is

OpenCode is a terminal-based AI coding agent.

## Why I use it

An alternative and complement to Claude Code for AI-assisted coding in the terminal.

## What's here

- `opencode.jsonc` -> `~/.config/opencode/opencode.jsonc` - main config.
  It uses the system theme and registers a local MCP server, `xcode` (via `xcrun mcpbridge`), giving the agent Xcode/iOS tooling.
- `tui.json` -> `~/.config/opencode/tui.json` - terminal-UI settings.

## Agent instructions

The agent instruction file OpenCode reads (`~/.config/opencode/AGENTS.md`) is the shared `AGENTS.md` from the repo root, symlinked here.
The same file is reused for Claude (`~/.claude/CLAUDE.md`), Gemini (`~/.gemini/GEMINI.md`), and Codex (`~/.codex/AGENTS.md`, `~/AGENTS.md`), so all agents follow one set of rules.
See the repo root README.
