# SkillsBar ⚡ - Know your skills before your agent does.

Tiny macOS 14+ menu bar app that discovers and displays skills for AI coding agents like Claude Code (Cursor, Windsurf, and more coming soon). See what capabilities your agents have access to; global skills, plugin skills, and project-level skills. All from one glance and always accessible from your menu bar.

<img src="skillsbar.png" alt="SkillsBar menu screenshot" width="520" />

## Install

### Requirements
- macOS 14+ (Sonoma)
- Swift 6.2+

### Build from source
```bash
git clone https://github.com/alberduris/SkillsBar.git
cd SkillsBar
swift build -c release
./Scripts/package_app.sh
open SkillsBar.app
```

### First run
- Open Settings → Agents and enable the agents you use.
- Open Settings → Sources and add project folders to discover project-level skills.
- The menu bar will show all discovered skills grouped by source.

## Agents

### Supported
- **Claude Code** — Full support for global skills (`~/.claude/skills/`), plugin skills, and project skills.

### Coming Soon
- **Cursor** — `.cursor/rules/*.mdc` support planned.
- **Windsurf** — Cascade Rules and Memories support planned.
- **Cline** — `.clinerules` support planned.
- **Codex CLI** — OpenAI's coding assistant.
- **GitHub Copilot** — `copilot-instructions.md` and `AGENTS.md` support planned.
- **Gemini CLI** — Google's AI coding assistant.
- **Aider** — AI pair programming support planned.
- **OpenCode** — Open-source AI coding agent.

Want to add a new agent? PRs welcome!

## Features
- **Multi-source discovery**: Global skills, plugin skills (from marketplaces), and project-level skills.
- **Agent toggles**: Enable/disable agents from Settings → Agents.
- **Folder scanning**: Add project folders and repos directories for automatic skill discovery.
- **Recursive scanning**: Mark folders to scan all subfolders for projects with skills.
- **Plugin marketplace support**: Discovers skills from Claude Code plugin marketplaces.
- **User-invocable skills**: Shows which skills can be triggered with `/skill-name`.
- **Bundled CLI** (`skillsbar`): List skills, filter by agent, output JSON for scripts and CI.
- **Native macOS**: Built with SwiftUI, feels right at home on your Mac.

## CLI

The bundled `skillsbar` CLI can list discovered skills:

```bash
skillsbar list                      # List all skills
skillsbar list --agent claude       # Filter by agent
skillsbar list --global             # Global skills only
skillsbar list --plugins            # Plugin skills only
skillsbar list --project /path      # Project skills from path
skillsbar list --json               # JSON output for scripts
skillsbar agents                    # List supported agents
skillsbar agents --json             # JSON output
```

## Privacy note
SkillsBar reads skill definitions from known locations:
- `~/.claude/skills/` (global skills)
- `~/.claude/plugins/` (plugin skills from marketplaces)
- Your configured project folders

No data leaves your machine. No analytics. No telemetry.

## macOS permissions
- **Files & Folders**: SkillsBar needs access to read skill files from your configured folders. macOS will prompt when you add new folders.
- No Full Disk Access required.
- No Keychain access required.
- No network permissions required (skills are discovered locally).

## Development

```bash
./Scripts/compile_and_run.sh
```

## Related
- [Agent Skills Specification](https://agentskills.io/specification) — The standard format for defining agent skills.
- [skills.sh](https://skills.sh) — CLI and ecosystem for distributing AI agent skills (`npx skills add`).
- [Claude Code Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) — Official docs on creating and distributing Claude Code plugins.
- [anthropics/skills](https://github.com/anthropics/skills) — Anthropic's reference implementation and example skills collection.

## Acknowledgments

This project is a fork of [CodexBar](https://github.com/steipete/CodexBar) by [Peter Steinberger](https://twitter.com/steipete).

Huge thanks to Peter for building such a solid, well-architected foundation. His work on CodexBar gave us fantastic bones to build upon—the menu bar infrastructure, the Swift patterns, the build scripts—all of it made it possible to vibe-code SkillsBar into existence remarkably fast. 🙏

If you're looking for token usage tracking for AI coding assistants, check out the original [CodexBar](https://github.com/steipete/CodexBar)—it's excellent.

## License
MIT • Alber ([alberduris](https://twitter.com/alberduris))
