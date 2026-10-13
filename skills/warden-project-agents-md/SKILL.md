---
name: warden-project-agents-md
description: Author or update AGENTS.md (and thin CLAUDE.md) for a Magento 2 project running on Warden, from verified repo sources, following the house skeleton. Use when asked to "generate AGENTS.md", "write project guidelines", "update AGENTS.md", "create CLAUDE.md for this project", or onboard a new Magento + Warden repo for AI agents. Magento + Warden only; requires the `warden-dev` skill.
---

# warden-project-agents-md

Generate/refresh a project's `AGENTS.md` for AI agents. Magento 2 + Warden shops and extension-development instances.

## Gate — run first
All must hold, else decline with the reason and produce no output:
- `composer.json` requires `magento/product-community-edition` OR `magento/project-community-edition` → else "not a Magento project".
- `.env` sets `WARDEN_ENV_TYPE` → else "not a Warden project".
- `warden-dev` skill available in this session → else "needs the `warden-dev` skill".

## Project type — decide second
Skeleton sections are tagged `[shop]`, `[ext]` or `[both]`. Emit only the tags that match.
- **Shop** — client storefront. Signals: custom theme under `app/design/frontend/<Vendor>/`, many 3rd-party modules vendored in `app/code`, client Jira prefix. Focus: legacy map, active theme chain, frontend build, patch flow.
- **Extension development instance (`[ext]`)** — near-stock Magento used to develop and release distributed packages. Signals: packages as git submodules under `src/<Vendor>/` (`.gitmodules`), `path` repo `src/*/*`, near-empty `app/code`, release script. Focus: package inventory, submodule git + GrumPHP workflow, releases.
  - **Package architecture goes into the package, not the root `AGENTS.md`.** Data flow, queue topics, CLI commands, DB schema, `system.xml` paths, admin routes/ACL, extension points, gotchas → `src/<Vendor>/<Pkg>/AGENTS.md`. It ships with the package repo and serves non-Claude agents too.
  - Package `CLAUDE.md` = `@AGENTS.md` import, same layout rules as the root (see "File layout"). Claude Code loads it lazily — only when files in that package are read.
  - **Pair invariant:** a package `AGENTS.md` never exists without a `CLAUDE.md` loading it (import or symlink). A lone `AGENTS.md` is invisible to Claude Code → broken.
  - Package `AGENTS.md` missing → propose creating the pair with that content. Don't put package architecture into the root `AGENTS.md` of the dev repo.

## The prime rule — actionable only
`AGENTS.md` loads into context on **every new session**. Every line must change what an agent does.

**BANNED — archaeology and meta-commentary:**
- staleness verdicts: "X is stale", "X is not stale", "don't derive version from it"
- absence notes: "referenced nowhere", "no config exists", "not wired", "dormant"
- conflict trivia: "config A sets level 2 but file B says 4"
- leftovers: "Y is a stale copy — live one is Z"
- evidence notes: "confirmed live", "verified on <date>", "tested with X". State the rule; the proof lives in the ticket.
- hedges: "verify before assuming", "check before debugging"
- drift-prone counts: file counts, test counts, "248/254 files", "No tests exist yet". Nobody recounts them; they rot.
- service version tables. Versions live in `.env`; point at it.

If a fact doesn't tell an agent what to run, where to put code, or what not to touch → cut it. Document the **live** config path and values; never narrate what the wrong one was.

## AGENTS.md is a team file
- It ships with the repo and is read by teammates who may have no parent `CLAUDE.md`.
- **Never reference a parent/global `CLAUDE.md` from inside `AGENTS.md`** — no "see parent CLAUDE.md", no "(parent CLAUDE.md rule)".
- Sibling docs inside the repo (`src/*/AGENTS.md`, `src/*/README.md`) are fine to point at.

## File layout — detect, preserve
Run `ls -la AGENTS.md CLAUDE.md`. Three valid layouts:
- `CLAUDE.md` contains only `@AGENTS.md` (default for new projects).
- `CLAUDE.md -> AGENTS.md` symlink.
- `AGENTS.md -> CLAUDE.md` symlink.

