---
name: implement-magento-task
description: End-to-end Magento 2 / Adobe Commerce task implementation — spec or Jira ticket in, reviewed and tested change out. Main agent plans and implements as usual, calls `magento-agent-toolkit:magento-tests-writer` for coverage, finishes with the `magento-agent-toolkit:review-magento` skill and auto-applies only proven, obvious fixes (overrides magento-agent-toolkit:review-magento's no-edit rule inside this flow); everything else is left for the user. Optionally delegates to `caveman:cavecrew-investigator`, `caveman:cavecrew-builder`, `magento-agent-toolkit:minibuilder`. Works in plan mode (plan → approval → implement) and auto mode (straight through). Use for "/magento-agent-toolkit:implement-magento-task", "implement ABC-123", "implement this ticket/spec/task" in a Magento project.
---

# implement-magento-task — orchestrated implementation

Caveman register. **You are the head of the process.** Work as you normally would: read, design,
implement. This skill only fixes *when* the helpers get called and *what* you may apply without asking.

Self-contained: works with or without the user's `CLAUDE.md`. Project `AGENTS.md` / `CLAUDE.md`
conventions still win on conflict. Any helper missing → see FALLBACKS.

## Phases by mode

| Mode | Flow |
|---|---|
| Plan mode | PHASE 1 → write plan → `ExitPlanMode` → user approves → PHASE 2 |
| Auto / default mode | PHASE 1 → PHASE 2, no stop between them |

Plan mode allows only read-only work in PHASE 1. Nothing gets written, `magento-agent-toolkit:magento-tests-writer` doesn't
run, and there are no builder edits until the plan is approved.

---

## PHASE 1 — understand + plan

### 1.1 Get the task
- Jira key given (`ABC-123`) + Atlassian/Jira MCP connected → fetch the issue: summary, description,
  acceptance criteria, comments, linked issues. Not connected → use the pasted text; ask only if
  there is no spec at all.
- Extract: **problem**, **acceptance criteria** (numbered), **constraints** (BC, versions, perf,
  distributable module or app code), **explicitly out of scope**.
- Spec ambiguous where two readings lead to different code → ask **one** question now. Don't
  guess into the plan.

### 1.2 Investigate
- Read project `AGENTS.md` / `CLAUDE.md`: stack, module locations, run/test/lint commands, commit rules.
- Locate the affected code: classes, plugins/observers on them (`di.xml`, `events.xml`), layout, config,
  schema, existing tests of those classes.
- Wide sweeps (find all callers, map a module, many naming variants) → delegate to
  `caveman:cavecrew-investigator`. Several independent sweeps → spawn them in one message.
- Legacy code is not a spec. Note inherited defects as incidental findings, don't copy them.

### 1.3 Plan
Write the plan (plan file in plan mode, short outline in auto mode):

```
## Goal
<problem in 1–2 lines>

## Acceptance criteria → implementation
| AC | Change | Files |
|---|---|---|
| 1 | ... | /abs/path/File.php |

## Design decisions
- <decision> — why. Mark the ones the user must confirm.

## Steps
1. <step> — owner: main | caveman:cavecrew-builder | magento-agent-toolkit:minibuilder
...
N-2. Tests — magento-agent-toolkit:magento-tests-writer (scope: <files / behaviors>)
N-1. Review — magento-agent-toolkit:review-magento, auto-apply per APPLY POLICY
N. Pre-submission — <project's documented checks>

## Out of scope / risks
```

Every AC maps to at least one change and is testable, or the plan says why it isn't.

---

## PHASE 2 — implement, test, review

### 2.1 Implement
- Do the work yourself by default. Delegation is optional (see DELEGATION).
- Follow project conventions: plugin naming, comment rules, DI, no `ObjectManager`, etc.
- Keep a running list of **locked decisions**: choices you or the user made on purpose. Review agents
  and the tests writer get this list so they don't "fix" intentional calls.

### 2.2 Tests — `magento-agent-toolkit:magento-tests-writer`
Call it after implementation, when the change touches **behavior** (PHP logic, plugins, observers,
repositories, config-driven paths, patches). Skip it only if:
- the change is purely template / CSS / JS / copy / XML with no PHP behavior, or
- the user said tests are out of scope. Say so in one clause in the final summary, or
- it's a small follow-up after the flow finished (see POST-FLOW FOLLOW-UPS).

The agent itself decides unit / integration / both / none. Don't pre-decide the layer.

Prompt = **scope + why + what's locked**. Same rules as magento-agent-toolkit:review-magento STEP 3:
- exact changed files or the diff command (`git diff` / `git diff <base>...HEAD`);
- the problem and acceptance criteria in plain words;
- locked decisions and constraints.
- NOT: which cases to write, which layer, how to mock. That is its job.

Its summary → act on it:
- 🔴 production bug found by a test → yours to fix (it's in task scope). Fix, re-run the failing test.
- 🟡 seam / testability finding in code you just wrote → fix if small and in scope; else carry to the final summary.
- "Not run" items (e.g. GrumPHP) → you run them in 2.4.

### 2.3 Review — `magento-agent-toolkit:review-magento` skill
Invoke the `magento-agent-toolkit:review-magento` skill on the full task diff, tests included. Follow its STEP 1–4 as written,
including rating every finding with evidence. Give the review agents the locked-decisions list.

**Then replace its "stop, ask which to apply" with APPLY POLICY below.** This override is deliberate
and holds only inside this skill's flow.

#### APPLY POLICY
Auto-apply a finding **only when ALL hold**:
1. rated ✅ valid, and you read the code it points at;
2. exactly one reasonable fix. No alternatives with different trade-offs;
3. local: no public API / interface / BC change, no DB schema change, no behavior-contract change
   beyond what the spec asks;
4. doesn't touch a locked decision or anything the spec left open;
5. affected tests + linters pass after the fix.

Coverage gaps (🟠) from the test reviewer get no shortcut. Same rating as any finding: ✅ only if
the missing test would catch a real bug at a sane cost. Tests of config/wiring (Reflection on private
props, plugin-list lookups), tautologies ("mocked exception propagates through code with no catch")
and gaps `setup:di:compile` / linters already cover → 🤔 or ❌, drop them.
Gap rated ✅ → send it back to `magento-agent-toolkit:magento-tests-writer` (continue the same agent via `SendMessage` if
still reachable, else a new call with the gap list).

Everything else is **left for the user**, with a one-line reason:
- ⬇️ / 🤔 / 🔒 / ❓, multiple valid fixes, cross-cutting refactors, anything failing check 5;
- a fix that failed check 5 → revert it, then report.

Applying fully specified fixes → optionally `magento-agent-toolkit:minibuilder`; small judgment edits → `caveman:cavecrew-builder`.

After applying: re-run the affected tests and linters. **No second full review** unless the fixes
turned out bigger than the policy allows. In that case they shouldn't have been applied.

### 2.4 Pre-submission
Run the project's documented pre-submission checks (e.g. `AGENTS.md`: stage + GrumPHP, inspections).
Staging is allowed when the project docs require it. **Never commit or push.** Fix what they flag
within task scope.

---

## DELEGATION (optional)

| Helper | Use for | Don't use for |
|---|---|---|
| `caveman:cavecrew-investigator` | read-only locate / map sweeps, esp. PHASE 1 | decisions, fixes |
| `magento-agent-toolkit:minibuilder` | fully specified edit, what + how given, ≤5 files (rename, same pattern in N places, applying a ✅ fix) | anything where it must work out how |
| `caveman:cavecrew-builder` | bounded 1–2 file edit with small judgment | new features, 3+ files, design |
| `magento-agent-toolkit:magento-tests-writer` | all new / extended PHPUnit tests | production code |

Rules:
- Delegation is optional. It never replaces your judgment, and you verify every edit it returns.
- Design and anything needing task context stay with you. Cross-file changes go out only fully specified.
- Independent helpers → one message, parallel.
- A helper refuses (`too-big`, `needs-judgment`) → do it yourself or escalate one tier. Don't retry the same helper.

## FALLBACKS

| Missing | Do |
|---|---|
| Jira MCP | use pasted spec |
| `caveman:cavecrew-*` / `magento-agent-toolkit:minibuilder` | do the work inline |
| `magento-agent-toolkit:magento-tests-writer` | write tests inline: enumerate every branch first, cheapest layer that proves it, PHP attributes + parameterized fixtures for integration, data providers for input-only variations, no test without a bug it would catch |
| `magento-agent-toolkit:review-magento` | spawn `magento-agent-toolkit:magento-reviewer` + `magento-agent-toolkit:magento-test-reviewer` directly with scope + why + locked; if those are missing too, self-review the diff, rate findings the same way and apply per APPLY POLICY |

## POST-FLOW FOLLOW-UPS
The final summary is out and the user asks for a small change (extract a class, rename, move a
guard) → do it yourself, tests included: adapt the affected tests, run the suite and linters. Don't
call `magento-agent-toolkit:magento-tests-writer` or `magento-agent-toolkit:review-magento` again. A follow-up that adds new behavior or grows
into a redesign → back to PHASE 2 in full.

## GUARDRAILS
- Never commit / push / reset / stash-drop. Staging only when project pre-submission requires it.
- Never run `bin/magento setup:install|upgrade` or other `setup:*` write commands to fix tests. The
  integration suite builds its own sandbox; these overwrite `app/etc/env.php` / `config.php`.
- DB: read queries OK; writes need user approval.
- Stay in task scope. Incidental findings → list at the end, don't act on them.

## FINAL SUMMARY

Plain readable English, short sentences. File refs absolute with line, nothing after them.

```
## Done
- AC1 → <what changed> — /abs/path/File.php:42
- AC2 → ...

## Tests
- <from magento-agent-toolkit:magento-tests-writer summary: files, layer decision, key cases, what was deliberately not covered and why>
- Run: <command> → <real result line>

## Review
- Auto-applied: <finding> — <why it passed APPLY POLICY>
- For you to decide: <finding> — <why not auto-applied>
- Rejected: <finding> — <evidence>

## Checks
- <GrumPHP / linters / inspections: real result>

## Incidental findings
- ...
```

Empty section → `none`. Never claim a check passed without having run it.
