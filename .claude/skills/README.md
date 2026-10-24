# Agent skills for this project

Claude Code loads every folder here as a skill when it works in this repo
(locally or in a cloud session). They are copies of open-source skills; each
folder keeps its upstream license.

| Skill | Upstream | License |
| --- | --- | --- |
| frontend-design | [anthropics/skills](https://github.com/anthropics/skills) | see `LICENSE.txt` |
| ui-ux-pro-max | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | MIT |
| flutter-ui-design, flutter-ui-patterns, flutter-accessibility, flutter-responsive-layout, flutter-code-review | [thiennc-tesoglobal/flutter-skills](https://github.com/thiennc-tesoglobal/flutter-skills) | BSD-3-Clause |
| flutter-apply-architecture-best-practices | [flutter/skills](https://github.com/flutter/skills) | BSD-3-Clause |
| supabase, supabase-postgres-best-practices | [supabase/agent-skills](https://github.com/supabase/agent-skills) | MIT |

Local changes: `ui-ux-pro-max/SKILL.md` refers to its search script as
`<skill-dir>/scripts/search.py` so it works outside a plugin install, and its
test suite was left out. The thiennc skills omit their `evals/` folders.

Run the design search tool from the repo root:

```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "job board listing" --domain product
```