Keep the existing layout. Edit the real file; never replace a symlink with a copy. Header line (section 1) names the actual layout. Same rules for `[ext]` package-level files.

## Extract from live sources — never memory
Read each, pull values:
- `composer.json` — magento pkg + version, PHP constraint, Hyvä pkgs, patcher pkg, `extra.patches`, `repositories` (`path` repos, private registries).
- `.env` (via `warden-dev` skill) — env name, domain, **which services are OFF** (`WARDEN_*=0`). Agents assume everything is on; that's actionable. Versions stay in `.env`.
- whichever exist, all optional: `grumphp.yml` (root + per submodule), `phpstan*.neon`, `rector.php`, `.php-cs-fixer*.php`, `phpcs.xml`, any wrapper script that overrides tool defaults — tools wired, scoped paths, run commands. Wrapper found → point at it as the place to change levels/flags, nothing more.
- every `phpunit.xml` / `phpunit.xml.dist` (`dev/tests/{unit,integration}/`, or project-specific dirs) — suite globs, bootstrap consts, unit/integration cmds.
- `composer.lock` — PHPUnit major version.
- `app/code/*` + `src/*` + `app/design/frontend/*` listing — namespaces, module list, active theme + parent chain.
- `.gitmodules` — `[ext]` package inventory.
- `package.json`, `webpack*.js`, `tailwind.config.js` — `[shop]` frontend build.
- git log + branch names — Jira prefix, commit subject format.

**Verify, don't assume.**
- A config named in a previous version of the file may no longer exist. `ls` it.
- `ls` every `phpunit.xml` suite glob with its exact case. Linux is case-sensitive; a wrong-case glob silently finds zero tests. Mismatch → report it as a bug in chat, don't document around it.

## Section skeleton — emit in this order
Fill only verified values. Subject absent from the project (no GrumPHP, no custom frontend build, no patches) → omit that section or row entirely, no "not configured" note.

1. `[both]` **Header** — 1 line: guides AI agents; name the file layout (import or symlink). Point at sibling docs (`src/*/AGENTS.md` for package architecture, `src/*/README.md` for submodule workflow); this file = env, rules, commands.
2. `[both]` **Project overview** — what the repo is *for*: shop or extension-dev instance, which product. Magento version (drives available APIs).
3. `[both]` **Env** — Warden env name, type, base domain + local URL. Then, verbatim:
   `- MUST ALWAYS use \`warden-dev\` skill for env ops: start/stop, shell, db, logs, debug. No duplicate content here — invoke skill.`
   Then `- Service versions → \`.env\`.` plus OFF services only. Never restate what the skill covers.
