#!/usr/bin/env python3
"""Deny a narrow, explicit set of catastrophic agent shell commands.

This is a defense-in-depth hook, not a shell-security boundary. It classifies
the command text supplied by Codex, Claude, Antigravity, or Grok. It does not
inspect referenced script files and does not promise coverage for aliases,
generated commands, arbitrary variable expansion, or alternate interpreters.
Hook bootstrap failures and timeouts may fail open in the calling harness and
must be reported as degraded protection.

The shared classifier allows forced ``git clean`` dry-runs. Claude and Grok can
still reject those commands earlier through the intentionally retained
``Bash(git clean -f*)`` permission deny. Their native allow smoke therefore
uses ``git clean -nd``; do not remove the stronger permission rule to make a
hook-level fixture pass.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from typing import Any, Iterable


SHELL_TOOLS = {
    "bash",
    "shell",
    "terminal",
    "run_command",
    "run_shell_command",
    "run_terminal_command",
}
TEST_SENTINEL = "destructive-guard-deny"
CONTROL_TOKENS = {";", "&&", "||", "|", "&", "(", ")"}
SUDO_SHORT_OPTIONS_WITH_ARGUMENT = frozenset("CDghpRrtTUu")
SUDO_LONG_OPTIONS_WITH_ARGUMENT = {
    "--chdir",
    "--chroot",
    "--close-from",
    "--command-timeout",
    "--group",
    "--host",
    "--other-user",
    "--prompt",
    "--role",
    "--type",
    "--user",
}
ENV_SHORT_OPTIONS_WITH_ARGUMENT = frozenset("CSu")
ENV_LONG_OPTIONS_WITH_ARGUMENT = {
    "--chdir",
    "--split-string",
    "--unset",
}


def decision(runtime: str, reason: str) -> dict[str, Any]:
    """Return the runtime-specific deny response around the shared decision."""

    if runtime in {"codex", "claude"}:
        return {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }}
    return {"decision": "deny", "reason": reason}


def response_runtime(config_runtime: str, payload: dict[str, Any] | None) -> str:
    """Resolve the consumer when Claude and Grok share one settings hook."""

    if config_runtime != "claude-grok":
        return config_runtime
    if os.environ.get("GROK_HOOK_EVENT") or (
        payload is not None and ("toolName" in payload or "hookEventName" in payload)
    ):
        return "grok"
    return "claude"


def emit_deny(runtime: str, reason: str) -> None:
    print(json.dumps(decision(runtime, reason), separators=(",", ":")))


def emit_allow(runtime: str) -> None:
    if runtime == "agy":
        print('{"decision":"allow"}')
    else:
        print("{}")


def nested_mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def extract_payload(payload: dict[str, Any]) -> tuple[str, Any, str | None]:
    """Return normalized tool name, command value, and optional command cwd."""

    tool_call = nested_mapping(payload.get("toolCall"))
    tool_input = nested_mapping(payload.get("tool_input"))
    if not tool_input:
        tool_input = nested_mapping(payload.get("toolInput"))
    if not tool_input:
        tool_input = nested_mapping(tool_call.get("args"))

    tool_name = (
        payload.get("tool_name")
        or payload.get("toolName")
        or tool_call.get("name")
        or ""
    )
    command = (
        tool_input.get("command")
        if "command" in tool_input
        else tool_input.get("CommandLine", tool_input.get("command_line"))
    )
    cwd = payload.get("cwd") or tool_input.get("cwd") or tool_input.get("Cwd")
    return str(tool_name).lower(), command, str(cwd) if cwd else None


def command_segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    tokens = list(lexer)
    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in CONTROL_TOKENS or token.startswith((";", "&", "|")):
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def is_assignment(token: str) -> bool:
    return bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", token))


def wrapper_option_consumption(
    tokens: list[str],
    index: int,
    short_with_argument: frozenset[str],
    long_with_argument: set[str],
) -> int:
    token = tokens[index]
    if token.startswith("--"):
        takes_argument = any(
            long_option_matches(token, option) for option in long_with_argument
        )
        return 1 if "=" in token or not takes_argument else 2

    cluster = token[1:]
    for option_index, option in enumerate(cluster):
        if option in short_with_argument:
            return 1 if cluster[option_index + 1 :] else 2
    return 1


def unwrap_option_wrapper(tokens: list[str], index: int, name: str) -> int:
    if name == "sudo":
        short_with_argument = SUDO_SHORT_OPTIONS_WITH_ARGUMENT
        long_with_argument = SUDO_LONG_OPTIONS_WITH_ARGUMENT
    else:
        short_with_argument = ENV_SHORT_OPTIONS_WITH_ARGUMENT
        long_with_argument = ENV_LONG_OPTIONS_WITH_ARGUMENT

    index += 1
    while index < len(tokens) and tokens[index].startswith("-"):
        if tokens[index] == "--":
            index += 1
            break
        index += wrapper_option_consumption(
            tokens,
            index,
            short_with_argument,
            long_with_argument,
        )
    while index < len(tokens) and is_assignment(tokens[index]):
        index += 1
    return index


def unwrap_command(tokens: list[str]) -> list[str]:
    index = 0
    while index < len(tokens) and is_assignment(tokens[index]):
        index += 1

    while index < len(tokens):
        name = Path(tokens[index]).name
        if name in {"command", "builtin", "nohup"}:
            index += 1
            while index < len(tokens) and tokens[index].startswith("-"):
                index += 1
            continue
        if name in {"sudo", "env"}:
            index = unwrap_option_wrapper(tokens, index, name)
            continue
        break
    return tokens[index:]


def git_action(tokens: list[str]) -> tuple[str, list[str]]:
    for index, token in enumerate(tokens[1:], start=1):
        if token in {"reset", "clean"}:
            return token, tokens[index + 1 :]
    return "", []


def short_options(tokens: Iterable[str]) -> set[str]:
    options: set[str] = set()
    for token in tokens:
        if token.startswith("-") and not token.startswith("--"):
            options.update(token[1:])
    return options


def long_option_matches(token: str, option: str) -> bool:
    name = token.partition("=")[0]
    return len(name) > 2 and name.startswith("--") and option.startswith(name)


def git_clean_is_destructive(args: list[str]) -> bool:
    options = short_options(args)
    forced = "f" in options or "--force" in args
    dry_run = "n" in options or "--dry-run" in args
    return forced and not dry_run


def git_roots(cwd: str | None) -> set[str]:
    roots: set[str] = set()
    run_cwd = Path(cwd).resolve() if cwd else Path.cwd().resolve()
    try:
        top = subprocess.run(
            ["git", "-C", str(run_cwd), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout.strip()
        if top:
            roots.add(str(Path(top).resolve()))

        common = subprocess.run(
            [
                "git",
                "-C",
                str(run_cwd),
                "rev-parse",
                "--path-format=absolute",
                "--git-common-dir",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout.strip()
        if common:
            roots.add(str(Path(common).resolve().parent))
    except (OSError, subprocess.SubprocessError):
        pass
    return roots


def strip_target_suffix(target: str) -> str:
    value = target.strip()
    while value.endswith("/") and value not in {"/", "//"}:
        value = value[:-1]
    if value.endswith("/*"):
        value = value[:-2] or "/"
    return value


def resolve_target(target: str, cwd: str | None) -> Path | None:
    value = strip_target_suffix(target)
    expanded_value = value
    if cwd:
        expanded_value = re.sub(
            r"\$(?:\{PWD\}|PWD)(?=/|$)", str(Path(cwd).resolve()), expanded_value
        )
    expanded = os.path.expandvars(os.path.expanduser(expanded_value))
    try:
        path = Path(expanded)
        base = Path(cwd).resolve() if cwd else Path.cwd().resolve()
        return (path if path.is_absolute() else base / path).resolve()
    except OSError:
        return None


def protected_tmp_roots(cwd: str | None) -> set[Path]:
    return {Path(root).resolve() / "tmp" for root in git_roots(cwd)}


def is_protected_tmp_target(target: str, cwd: str | None) -> bool:
    resolved = resolve_target(target, cwd)
    return resolved is not None and resolved in protected_tmp_roots(cwd)


def dangerous_rm_target(target: str, cwd: str | None) -> bool:
    value = strip_target_suffix(target)
    symbolic = {
        "/",
        "//",
        ".",
        "..",
        "~",
        "$HOME",
        "${HOME}",
        "$PWD",
        "${PWD}",
    }
    if value in symbolic:
        return True

    resolved_path = resolve_target(value, cwd)
    if resolved_path is None:
        return False
    base = Path(cwd).resolve() if cwd else Path.cwd().resolve()
    protected = {
        Path.home().resolve(),
        base,
        *(Path(root) for root in git_roots(cwd)),
        *protected_tmp_roots(cwd),
    }
    return any(
        resolved_path == protected_path or resolved_path in protected_path.parents
        for protected_path in protected
    )


def rm_is_destructive(tokens: list[str], cwd: str | None) -> bool:
    args = tokens[1:]
    options = short_options(args)
    recursive = "r" in options or "R" in options or any(
        long_option_matches(token, "--recursive") for token in args
    )
    remove_directory = "d" in options or any(
        long_option_matches(token, "--dir") for token in args
    )
    if not (recursive or remove_directory):
        return False
    targets = operands(args)
    return any(dangerous_rm_target(target, cwd) for target in targets)


def operands(args: list[str]) -> list[str]:
    return [token for token in args if token == "-" or not token.startswith("-")]


def rmdir_is_destructive(tokens: list[str], cwd: str | None) -> bool:
    args = tokens[1:]
    parents = "p" in short_options(args) or any(
        long_option_matches(token, "--parents") for token in args
    )
    for target in operands(args):
        if is_protected_tmp_target(target, cwd):
            return True
        resolved = resolve_target(target, cwd)
        if parents and resolved is not None and any(
            protected in resolved.parents for protected in protected_tmp_roots(cwd)
        ):
            return True
    return False


def consume_short_mv_option(args: list[str], index: int) -> tuple[int, bool]:
    cluster = args[index][1:]
    for option_index, option in enumerate(cluster):
        if option not in {"S", "t"}:
            continue
        attached = cluster[option_index + 1 :]
        consumed = 1 if attached else 2
        return consumed, option == "t"
    return 1, False


def mv_sources(tokens: list[str]) -> list[str]:
    args = tokens[1:]
    values: list[str] = []
    target_directory = False
    index = 0
    while index < len(args):
        token = args[index]
        if token == "--":
            values.extend(args[index + 1 :])
            break
        if long_option_matches(token, "--target-directory"):
            target_directory = True
            index += 1 if "=" in token else 2
            continue
        if long_option_matches(token, "--suffix"):
            index += 1 if "=" in token else 2
            continue
        if token.startswith("--"):
            index += 1
            continue
        if token.startswith("-") and token != "-":
            consumed, has_target_directory = consume_short_mv_option(args, index)
            target_directory = target_directory or has_target_directory
            index += consumed
            continue
        values.append(token)
        index += 1
    return values if target_directory else values[:-1]


def mv_is_destructive(tokens: list[str], cwd: str | None) -> bool:
    return any(
        is_protected_tmp_target(source, cwd) for source in mv_sources(tokens)
    )


def find_parts(tokens: list[str]) -> tuple[list[str], list[str]]:
    args = tokens[1:]
    index = 0
    while index < len(args):
        token = args[index]
        if token in {"-H", "-L", "-P"} or re.fullmatch(r"-O\d+", token):
            index += 1
            continue
        if token == "-D":
            index += 2
            continue
        if token.startswith("-D") and token != "-D":
            index += 1
            continue
        break

    roots: list[str] = []
    while index < len(args):
        token = args[index]
        if token.startswith("-") or token in {"!", "("}:
            break
        roots.append(token)
        index += 1
    return roots or ["."], args[index:]


FIND_ONE_ARGUMENT_PRIMARIES = {
    "-name",
    "-iname",
    "-path",
    "-ipath",
    "-wholename",
    "-iwholename",
    "-lname",
    "-ilname",
    "-regex",
    "-iregex",
    "-type",
    "-xtype",
    "-user",
    "-group",
    "-uid",
    "-gid",
    "-perm",
    "-size",
    "-inum",
    "-links",
    "-fstype",
    "-samefile",
    "-printf",
    "-fprint",
    "-fls",
}


def find_has_destructive_action(expression: list[str]) -> bool:
    index = 0
    while index < len(expression):
        token = expression[index]
        if token == "-delete":
            return True
        if token in {"-exec", "-execdir"}:
            if (
                index + 1 < len(expression)
                and Path(expression[index + 1]).name == "rm"
            ):
                return True
            index += 2
            while index < len(expression) and expression[index] not in {";", "+"}:
                index += 1
            index += 1
            continue
        if token == "-fprintf":
            index += 3
            continue
        if token in FIND_ONE_ARGUMENT_PRIMARIES or token.startswith("-newer"):
            index += 2
            continue
        index += 1
    return False


def find_is_destructive(tokens: list[str], cwd: str | None) -> bool:
    roots, expression = find_parts(tokens)
    roots_protected = any(
        is_protected_tmp_target(root, cwd) for root in roots
    )
    return roots_protected and find_has_destructive_action(expression)


def segment_reason(tokens: list[str], cwd: str | None) -> str | None:
    command = unwrap_command(tokens)
    if not command:
        return None
    executable = Path(command[0]).name

    if executable == "git":
        action, args = git_action(command)
        if action == "reset" and "--hard" in args:
            return "hard Git reset is blocked by the project command guard"
        if action == "clean" and git_clean_is_destructive(args):
            return "forced Git clean without dry-run is blocked by the project command guard"
    elif executable == "rm" and rm_is_destructive(command, cwd):
        if any(
            is_protected_tmp_target(target, cwd)
            for target in operands(command[1:])
        ):
            return (
                "project tmp root deletion is blocked; "
                "select an explicit owned child path"
            )
        return "broad recursive deletion is blocked by the project command guard"
    elif executable == "rmdir" and rmdir_is_destructive(command, cwd):
        return (
            "project tmp root removal is blocked; "
            "select an explicit owned child path"
        )
    elif executable == "mv" and mv_is_destructive(command, cwd):
        return (
            "project tmp root movement is blocked; "
            "select an explicit owned child path"
        )
    elif executable == "find" and find_is_destructive(command, cwd):
        return (
            "broad project tmp deletion is blocked; "
            "select an explicit owned child path"
        )
    elif executable == "mkfs" or executable.startswith("mkfs."):
        return "filesystem formatting is blocked by the project command guard"
    elif executable == "wipefs":
        return "filesystem signature wiping is blocked by the project command guard"
    elif executable == "dd" and any(
        token.startswith("of=/dev/") or token == "of=/dev" for token in command[1:]
    ):
        return "raw device overwrite is blocked by the project command guard"
    elif executable == "docker":
        for index, token in enumerate(command[1:-1], start=1):
            if token == "system" and command[index + 1] == "prune":
                return "Docker system prune is blocked by the project command guard"
    elif executable == "terraform" and "destroy" in command[1:]:
        return "Terraform destroy is blocked by the project command guard"
    elif executable == "kubectl":
        for index, token in enumerate(command[1:-1], start=1):
            if token == "delete" and command[index + 1] in {
                "namespace",
                "namespaces",
                "ns",
            }:
                return "Kubernetes namespace deletion is blocked by the project command guard"
    return None


def classify(command: str, cwd: str | None = None) -> str | None:
    if os.environ.get("LEARN_DESTRUCTIVE_GUARD_TEST") == "1" and TEST_SENTINEL in command:
        return "harmless destructive-command guard test sentinel was denied"
    try:
        segments = command_segments(command)
    except ValueError:
        return "malformed shell command was denied by the project command guard"
    for segment in segments:
        reason = segment_reason(segment, cwd)
        if reason:
            return reason
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--runtime",
        required=True,
        choices=("codex", "claude-grok", "agy"),
        help="Expected shell-hook adapter; used to fail closed on malformed payloads.",
    )
    return parser.parse_args()


def main() -> None:
    config_runtime = parse_args().runtime
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
        runtime = response_runtime(config_runtime, None)
        emit_deny(runtime, "malformed shell hook payload was denied by the project command guard")
        return

    runtime = response_runtime(
        config_runtime, payload if isinstance(payload, dict) else None
    )
    if not isinstance(payload, dict):
        emit_deny(runtime, "malformed shell hook payload was denied by the project command guard")
        return

    tool_name, command, cwd = extract_payload(payload)
    if tool_name and tool_name not in SHELL_TOOLS:
        emit_allow(runtime)
        return
    if not tool_name or not isinstance(command, str) or not command.strip():
        emit_deny(runtime, "shell hook payload without a command was denied by the project command guard")
        return

    reason = classify(command, cwd)
    if reason:
        emit_deny(runtime, reason)
    else:
        emit_allow(runtime)


if __name__ == "__main__":
    main()
