# Agent skills

`starling-desktop/SKILL.md` teaches an agent to launch and control desktop
applications through `agent-client`. It is written for Claude Code, which
discovers skills under `~/.claude/skills/`, but it is plain Markdown — any
harness that can read a file can use it.

The package installs it as **data**, at
`/usr/share/starling/skills/starling-desktop/`, and does not write into anyone's
home directory: `~/.claude` belongs to the user, and a package that installs
into it would fight with whatever the user has there already. Link it in
per-agent:

```sh
mkdir -p ~/.claude/skills
ln -sfn /usr/share/starling/skills/starling-desktop ~/.claude/skills/starling-desktop
```

A symlink rather than a copy so a package upgrade updates the skill too.

Check it took effect by asking the agent to `agent-client windows` — if the
skill is not loaded it will not know the command exists.