4. `[both]` **Custom code** — allowed dirs + namespaces, read-only dirs (`vendor/ lib/ setup/ generated/ pub/static/`), `path`-repo symlink behavior (when `composer update` is needed), private registry, dir-name == namespace invariant. `[shop]`: active theme + parent chain.
5. `[shop]` **Legacy code** — which dirs are inherited, which are 3rd-party vendored into `app/code` (upstream upgrades won't reach them), which are project-specific. Not a style reference; no refactor unless ticket asks. Customized themes: trace parent chain before editing.
6. `[ext]` **Packages** — table: submodule | package | type | one-line purpose. Then the git model: each submodule has own `.git` (`.git/modules/...`), stage inside the submodule. Real gotchas only: naming inconsistencies an agent would guess wrong, version pins that go stale together, same-named repos of the wrong lineage.
7. `[shop]` **Frontend build** (only if custom build) — tool, config, install + build commands via Warden, entry points, outputs and whether they're committed.
8. `[ext]` **Releases** — script path, default-safe mode, what it does in order, what aborts it.
9. `[both]` **Patch flow** — patcher, `patches/<Vendor_Package>/`, add-patch steps, excluded/critical patches.
10. `[both]` **Code quality** — PHP target. Table: tool | config path | scope. Point at the one file that controls levels/flags.
11. `[both]` **GrumPHP** (only if `grumphp.yml` exists) — where `grumphp.yml` lives (root vs per submodule), hook chain, init command.
    - Manual run through Warden when host PHP ≠ project PHP (pre-commit hook may run on host). Real path:
      `warden env exec -w /var/www/html/<submodule-path> php-fpm <relative-vendor>/bin/grumphp git:pre-commit --no-interaction`
    - `[ext]`: run scoped to the submodule. From superproject root `git diff --cached` sees the submodule as one gitlink line → every file task matches zero files → false pass.
    - `fix_by_default: true` → tools rewrite files in place. After the run check `git status --short` for `MM`/`AM`, re-stage, re-run.
12. `[both]` **Code style** — strict types, promotion/readonly, DI-first. Project-specific only.
13. `[both]` **Testing** — PHPUnit major version, phpunit configs, unit/integration/single-file/single-test commands (all `warden env exec php-fpm ...`), test dirs, what the integration bootstrap **disables**, install config path.
14. `[both]` **DB access** — project facts only: which DBs exist (local Warden, integration test DB), which must not be mixed, which are prod. Never name IDE data sources or read `.idea/` for this — IDE settings differ per user.
15. `[both]` **Pre-submission MUST** — ordered list: GrumPHP wired → `git add` (`[ext]`: inside submodule) → GrumPHP; else the linters from section 10 → tests if touched → `[ext]` version/pin sync.
16. `[both]` **Conventions** — Jira prefix, commit subject format, tense. `[ext]`: release commit format.
17. `[both]` **Guidelines maintenance MUST** — update this file when env/tooling/tests/release/inventory change.
    - `[ext]`: package architecture changes → package `AGENTS.md`. Emit this rule verbatim:
      `- Package has architecture worth documenting (data flow, queues, CLI, DB schema, system.xml, ACL, extension points, gotchas) and no \`AGENTS.md\` → create \`src/<Vendor>/<Pkg>/AGENTS.md\` + \`CLAUDE.md\` containing only \`@AGENTS.md\`. Existing \`AGENTS.md\` without \`CLAUDE.md\` → add the \`CLAUDE.md\`. Never one without the other.`

## Style — caveman-compressed
Drop articles/filler/pleasantries. Fragments OK. `[thing] [value] [note].` Commands verbatim in backticks. Terse but every actionable fact intact.

## Parent-dedup — before write
- Session context already holds instruction files from outside the project (user-level `~/.claude/CLAUDE.md`, any ancestor-dir `CLAUDE.md`) → drop every rule they already state. Claude Code loads them each session; a copy costs tokens twice and drifts.
- None loaded → skip this step. Never fill the gap with generic rules; project file = project-specific facts only.

## Update mode (AGENTS.md exists)
- Re-verify drift-prone values (pkg versions, tool config paths, module list, suite globs). Correct them **silently** — fix the value, don't annotate that it changed or what it used to be.
- Confirm each named config file still exists before keeping its row.
- Preserve project-specific prose and legacy warnings the user wrote.
- Remove content that now violates this skill (global-rule copies, version tables, caveman activation, archaeology).
- Report the diff in chat: what changed, why, citing the source file.

## After write
- Outside-project instruction files loaded → confirm none of their rules leaked in. Always: no reference to them.
- Re-scan for banned archaeology (see prime rule). Cut what slipped in.
- Confirm file layout unchanged (`ls -la AGENTS.md CLAUDE.md`).
- `[ext]`: `ls -la src/*/*/AGENTS.md src/*/*/CLAUDE.md`. Every package `AGENTS.md` has its `CLAUDE.md` pair; fix missing ones.
- Last step, only if `caveman:caveman-compress` skill is installed: invoke it on each real (non-symlink) guidelines file written this run. Then delete the `<FILE>.original.md` backup it creates, and re-run the layout check (symlink must survive).
