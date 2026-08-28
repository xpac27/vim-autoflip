# General rules

## Core principles

- prefer simple and boring solutions
- prefer explicit code over clever code
- prefer incremental changes over large refactors
- prefer extending existing systems over introducing parallel systems
- avoid premature abstractions
- avoid introducing new dependencies without justification
- do not rewrite working systems without explicit user request
- preserve public APIs unless explicitly requested
- keep files and functions reasonably small

## Project philosophy

- when tradeoffs are unclear prefer solutions aligned with the documented technology manifest
- prioritize consistency with existing technology guidance over introducing new patterns

---

# Workflow

## Before coding

- search the codebase for existing patterns to follow
- check related tests before modifying functionality
- read relevant documentation before major changes
- review architecture and existing subsystem boundaries before introducing new patterns

## During coding

- follow existing conventions unless there is a clear reason not to
- when introducing a new pattern or abstraction explain why existing patterns were insufficient
- avoid creating helper functions used only once
- avoid temporary workarounds when possible
- commit often, at least once per implemented feature or sub-feature

## After coding

- write at least 1 test for every new feature or functionality
- write regression tests for bug fixes
- ensure tests, linting and type checks pass before considering work complete
- if tests cannot be written due to lack of testing support explain why
- if existing tests must be modified explain why
- document root cause analysis for bug fixes
- document why the issue happened and how recurrence is prevented

---

# Documentation

## Always keep updated

- `README.md`
  - setup instructions
  - development workflow
  - usage examples
  - "how to" instructions

- `docs/features.md`
  - user-visible features
  - feature status and limitations

- `docs/architecture.md`
  - high level system design
  - subsystem boundaries
  - data flow
  - major technical decisions

- `docs/glossary.md`
  - domain terminology
  - important concepts
  - canonical naming conventions

- `docs/journal.md`
  - dated work log
  - implementation notes
  - bug investigations
  - migration notes

- `docs/debt.md`
  - shortcuts
  - temporary workarounds
  - known limitations
  - future improvements

- `docs/decisions.md`
  - architecture decision records
  - rationale
  - rejected alternatives

- `docs/details/...`
  - implementation details
  - subsystem-specific documentation
  - protocol notes
  - integration behavior

- `docs/technology.md`
  - core stack decisions
  - framework integration guidance
  - technology constraints and defaults

## Documentation rules

- update documentation when behavior or architecture changes
- add date and time to all new entries in `docs/...`
- keep diagrams and examples small and practical
- do not leave undocumented temporary workarounds
- document impact, risks and possible future fixes for technical debt
- avoid duplicating stale information across files

---

# Stability constraints

- avoid destructive changes without explicit confirmation
- avoid changing project structure without updating documentation
- avoid hidden side effects and implicit behavior
- prefer reversible changes when possible
- add logging for critical flows and failures
- fail with actionable error messages

---

# Architecture Decision Record format

Example:

```markdown
## 2026-05-07 - Use SQLite for local persistence

Reason:
- zero setup
- easy backups
- sufficient scale

Rejected:
- postgres: unnecessary operational complexity
- json files: poor concurrent safety
```
