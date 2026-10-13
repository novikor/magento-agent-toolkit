# magento-agent-toolkit

Claude Code plugin for Magento 2 / Adobe Commerce development. It adds skills that review code, implement tasks end to end and write PHPUnit tests, plus the subagents those skills delegate to.

## Contents

### Skills

| Skill | What it does |
|---|---|
| `review-magento` | Runs `magento-reviewer` on production code and `magento-test-reviewer` on tests in parallel, then rates every finding with evidence. Applies nothing without your confirmation. |
| `implement-magento-task` | Takes a spec or Jira ticket, plans, implements, gets tests from `magento-tests-writer`, reviews with `review-magento` and auto-applies only obvious, proven fixes. Works in plan mode and auto mode. |
| `magento-integration-tests` | Rules for integration tests with PHP attributes (`#[DataFixture]`, `#[DbIsolation]`, `#[AppArea]`, ...) and parameterized data fixtures, verified against the framework source. |
| `warden-project-agents-md` | Writes or updates a project's `AGENTS.md` and a thin `CLAUDE.md` from the repo's real config. Only for Magento projects on Warden. |

### Subagents

| Agent | What it does |
|---|---|
| `magento-reviewer` | Reviews production code against the Adobe Commerce Technical Guidelines (§1-17) plus an opinionated rule layer (§C). One line per finding, tagged with a rule ID. Read-only. |
| `magento-test-reviewer` | Reviews unit and integration tests: coverage gaps, weak assertions, flaky or dead tests, Magento test-framework mistakes. Read-only. |
| `magento-tests-writer` | Decides per behavior whether a unit test, an integration test, both or none is justified, writes the tests, runs them and iterates until they pass. Never edits production code. |
| `minibuilder` | Cheap Haiku agent for fully specified edits: the task says what to change and how. Refuses anything that needs a decision. |

### Hook

A `PreToolUse` hook stops `magento-tests-writer` from running `bin/magento setup:*` write commands or touching `app/etc/env.php` / `app/etc/config.php`. The integration suite installs its own sandbox, and these commands overwrite the dev store config. The hook does not affect your main session or other agents.

## Opinionated rules

The §C layer in `magento-reviewer` and the house rules in `magento-tests-writer` are the author's own conventions. Examples: descriptive plugin class names instead of a generic `Plugin` suffix, no `final` classes, `@SuppressWarnings("PHPMD.UnusedFormalParameter")` on plugin methods.

Rules in your project's `AGENTS.md` or `CLAUDE.md` take precedence over them.

## Requirements

- Claude Code.
- The [caveman](https://github.com/JuliusBrussee/caveman) plugin. It is a declared dependency: the agents delegate code search and small edits to its `cavecrew-*` subagents.

Optional:

- `warden-dev` skill. `warden-project-agents-md` refuses to run without it. `magento-tests-writer` uses it to run tests in Warden and falls back to the commands in your `AGENTS.md`, `README` or CI config.
- `jq`. The hook uses it to parse its input and falls back to `grep` without it.

## Install

1. Add the caveman marketplace, so the dependency can be installed:

   ```bash
   claude plugin marketplace add JuliusBrussee/caveman
   ```

2. Add this marketplace and install the plugin:

   ```bash
   claude plugin marketplace add novikor/magento-agent-toolkit
   claude plugin install magento-agent-toolkit@novikor
   ```

To register the marketplace for everyone working in a project, run the `marketplace add` commands with `--scope project` inside that project and commit the `.claude/settings.json` they write.

## Use

Everything in the plugin is prefixed with `magento-agent-toolkit:`.

- Skills: `/magento-agent-toolkit:review-magento`, `/magento-agent-toolkit:implement-magento-task`. Claude also invokes them on its own when your request matches, for example "review my diff".
- Agents: mention one explicitly with `@agent-magento-agent-toolkit:magento-tests-writer`.

## Updates

Auto-update is off by default for third-party marketplaces.

- To turn it on: run `/plugin`, open **Marketplaces**, select `novikor`, choose **Enable auto-update**.
- To update manually:

  ```bash
  claude plugin update magento-agent-toolkit@novikor
  ```

The plugin has no version number, so every commit to the default branch is a new release.

## License

MIT
