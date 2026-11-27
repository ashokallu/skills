<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (Muse adapter boundary) -->

# Tmux Persistent Harness Sessions

Use tmux in one of two explicit modes:

- durable transport around a repository-owned headless wrapper; or
- a private, user-observable raw-TUI transport for a capability-proven Codex
  Desktop headed session.

Tmux keeps the process alive and supplies exact session/pane addressing. The
selected mode's wrapper or collaborator specialist still owns authentication,
permissions, model selection, logical-session identity, and result readback.

## Boundaries

- This lane is additive. Choose headed or headless through
  `direct-collaboration.md` first, then select exactly one mode here.
- Prefer a direct wrapper call for bounded work that the current parent can
  supervise to completion.
- Use tmux when the call must survive a terminal closing, the user wants to
  navigate other Codex tasks during control, or exact pane addressing is
  required. Direct right-panel launch is the simpler headed default otherwise.
- Do not launch raw Claude, Codex, AGY, Grok, Muse, or Copilot TUIs merely
  because tmux is available. Raw TUI is allowed only when an explicit Codex
  Desktop headed request selects it and the tool/runtime path is currently
  proven. Grok is the general Linux candidate. For Muse, use
  `muse-work-orchestration.md` as the canonical capability, one-writer, and TUI
  transaction boundary. AGY raw tmux and non-Linux paths remain `Pending
  Verification` and fail closed.
  Muse's TUI may repaint continuously or acknowledge a paste late. Never press
  Enter until the exact composer text is visibly present once, never bypass a
  stale-input rejection, and use only one Ctrl+C to interrupt because a second
  can quit the TUI. Move automation to the guarded headless wrapper.
- Keep identities separate:
  - Codex task/thread: user-visible work ownership
  - tmux session: operating-system process and terminal lifetime
  - tmux pane: exact input/output target
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
4. In wrapper mode, keep prompt text in a prompt file and context in wrapper
   `--context-file` arguments. In raw-TUI mode, use only the stdin buffer
   transaction below; never create a prompt file. Neither mode interpolates
   prompt contents into a shell command.
5. In wrapper mode, use a wrapper session alias or lane for continuation. In
   raw-TUI mode, bind the collaborator's logical session independently. The
   tmux session name substitutes for neither identity.
6. Give the user the exact attach command after either mode starts. Give the
   broad capture command only for wrapper mode; raw-TUI capture remains minimal
   and ephemeral under its prompt transaction.

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

## Headed Shared Raw TUI

Use this mode only for an explicit headed request when navigation,
persistence, or exact pane control is expected. First use the installed
task-terminal contract to create and bind a fresh empty right-side shell. Start
tmux and the collaborator visibly from that shell with no user prompt in argv,
shell history, environment variables, or files; do not create a detached hidden
collaborator first.

Run the setup and later raw-TUI transaction commands in one shell so the exact
private socket, session, target, and buffer identities remain bound throughout.

```bash
tmux_root="${XDG_RUNTIME_DIR:-/tmp/agent-tmux-${UID}}"
mkdir -p "$tmux_root"
chmod 700 "$tmux_root"
tmux_socket="$tmux_root/control.sock"
repo_root="$(git rev-parse --show-toplevel)"
session="grok-x-research"
target="${session}:0.0"

if tmux -S "$tmux_socket" has-session -t "$session" 2>/dev/null; then
  echo "tmux session already exists: $session" >&2
  exit 1
fi

tmux -S "$tmux_socket" -f /dev/null new-session \
  -s "$session" -n harness -c "$repo_root" grok
```

Bind one collision-checked identity chain before attachment or input:

```text
Codex task/thread -> private socket -> tmux session -> pane ->
harness PID/process group/start identity/TTY/cwd -> logical session
```

Inspect the pane identity rather than trusting the session name or command
alone:

```bash
tmux -S "$tmux_socket" list-panes -t "$session" \
  -F '#{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_tty} #{pane_current_command}'
```

