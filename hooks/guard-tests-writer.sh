#!/usr/bin/env bash
# Blocks magento-tests-writer from running setup:* write commands or touching app/etc/env.php|config.php.
# Plugin agents ignore frontmatter hooks, so the guard lives here and filters on agent_type.
# Checks the whole tool_input of every tool: the agent inherits MCP tools (IDE terminal, SQL) that bypass Bash.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
    agent=$(jq -r '.agent_type // empty' <<<"$input")
    payload=$(jq -c '.tool_input // empty' <<<"$input")
else
    agent=$(grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | sed -E 's/.*"([^"]*)"$/\1/')
    payload=$input
fi

case "$agent" in
    *magento-tests-writer) ;;
    *) exit 0 ;;
esac

if grep -qE 'setup:(install|upgrade|uninstall|config:set|db|store-config|backup|rollback)|app/etc/(env|config)\.php' <<<"$payload"; then
    echo 'Blocked: magento-tests-writer must never run setup:* write commands or touch app/etc/env.php/config.php. Integration suite builds its own sandbox.' >&2
    exit 2
fi

exit 0
