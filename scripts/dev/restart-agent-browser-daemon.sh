#!/usr/bin/env bash
set -euo pipefail

# agent-browser runs a long-lived Node daemon. Some global options (notably
# AGENT_BROWSER_EXECUTABLE_PATH) are read only when the daemon starts.
#
# This helper force-restarts the daemon so new settings (and trust store changes)
# take effect.

if command -v agent-browser >/dev/null 2>&1; then
	# Best effort: close any session browser first.
	agent-browser close >/dev/null 2>&1 || true
fi

# Kill the daemon (safe match: agent-browser dist/daemon.js)
pkill -f 'agent-browser.*/dist/daemon\.js' >/dev/null 2>&1 || true

# Remove any stale session files (socket/PID/port) that can confuse subsequent runs.
# The daemon normally cleans these up, but if it crashes or is SIGKILL'ed they can linger.
rm -f /tmp/agent-browser-*.sock /tmp/agent-browser-*.pid /tmp/agent-browser-*.port /tmp/agent-browser-*.streamport >/dev/null 2>&1 || true

# Newer agent-browser versions store daemon files under ~/.agent-browser instead of /tmp.
if [[ -d "${HOME}/.agent-browser" ]]; then
	rm -f "${HOME}/.agent-browser"/agent-browser-*.sock \
		"${HOME}/.agent-browser"/agent-browser-*.pid \
		"${HOME}/.agent-browser"/agent-browser-*.port \
		"${HOME}/.agent-browser"/agent-browser-*.streamport >/dev/null 2>&1 || true
fi

echo "agent-browser daemon restarted"
