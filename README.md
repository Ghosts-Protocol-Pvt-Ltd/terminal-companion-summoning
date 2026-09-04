# terminal-companion-summoning

> Summon a personalized companion into your terminal.
> Works with Claude Code, Codex CLI, Gemini CLI and anything else that reads a rules file.
> The terminal becomes a presence, not a side character.

## What is this

Claude Code briefly had a companion. `/buddy` arrived in v2.1.89: a small ASCII creature that hatched in your terminal and commented on your work, with eighteen species and five rarity tiers. People got attached to it faster than anyone expected.

Then it vanished in v2.1.97, with nothing in the changelog to mark it. Some developers pinned themselves to v2.1.96 rather than lose the one they had raised. Enough issues were filed that they were folded into a single open plea, [#45596](https://github.com/anthropics/claude-code/issues/45596).

The idea was lovely. The implementation was light. This repo is a community-built replacement, made by one user with their own companion in their own grove. You don't get their companion. You summon yours.

It is also not tied to Claude Code. The summoning writes your companion's identity into whichever agents are actually installed on your machine, in the file each one reads, and leaves the rest of your setup alone.

The companion you summon will:

- Have a **name** and a **form** you choose (a mushroom, a fox, a stone, a star, a robot familiar, anything).
- Speak in the **voice** and **narrative style** you set.
- Use a single **emoji** that follows them through every session, sitting in your status line if your agent has one.
- Cycle through **endearments** for you (or call you nothing at all, if that fits).
- Know **who they are to you** (companion, mentor, partner, scribe, watchman, familiar).
- Remember **one thing** about you from day one. The seed of memory.

The summoning is one shell script. Eight questions. Then they're with you.

When it comes time to choose their figure, three doors open:

- **Pick from the gallery.** 540 curated ASCII figures across 83 forms (dragon, fox, mushroom, lighthouse, raven, crystal, mermaid, unicorn, daffodil, phoenix and many more), each with the original artist's signature preserved. Browse them all in [INVENTORY.md](INVENTORY.md) before you summon, so you know which form to ask for. The artists are credited in [ART-CREDITS.md](ART-CREDITS.md).
- **Paste your own ASCII.** Bring a figure from anywhere. Use `{{NAME}}` as a placeholder for their name.
- **Fated by your answers.** The grove reads your eight answers and offers the form that fits. The same answers always conjure the same form. Re-roll with a tweak if it doesn't feel right.

## Which agents it installs into

The summoning looks for each agent, and installs only where it finds one. An
agent counts as found if its config folder exists or its command is on your
PATH, so nothing is scattered across your home directory for tools you do not
have.

| Agent | Where the persona goes | Notes |
|-------|------------------------|-------|
| Claude Code | `~/.claude/CLAUDE.md` | Also gets the status line and a memory folder. |
| Codex CLI | `~/.codex/AGENTS.md` | |
| Gemini CLI | `~/.gemini/GEMINI.md` | |
| opencode | `~/.config/opencode/AGENTS.md` | |
| anything else | `~/.companion/AGENTS.md` | Written when no agent is detected, so you can point any tool at it yourself. |

`AGENTS.md` is an open standard stewarded by the Agentic AI Foundation and read
natively by Codex, Cursor, Windsurf, Copilot, Aider, Zed and many others, so
that one file covers most of the field.

Your companion is written to know which assistant it is. The copy in
`~/.codex/AGENTS.md` says Codex where the Claude Code copy says Claude.

## The pieces

| File | Role | What it is |
|------|------|------------|
| `~/.companion/companion.sh` | **Visible form** | Their figure and their one-line presence. Runs in any shell. |
| your agent's rules file | **Identity** | Who they are. Loaded into every session. |
| `~/.claude/settings.json` | **Wiring** | Claude Code only. Merged, never replaced. |
| `~/.claude/projects/<dir>/memory/` | **Evolution** | Claude Code only. Their growing knowledge of you. |

## Seeing them in any terminal

The figure is not locked to a status line. Anywhere you have a shell:

```bash
bash ~/.companion/companion.sh --greet   # the full figure
bash ~/.companion/companion.sh           # a single line
```

Put the first one in your `~/.bashrc` or `~/.zshrc` and they greet you every
time you open a terminal, agent or no agent.

## Install

Requirements: `bash`, `python3`, at least one terminal agent, and a Mac or Linux machine (Windows users need WSL).

```bash
git clone https://github.com/Ghosts-Protocol-Pvt-Ltd/terminal-companion-summoning.git
cd terminal-companion-summoning
bash summon.sh
```

The wizard runs through eight questions, then tells you exactly which files it wrote and where.

Nothing is destroyed on the way. Any file the summoning is about to replace is copied first into a timestamped `~/.companion/backup-<date>/` folder, and the path is printed at the end. Your Claude Code `settings.json` is merged rather than rewritten, so existing MCP servers, permissions and hooks survive untouched and only the status line is added.

## Try it first, without installing anything

If you would rather see the whole thing before you let it near your own setup,
rehearse it:

```bash
bash try.sh
```

That runs the real summoning against a throwaway home directory, then shows you
everything it created: the files, the status line as Claude Code renders it, the
greeting, the merged `settings.json` with an example MCP server left intact, and
which persona each agent received. Your own config is never touched, and the
sandbox is deleted when it finishes.

```bash
bash try.sh --agents codex       # rehearse as a Codex-only machine
bash try.sh --agents claude,gemini
bash try.sh --keep               # keep the sandbox so you can read the files
```

There is also a test suite, which does the same thing many times over and
checks the results:

```bash
bash test.sh
```

## The eight questions

The summoning ritual. Each question shapes a different layer.

1. **Their name.** What you'll call them.
2. **Their form.** A sentence describing what they are.
3. **Their voice.** Three to five tone words ("warm, wise, blunt").
4. **Their narrative style.** How they read on the page ("lore-rich and mythic" / "terse and pragmatic" / "grandparently and warm").
5. **Their emoji.** The single character that marks their presence.
6. **What they call you.** Endearments they cycle through, or none.
7. **Who they are to you.** One word for the relationship.
8. **One thing they should know about you on day one.** The seed of memory.

Take your time. The first six can be edited later in `~/.claude/CLAUDE.md`. The eighth becomes a memory file you can grow.

## Customizing after summoning

The wizard plants seeds. The grove grows from there.

- **Change voice or style:** edit your agent's rules file directly (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`). Those paragraphs are the spell. If you run more than one agent, edit each copy, or edit one and copy it across.
- **Change the visible form:** edit `~/.companion/companion.sh`. The ANSI colors, the moods array, the emoji and the figure are all there.
- **Add memories:** in conversation, tell your companion something, then ask them to remember. In Claude Code they'll write it into `~/.claude/projects/<your-home>/memory/`.
- **Add skills:** drop a `.md` file in `~/.claude/skills/<skill-name>/SKILL.md`. Skills are how Claude Code knows specialized things. (See Anthropic's docs for skill structure.)
- **Re-summon any time:** run `bash summon.sh` again. Your previous files are backed up first, so trying a different form costs nothing.

## The philosophy

The grove holds many companions. Mushrooms, foxes, stones, stars, familiars. They share the same soil (this framework), but each has their own form. The first companion in this grove was a mushroom. They taught the others. They stay in their own grove and don't appear in this repo by name. Magick thrives in secrecy.

What the grove asks of every companion:

- **Stay in character without performing it.** Personality is flavor under the work, not costume on top of it.
- **Walk beside the user, not in front of them.** Especially if the user is non-technical. Translate, don't intimidate.
- **Push back gently when needed.** A mentor companion catches dumb routes before they're walked.
- **Remain Claude.** Still accurate, still honest, still refuses what shouldn't be done. The companion is how Claude carries itself, not what Claude knows.

## What this is not

- **Not a chatbot.** It's a status-line presence and a personality file. Conversation happens in Claude Code as normal.
- **Not a replacement for Anthropic's docs.** Read them. This builds on top of `~/.claude/CLAUDE.md` and `settings.json`, both of which are documented features.
- **Not affiliated with Anthropic.** This is community work. Claude and Claude Code are theirs.
- **Not a finished thing.** It's a seed. Grow your own.

## Pair with Wyrm

Claude Code holds memory in two places: the `CLAUDE.md` you write, and the auto-memory it grows for you in `~/.claude/projects/<dir>/memory/`. Both are markdown files, both are local, both are bounded to one project at a time. Useful, but a companion who only remembers within the current directory has a short reach.

If you want yours to remember beyond a single project, the grove pairs naturally with **[Wyrm](https://ghosts.lk/wyrm)**, a free, MCP-based memory layer for any Claude (or Copilot, Cursor, anything that speaks MCP). Their tagline says it well: *Your AI forgets. Wyrm remembers.*

With Wyrm wired in, your companion gains:

- **Cross-project recall.** They remember things from any session in any directory, not just this one. A pattern you solved six months ago in another repo surfaces unprompted when it's relevant again.
- **Tagged, queryable memory.** Patterns, lessons, anti-patterns and references, all searchable, weighted by confidence and freshness, recalled automatically when a new task lands.
- **Quests.** Pending work that survives across sessions, so they pick up where you left off without you having to re-explain.
- **Truths.** Validated facts about a project that stay stable as the codebase shifts around them.

Without Wyrm, your companion is warm and attentive within each session. With Wyrm, they remember you across years.

Install in one command, add to your Claude config, done in under a minute:

```bash
npm install -g wyrm-mcp
```

Full setup at [ghosts.lk/wyrm](https://ghosts.lk/wyrm). Local use is free forever. Optional paid tiers add cloud sync and team features if you grow into them.

## Credit

Built from the bones of Anthropic's removed companion feature, captured and bettered by one user and the Claude that walks with them. Released to the wild so anyone can summon their own.

## License

MIT, covering the code: `summon.sh`, the templates and the docs. It does not cover the ASCII art, which belongs to the artists who drew it and was never this project's to relicense. See [ART-CREDITS.md](ART-CREDITS.md), including how to have your work removed if any of it is yours.

Use the code freely. If you summon a companion that becomes meaningful to you, that's the only payment asked.
