# Tmux Persistent Harness Sessions

Use tmux as a durable, observable transport around the repository-owned
Claude, Codex CLI, Grok, Muse, and Copilot wrappers. Tmux keeps the
terminal process alive; the selected wrapper or specialist adapter remains
responsible for authentication, permissions, model selection, conversation
identity, timeout, and captured output.

## Boundaries

- This lane is additive. Choose the wrapper and headless call mechanics through
  `direct-collaboration.md` first, then add tmux only when a trigger below
  applies. If none applies, invoke the wrapper directly without asking the user
  to choose a transport.
- Prefer a direct wrapper call for bounded work that the current parent can
  supervise to completion.
- Use tmux when the call must survive a terminal closing, the user wants to
  attach and observe it, or several long calls need isolated terminals.
- Do not launch raw Claude, Codex, Grok, Muse, or Copilot TUIs merely
  because tmux is available. Use the repository wrappers and their prompt,
  context, output, alias, budget, and permission flags. For Muse, use
  `muse-work-orchestration.md` as the canonical capability and TUI boundary.
  Muse's TUI may repaint continuously or acknowledge a paste late. Never press
  Enter until the exact composer text is visibly present once, never bypass a
  stale-input rejection, and use only one Ctrl+C to interrupt because a second
  can quit the TUI. Move automation to the guarded headless wrapper.
- Keep identities separate:
  - tmux session: operating-system process and terminal lifetime
  - wrapper alias: Learn thread or lane ownership
  - harness session or conversation ID: model-side continuation
- Do not use tmux as a replacement for the parent agent's ownership of waits,
  terminal-state readback, or user notification.

## Private Socket

Use one private socket for Learn agent sessions. Never depend on the user's
personal tmux configuration or default server.

```bash
tmux_root="${XDG_RUNTIME_DIR:-/tmp/agent-tmux-${UID}}"
mkdir -p "$tmux_root"
chmod 700 "$tmux_root"
tmux_socket="$tmux_root/control.sock"
tmux -S "$tmux_socket" -f /dev/null list-sessions
```

Treat a failed initial `list-sessions` as "no server yet." Use `-S` for the
socket path consistently. Do not substitute `-L`; `-L` accepts a socket name,
not a filesystem path.

## Session Contract

1. Resolve the repository root and verify the selected wrapper help before
   starting a session.
2. Use a lowercase slug containing the harness and purpose, such as
   `codex-api-review`. Reject spaces and ambiguous reused names.
3. Check for a collision with `has-session` before `new-session`. Reattach or
   choose a new name deliberately; never silently replace a running session.
4. Keep prompt text in a prompt file and context in wrapper `--context-file`
   arguments. Never interpolate prompt contents into a shell command.
5. Use a wrapper session alias or lane for continuation. The tmux session name
   is not a valid substitute.
6. Give the user the exact attach and capture commands immediately after the
   session starts.

```bash
repo_root="$(git rev-parse --show-toplevel)"
session="codex-api-review"
target="${session}:0.0"

if tmux -S "$tmux_socket" has-session -t "$session" 2>/dev/null; then
  echo "tmux session already exists: $session" >&2
else
  tmux -S "$tmux_socket" -f /dev/null new-session \
    -d -s "$session" -n worker -c "$repo_root"
fi
```

Stop if the collision branch runs. Do not submit work to that session until
its ownership is established.

## Safe Wrapper Submission

Construct the command only from explicit arguments. Use shell `%q` escaping,
send literal text, then send Enter separately. Never place secrets or prompt
contents in the command line.

```bash
wrapper_args=(
  scripts/dev/agent-call-codex.sh
  --session-alias api-review
  --prompt-file tmp/codex-claude/prompts/api-review.md
  --output tmp/codex-claude/calls/api-review.md
  --events-output tmp/codex-claude/calls/api-review.events.jsonl
)
printf -v wrapper_command '%q ' "${wrapper_args[@]}"

tmux -S "$tmux_socket" send-keys -t "$target" -l -- "$wrapper_command"
tmux -S "$tmux_socket" send-keys -t "$target" Enter
```

Use the source-confirmed wrapper for the selected harness:

| Harness | Wrapper |
| --- | --- |
| Claude Code | `scripts/dev/agent-call-claude.sh` |
| Codex CLI | `scripts/dev/agent-call-codex.sh` |
| Grok CLI brokered council/contributor | `scripts/dev/agent-call-grok.sh` |
| Muse CLI | `scripts/dev/agent-call-muse.sh` |
| Copilot CLI | `scripts/dev/agent-call-copilot.sh` |

Select permissions, model, effort, role, timeout, continuation, and output
flags from `direct-collaboration.md` and the wrapper's current `--help`; do not
invent them in this lane. Multiple Codex CLI workers require distinct tmux
session names and distinct wrapper aliases or lanes. Never let parallel workers
share a global `latest` or `last` pointer.

For Muse, this lane owns only process lifetime, pane addressing, observation,
and generic cleanup. Use `muse-work-orchestration.md` for role, wrapper,
session, worktree, manifest, writer-release, raw-TUI, and MSP rules.

## Observe And Wait

Always provide both commands after launch:

```bash
tmux -S "$tmux_socket" attach-session -t "$session"
tmux -S "$tmux_socket" capture-pane -p -J -t "$target" -S -200
```

Detach with `Ctrl+b d`. Attaching transfers terminal focus; it does not transfer
task ownership.

For supervision:

- poll `capture-pane` at a bounded interval and deadline
- use the wrapper's requested output path as the authoritative result
- inspect the pane only for progress, prompts, failures, and exit status
- do not treat text merely appearing in the pane as proof that Enter submitted
  it
- do not infer success from a shell prompt alone
- if a confirmation appears, stop and apply the owning workflow's authority
  boundary; never auto-accept it

The parent must consume and report the terminal result. A detached tmux session
or background watcher does not wake the parent automatically.

## Cleanup And Recovery

Capture final output and confirm the wrapper artifact before cleanup:

```bash
tmux -S "$tmux_socket" capture-pane -p -J -t "$target" -S - > \
  "tmp/codex-claude/calls/${session}-pane.log"
tmux -S "$tmux_socket" kill-session -t "$session"
```

- Keep a useful shell open when the user asked for an interactive follow-up.
- Kill only the exact completed session. Never kill the private server while
  unrelated sessions exist.
- List sessions and panes before recovery:

```bash
tmux -S "$tmux_socket" list-sessions
tmux -S "$tmux_socket" list-panes -a \
  -F '#{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}'
```

- After a parent or terminal restart, rediscover the exact tmux session and
  wrapper alias independently. Resume only when both identities match the
  intended thread or lane.

## Imported Design Notes

This lane adapts the private-socket, literal-send, capture, monitor-command,
and bounded-wait ideas from
`mitsuhiko/agent-stuff/skills/tmux` at commit
`c7ff3334747ca0235bbe3b6c9f3e0dd4a8cc4f73` (Apache-2.0 repository).
It deliberately fixes the source's mixed `-S`/`-L` examples and does not use
its socket-unaware wait helper.

Do not import a general tmux agent framework here. Learn's existing wrappers
already own harness permissions, aliases, output artifacts, budgets, and
timeouts; a second orchestration engine would create conflicting truth.
