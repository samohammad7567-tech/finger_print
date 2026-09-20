# Claude Flutter Clean Rules

This folder contains Claude-ready instruction files based on Mohammad's two Flutter projects:

- PharmaChain / Pharmacy
- Fruite Hub

It also assumes the reusable Flutter Core Kit extracted from both apps is available.

## Files

- `CLAUDE.md`: best file to paste into Claude Code project instructions or place at the project root.
- `CONSTRAINTS.md`: detailed rules and constraints for architecture/refactoring.
- `SKILL.md`: compact skill-style instruction file for Claude/custom assistants.
- `docs/CORE_KIT_USAGE.md`: how to use the reusable Core Kit.
- `docs/REFACTOR_CHECKLIST.md`: checklist before delivering changes.
- `templates/FEATURE_TEMPLATE.md`: feature folder template.

## How to Use with Claude Code

Option 1: copy `CLAUDE.md` to the root of the Flutter project.

Option 2: paste `CLAUDE.md` + `CONSTRAINTS.md` into Claude project instructions.

Option 3: if your Claude workspace supports skills/custom instructions, use `SKILL.md` as the skill instruction file.

Always also attach or reference the reusable Core Kit ZIP when asking Claude to implement new features.
