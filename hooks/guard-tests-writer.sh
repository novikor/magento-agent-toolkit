#!/usr/bin/env bash
# Blocks magento-tests-writer from running setup:* write commands or touching app/etc/env.php|config.php.
# Plugin agents ignore frontmatter hooks, so the guard lives here and filters on agent_type.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
    agent=$(jq -r '.agent_type // empty' <<<"$input")
    command=$(jq -r '.tool_input.command // empty' <<<"$input")
else
    agent=$(grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | sed -E 's/.*"([^"]*)"$/\1/')
    command=$input
fi

case "$agent" in
    *magento-tests-writer) ;;
    *) exit 0 ;;
esac

if grep -qE 'setup:(install|upgrade|uninstall|config:set|db|store-config|backup|rollback)|app/etc/(env|config)\.php' <<<"$command"; then
    echo 'Blocked: magento-tests-writer must never run setup:* write commands or touch app/etc/env.php/config.php. Integration suite builds its own sandbox.' >&2
    exit 2
fi

exit 0
