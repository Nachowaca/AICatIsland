# AICatIsland -- Claude Code Game Studios (versión liviana, solo Godot)

Juego 2D isométrico en Godot 4.7: un gatito autónomo en una isla japonesa
(ver `README.md` y `Pendientes.md`). El trabajo se organiza con el framework
Claude Code Game Studios v1.3.0, recortado a Godot: 37 subagentes y 73 skills.

**Recortes respecto del template original** (no buscarlos ni invocarlos): agentes
de Unity, Unreal, Godot C# y GDExtension; el starter web (`.claude/engines/web`);
`/skill-test`, `/skill-improve` y `studio-tests/`; los alias viejos `/help`,
`/settings`, `/changelog`.

## Technology Stack

- **Engine**: Godot 4.7 (Forward+, 2D isométrico)
- **Language**: GDScript
- **Version Control**: Git
- **Build System**: exportación de Godot (sin presets configurados todavía)
- **Asset Pipeline**: importador de Godot; arte procedural más sprites en `assets/`

> **Code root**: el código del juego vive en `scripts/` (no en `src/`), las
> escenas en `scenes/`, los shaders en `shaders/` y las pruebas en `tests/`
> (escenas y scripts propios, no gdUnit4). Donde el framework diga `src/…`,
> leer `scripts/…`. Así lo fija `engine.code_root` en `project.yaml`.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line under this comment is engine-specific,
     and there is none until an engine is set. /setup-engine, the grow's record
     step and /project-settings (engine.name) write
     @docs/engine-reference/<engine>/VERSION.md here for the chosen engine. Skills
     that need the pinned version read that file on demand either way. -->
@docs/engine-reference/godot/VERSION.md


## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

`.claude/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.claude/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this file's folder? Warn first: hooks, deny rules and the
  ask-first mode load only when Claude Code starts here

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** Say "make me a game" (`/prototype`), or run `/start` to begin
> the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