The user stages and submits this tmux launch command in the already-bound
right-side shell while Codex observes the identity transition. The automated
bare-executable exception does not extend to tmux or another shell command.
After launch, require the intended pane to be visibly attached before any
prompt work. If later reattachment is needed, use:

```bash
tmux -S "$tmux_socket" attach-session -t "$session"
```

Verify the task, empty Codex composer, right-side shell, socket, session, pane,
and harness identity before accepting the attachment. Once attached, ongoing
prompt control targets the exact pane; navigation elsewhere in Codex no longer
changes that input target. Interaction with the same pane still invalidates
agent control.

### Raw-TUI Prompt Transaction

This transaction is for fully visible, single-line, non-sensitive prompt text.
Start `load-buffer` with stdin open, then provide the prompt through the shell
executor's stdin channel. Never interpolate the prompt into a command, argv,
shell history, environment variable, or file:

```bash
buffer="${session}-prompt-<nonce>"
tmux -S "$tmux_socket" load-buffer -b "$buffer" -
```

After stdin closes successfully, paste into the exact pane and delete the
private buffer in the same operation:

```bash
tmux -S "$tmux_socket" paste-buffer -d -b "$buffer" -t "$target"
```

Capture only the smallest in-memory pane region that can show the complete
staged prompt. Do not redirect it to a file or retain secret-bearing TUI output:

```bash
tmux -S "$tmux_socket" capture-pane -p -J -t "$target" -S -20
```

Require the exact complete prompt, expected TUI state, deleted buffer, and the
unchanged task/socket/session/pane/harness identity chain. If the user interacts
with the same pane or content/state changes unexpectedly, stop before further
input; do not race, clean up, reconcile, or resend. User navigation elsewhere
in Codex does not invalidate the exact pane.

Send Enter only after every stage and identity latch passes:

```bash
tmux -S "$tmux_socket" send-keys -t "$target" Enter
```

Then require exact prompt acknowledgement and response readback from the same
logical collaborator session through `direct-collaboration.md`. Pane text alone
is not acknowledgement. Never reuse a session or process because its name or
command merely looks right.

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
| AGY | `scripts/dev/agent-call-agy.sh` |
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

For wrapper mode, provide both commands after launch:

```bash
tmux -S "$tmux_socket" attach-session -t "$session"
tmux -S "$tmux_socket" capture-pane -p -J -t "$target" -S -200
```

Detach with `Ctrl+b d`. Attaching transfers terminal focus; it does not transfer
task ownership.

For raw-TUI mode, use the attach command but retain only the smallest ephemeral
capture required by the prompt transaction. Do not run the broad `-S -200`
capture against conversation output.

For supervision:

- poll wrapper panes at a bounded interval and deadline; for raw TUI, prefer
  the collaborator's logical-session events and use only bounded minimal pane
  reads for state
- in wrapper mode, use the requested output path as the authoritative result;
  in raw-TUI mode, use same-lineage logical-session acknowledgement/readback
- inspect the pane only for progress, prompts, failures, and exit status
- do not treat text merely appearing in the pane as proof that Enter submitted
  it
- do not infer success from a shell prompt alone
- if a confirmation appears, stop and apply the owning workflow's authority
  boundary; never auto-accept it

The parent must consume and report the terminal result. A detached tmux session
or background watcher does not wake the parent automatically.

## Cleanup And Recovery

In wrapper mode, capture final output and confirm the wrapper artifact before
cleanup:

```bash
tmux -S "$tmux_socket" capture-pane -p -J -t "$target" -S - > \
  "tmp/codex-claude/calls/${session}-pane.log"
tmux -S "$tmux_socket" kill-session -t "$session"
```

In raw-TUI mode, do not persist a final pane capture. Confirm the intended
logical-session response and exact tmux identity in memory, then either keep
the interactive session for follow-up or kill only that completed session.

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
