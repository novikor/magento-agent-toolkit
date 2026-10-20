---
name: review-magento
description: Orchestrated Magento 2 code review — fans a scope out to the `magento-agent-toolkit:magento-reviewer` subagent (production code) and, when tests are in scope, the `magento-agent-toolkit:magento-test-reviewer` subagent (unit + integration tests, coverage), then rates every finding before anything is applied. Use for "review this", "review my diff", "review the branch", "audit this module", "/magento-agent-toolkit:review-magento", or any review request in a Magento 2 / Adobe Commerce project. Applies no fixes without explicit user confirmation.
---

# review-magento — orchestrated review

Caveman register. Four steps, in order. No step skipped.

## STEP 1 — resolve scope, state it

Scope must be pinned **before** any subagent spawns, and both subagents must receive the
identical scope. Guess wrong here and the findings can't be cross-referenced.

Resolve in this priority:

1. User named it explicitly (files, dir, commit, branch, PR) → use that.
2. Uncommitted work exists (`git status` dirty) → working-tree diff.
3. Branch differs from base → `git log --oneline <base>..HEAD` + `git diff <base>...HEAD`.
   Base = `master` unless project docs say otherwise.
4. Nothing obvious → ask. One question, don't guess.

Then **print the resolved scope** before spawning: file list (or count + dirs), and what it
came from. One line.

Partition the file list:

| Bucket | Goes to |
|---|---|
| Production PHP, DI/XML, templates, schema, patches, CLI | `magento-agent-toolkit:magento-reviewer` |
| All PHPUnit tests — unit **and** integration — plus their fixtures, data providers, test base classes | `magento-agent-toolkit:magento-test-reviewer` |

Bucket empty → that agent doesn't spawn. Test-only diff = test reviewer alone.

## STEP 2 — decide whether the test reviewer runs

Run `magento-agent-toolkit:magento-test-reviewer` when **any** holds:

- scope contains PHPUnit test files — unit or integration;
- scope changes production behavior and ships **no** test — missing coverage is a finding, and
  this is the agent that makes it;
- user asked about coverage/tests.

**Do NOT run it when the user said tests are out of scope for this task.** Explicit user
exclusion wins over every trigger above. Same if they said "no test review", "skip tests",
"tests handled separately", or scoped the task to production code only. Say once, in one
clause, that test review was skipped per their instruction — then drop it.

If it runs, `magento-agent-toolkit:magento-reviewer` **must not** review tests — unit or integration. Tell it in the
scope line that test files are excluded and reviewed separately. Two agents reporting the same
finding wastes your rating pass and inflates the totals.

If it does not run, `magento-agent-toolkit:magento-reviewer` takes the whole scope.

## STEP 3 — spawn, parallel, context-only prompts

Both Agent calls in **one message** so they run concurrently.

### What the prompt MUST contain

- the scope — exact file paths, or the git ref/diff command that produces it;
- what is excluded and why (e.g. "tests reviewed separately");
- task context, where it exists and is useful:
  - what the change is for, in plain terms;
  - ticket intent — the *problem*, not the ticket ID;
  - decisions the user locked deliberately, and that they were deliberate
    (stops an agent "fixing" an intentional call);
  - hard constraints — BC, supported versions, perf budget, distributable-module status;
  - what is knowingly out of scope / deferred.

### What the prompt MUST NOT contain

Never tell them **how** to review. That's their job, and their rubric is better than an
improvised hint.

Forbidden in the prompt:

- rubric hints, rule IDs, checklists, "pay attention to X";
- "check for N+1 / security / naming / coverage of method Y";
- severity steering ("only report serious ones", "be thorough about Z");
- your own suspicions about where the bug is;
- suggested fixes, or a verdict you already reached;
- anything that narrows their attention to a subset of the scope.

Pattern: **scope + why the change exists + what's locked.** Stop there.

Bad: `Review Foo.php. Check the plugin is stateless and the loop isn't N+1.`
Good: `Review src/Model/Foo.php, src/etc/di.xml (working-tree diff). Adds batching to the
category sync so a 50k-category channel stops timing out. Direct-SQL write bypassing the
repository is deliberate — perf requirement, not an oversight. Tests excluded, reviewed
separately.`

## STEP 4 — rate every finding, apply nothing

Agents done → go through **every** finding and comment. None silently dropped.

Rating requires **evidence**. Read the code the finding points at before judging it. "False
positive" means *you read it and the agent is wrong*, not that it feels off. A rejection with
no evidence is worse than the false positive it claims to remove.

Finding cites a rule ID and you rate it 🤔 or ❌ → open the rule, quote it, and show from the code
why it doesn't apply here. "Adds nothing" or "churn" is not evidence.

Findings that contradict each other (one fix needs code another wants deleted) → settle them
before rating either ✅. The fix for the root defect wins.

Verdicts:

| Verdict | Meaning |
|---|---|
| ✅ valid | Real. Fix it. |
| ⬇️ valid, lower | Real but over-rated severity. Say the true tier. |
| 🤔 valid, not worth | Real, cost > benefit here. Say why (scope, churn, deliberate trade-off). |
| ❌ false positive | Verified wrong. Cite what you read that disproves it — file:line. |
| 🔁 duplicate | Same defect as another finding. Point at the survivor. |
| 🔒 by design | Contradicts a decision the user locked. Name the decision. |

Output shape:

```
### magento-agent-toolkit:magento-reviewer
✅ src/Model/Foo.php:42 §5.2 — exception caught+thrown same fn. Real, split it.
❌ src/Model/Foo.php:88 §4.4 — claims plugin holds state. `$this->cache` is ctor-assigned + never written (L12, L88). Stateless.
🤔 src/Block/Bar.php:15 §C-style — promotion refactor. Untouched by this change, skip.

### magento-agent-toolkit:magento-test-reviewer
✅ src/Model/Foo.php:67 §T-cov — empty-batch branch uncovered. Real gap.
✅ Test/Unit/FooTest.php:55 §U-mock-tauto — asserts only the stub's return. Real, delete it.
⬇️ Test/FooTest.php:30 §T-perf — count: 50 fixture. Real but 🔵 not 🟡, suite cost is trivial here.

verdict: 3 to fix, 1 gap to cover, 1 deferred, 1 rejected.
```

Then **stop**. List proposed changes, ask which to apply.

**No edits without explicit user confirmation.** Not the "obvious" one-liners, not the typos,
not while you're in the file anyway. The review is the deliverable; fixing is a separate ask.

## Notes

- Neither subagent edits — both are read-only by design. The no-edit rule here is about *you*.
- Agent findings are input, not verdicts. Cross-check before repeating them to the user.
- Subagent output is already compressed — relay the rated result, never paste raw agent dumps.
