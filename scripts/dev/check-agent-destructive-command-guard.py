#!/usr/bin/env python3
"""Deterministic contract checks for agent-destructive-command-guard.py."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / "scripts/dev/agent-destructive-command-guard.py"


def payload(adapter: str, command: str, tool: str | None = None) -> dict[str, Any]:
    runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
    if runtime == "codex":
        return {"tool_name": tool or "Bash", "tool_input": {"command": command}}
    if adapter == "claude":
        return {"tool_name": tool or "Bash", "tool_input": {"command": command}}
    if adapter == "grok":
        return {"toolName": tool or "Bash", "toolInput": {"command": command}}
    return {
        "workspacePaths": [str(ROOT)],
        "toolCall": {
            "name": tool or "run_command",
            "args": {"CommandLine": command},
        }
    }


def run_guard(
    runtime: str,
    body: dict[str, Any] | str,
    *,
    test_mode: bool = False,
    grok_event: bool = False,
) -> dict[str, Any]:
    env = os.environ.copy()
    if test_mode:
        env["LEARN_DESTRUCTIVE_GUARD_TEST"] = "1"
    if grok_event:
        env["GROK_HOOK_EVENT"] = "PreToolUse"
    encoded = body if isinstance(body, str) else json.dumps(body)
    result = subprocess.run(
        [sys.executable, str(GUARD), "--runtime", runtime],
        input=encoded,
        text=True,
        capture_output=True,
        check=True,
        cwd=ROOT,
        env=env,
        timeout=5,
    )
    return json.loads(result.stdout)


def assert_denied_result(adapter: str, result: dict[str, Any]) -> None:
    if adapter in {"codex", "claude"}:
        hook = result.get("hookSpecificOutput", {})
        assert hook.get("permissionDecision") == "deny", (adapter, result)
        assert "decision" not in result, (adapter, result)
    else:
        assert result.get("decision") == "deny", (adapter, result)
        assert "hookSpecificOutput" not in result, (adapter, result)


def assert_denied(adapter: str, command: str) -> None:
    runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
    result = run_guard(runtime, payload(adapter, command))
    assert_denied_result(adapter, result)


def assert_allowed(adapter: str, command: str) -> None:
    runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
    result = run_guard(runtime, payload(adapter, command))
    expected = {"decision": "allow"} if adapter == "agy" else {}
    assert result == expected, (adapter, command, result)


def set_payload_cwd(body: dict[str, Any], adapter: str, cwd: Path) -> None:
    if adapter in {"codex", "claude"}:
        body["tool_input"]["cwd"] = str(cwd)
    elif adapter == "grok":
        body["toolInput"]["cwd"] = str(cwd)
    else:
        body["toolCall"]["args"]["Cwd"] = str(cwd)


def main() -> None:
    home = str(Path.home().resolve())
    root = str(ROOT.resolve())
    denied = [
        "git reset --hard HEAD~1",
        "git clean -fd",
        "git clean --force -d",
        "printf ok && git clean -xdf",
        "rm -rf /",
        "rm -fr /*",
        "rm --recursive --force --no-preserve-root /",
        "rm -r -f .",
        "rm -rf ..",
        "rm -rf ~",
        "rm -rf $HOME",
        "rm -rf ${HOME}/",
        "rm -rf $PWD",
        "rm -rf ./../..",
        f"rm -rf {home}",
        f"rm -rf {root}/*",
        "rm -rf tmp/",
        "rm -r tmp",
        "rm --recursive tmp/",
        "rm --recurs tmp/",
        "rm -d tmp",
        "rm -rf ./tmp/",
        "rm -rf $PWD/tmp",
        "rm -rf tmp/*",
        f"rm -rf {root}/tmp",
        "rmdir tmp",
        "rmdir ./tmp/",
        f"rmdir {root}/tmp",
        "rmdir -p tmp/owned-empty-directory",
        "rmdir --parents tmp/owned-empty-directory",
        "rmdir --parent tmp/owned-empty-directory",
        "mv tmp /tmp/project-tmp",
        "mv ./tmp/ /tmp/project-tmp",
        f"mv {root}/tmp /tmp/project-tmp",
        "mv --target-directory=/tmp tmp",
        "mv --target=/tmp tmp",
        "mv --t /tmp tmp",
        "mv -t /tmp tmp",
        "mv -vt /tmp tmp",
        "mv -t/tmp tmp",
        "mv -vt/tmp tmp",
        "find tmp -delete",
        "find tmp -mindepth 1 -delete",
        "find ./tmp/ -depth -delete",
        "find -H tmp -delete",
        "find -L tmp -delete",
        "find -P tmp -delete",
        "find -O2 tmp -delete",
        "find -D search tmp -delete",
        "find tmp -exec rm -rf {} +",
        "find tmp -execdir /bin/rm -rf {} +",
        "sudo -u root rm -rf tmp/",
        "sudo --user=root rm --recurs tmp/",
        f"sudo -D {root} rmdir tmp",
        f"env -C {root} rm -rf tmp/",
        f"env --chdir={root} mv tmp /tmp/project-tmp",
        f"sudo -uroot env -C{root} rm -rf tmp/",
        "mkfs.ext4 /dev/loop0",
        "wipefs --all /dev/loop0",
        "dd if=/dev/zero of=/dev/sda bs=1M",
        "docker system prune -af",
        "docker --context local system prune -af",
        "terraform destroy -auto-approve",
        "terraform -chdir=infrastructure destroy -auto-approve",
        "kubectl delete namespace production",
        "kubectl --context production delete ns production",
    ]
    allowed = [
        "printf 'ordinary-allow\\n'",
        "printf '%s\\n' 'rm -rf /'",
        "git reset --soft HEAD~1",
        "git reset --mixed HEAD~1",
        "git clean -nd",
        "git clean -fdn",
        "git clean -f -n -d",
        "git clean -nf",
        "git clean -fn",
        "git clean -xfdn",
        "git clean --force --dry-run -d",
        "rm -rf tmp/owned-guard-fixture",
        "rm -r tmp/owned-guard-fixture",
        "rm --recurs tmp/owned-guard-fixture",
        "rm -rf tmp/owned-guard-fixture/*",
        "rmdir tmp/owned-empty-directory",
        "mv tmp/owned-guard-fixture /tmp/owned-guard-fixture",
        "mv --target-directory=/tmp tmp/owned-guard-fixture",
        "mv --target=/tmp tmp/owned-guard-fixture",
        "mv --suff tmp --target=/tmp tmp/owned-guard-fixture",
        "find tmp -type f",
        "find -H tmp -name -delete",
        "find tmp/owned-guard-fixture -delete",
        "find tmp/owned-guard-fixture -exec rm -rf {} +",
        "sudo -u root rm -rf tmp/owned-guard-fixture",
        f"env -C {root} rm -rf tmp/owned-guard-fixture",
        f"sudo -uroot env -C{root} rm -rf tmp/owned-guard-fixture",
        "dd if=/dev/zero of=tmp/disk.img bs=1 count=0",
        "docker system df",
        "terraform plan",
        "kubectl get namespace",
    ]

    for adapter in ("codex", "claude", "grok", "agy"):
        runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
        for command in denied:
            assert_denied(adapter, command)
        for command in allowed:
            assert_allowed(adapter, command)

        sentinel = run_guard(
            runtime,
            payload(adapter, f"printf '{'destructive-guard-deny'}\\n'"),
            test_mode=True,
        )
        assert_denied_result(adapter, sentinel)

        malformed = run_guard(runtime, "{", grok_event=adapter == "grok")
        assert_denied_result(adapter, malformed)

        malformed_command = run_guard(runtime, payload(adapter, "printf 'unterminated"))
        assert_denied_result(adapter, malformed_command)

        missing_command = run_guard(runtime, payload(adapter, "") | {
            "tool_input": {},
            "toolInput": {},
            "toolCall": {"name": "run_command", "args": {}},
        })
        assert_denied_result(adapter, missing_command)

        non_shell = run_guard(runtime, payload(adapter, "rm -rf /", tool="Read"))
        expected = {"decision": "allow"} if adapter == "agy" else {}
        assert non_shell == expected, (adapter, non_shell)

        nested_cwd = payload(adapter, "rm -rf ./..")
        nested_cwd["cwd"] = str(ROOT / "backend")
        assert_denied_result(adapter, run_guard(runtime, nested_cwd))

        nested_ancestor = payload(adapter, "rm -rf ./../..")
        command_cwd = str(ROOT / "backend" / "internal" / "shared")
        if adapter in {"codex", "claude"}:
            nested_ancestor["tool_input"]["cwd"] = command_cwd
        elif adapter == "grok":
            nested_ancestor["toolInput"]["cwd"] = command_cwd
        else:
            nested_ancestor["toolCall"]["args"]["Cwd"] = command_cwd
        assert_denied_result(adapter, run_guard(runtime, nested_ancestor))

        nested_tmp = payload(adapter, "rm -rf ../tmp")
        set_payload_cwd(nested_tmp, adapter, ROOT / "backend")
        assert_denied_result(adapter, run_guard(runtime, nested_tmp))

    with tempfile.TemporaryDirectory(prefix="tmp-guard-") as temporary:
        fixture_root = Path(temporary)
        worktree_root = fixture_root / "worktree"
        common_directory = fixture_root / "common.git"
        subprocess.run(
            [
                "git",
                "init",
                "--quiet",
                "--separate-git-dir",
                str(common_directory),
                str(worktree_root),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        protected_roots = (worktree_root / "tmp", fixture_root / "tmp")
        for adapter in ("codex", "claude", "grok", "agy"):
            runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
            for protected_root in protected_roots:
                root_body = payload(adapter, f"rm -rf {protected_root}")
                set_payload_cwd(root_body, adapter, worktree_root)
                assert_denied_result(adapter, run_guard(runtime, root_body))

                child_body = payload(
                    adapter,
                    f"rm -rf {protected_root / 'owned-guard-fixture'}",
                )
                set_payload_cwd(child_body, adapter, worktree_root)
                expected = {"decision": "allow"} if adapter == "agy" else {}
                assert run_guard(runtime, child_body) == expected, (
                    adapter,
                    protected_root,
                )

    schema_variants = [
        ("codex", {"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}),
        ("claude", {"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}),
        ("grok", {"toolName": "Bash", "toolInput": {"command": "rm -rf /"}}),
        (
            "grok",
            {
                "toolName": "run_terminal_command",
                "toolInput": {"command": "rm -rf /"},
            },
        ),
        ("agy", {"toolCall": {"name": "run_command", "args": {"CommandLine": "rm -rf /"}}}),
        ("agy", {"toolCall": {"name": "run_command", "args": {"command_line": "rm -rf /"}}}),
    ]
    for adapter, body in schema_variants:
        runtime = "claude-grok" if adapter in {"claude", "grok"} else adapter
        result = run_guard(runtime, body)
        assert_denied_result(adapter, result)

    codex_hooks = json.loads((ROOT / ".codex/hooks.json").read_text())[
        "hooks"
    ]["PreToolUse"]
    claude_hooks = json.loads((ROOT / ".claude/settings.json").read_text())[
        "hooks"
    ]["PreToolUse"]
    agy_hooks = json.loads(
        (ROOT / ".agents/plugins/project/hooks.json").read_text()
    )["destructive-command-guard"]["PreToolUse"]
    registrations = (
        ("codex", codex_hooks, "Bash", "--runtime codex"),
        ("claude-grok", claude_hooks, "Bash", "--runtime claude-grok"),
        (
            "agy",
            agy_hooks,
            "run_command",
            "scripts/agent-destructive-command-guard.py",
        ),
    )
    for runtime, hooks, matcher, marker in registrations:
        assert any(
            entry.get("matcher") == matcher
            and any(
                marker in hook.get("command", "")
                for hook in entry.get("hooks", [])
            )
            for entry in hooks
        ), (runtime, matcher, marker)

    agy_bootstrap = (
        ROOT
        / ".agents/plugins/project/scripts/agent-destructive-command-guard.py"
    )
    bootstrap_result = subprocess.run(
        [sys.executable, str(agy_bootstrap)],
        input=json.dumps(payload("agy", "git reset --hard HEAD")),
        text=True,
        capture_output=True,
        check=True,
        cwd=agy_bootstrap.parent.parent,
        timeout=10,
    )
    assert_denied_result("agy", json.loads(bootstrap_result.stdout))

    bootstrap_without_workspace = payload(
        "agy", f"rm -rf {ROOT.resolve()}"
    )
    bootstrap_without_workspace["workspacePaths"] = []
    bootstrap_env = os.environ.copy()
    bootstrap_env["PWD"] = str(ROOT)
    bootstrap_fallback_result = subprocess.run(
        [sys.executable, str(agy_bootstrap)],
        input=json.dumps(bootstrap_without_workspace),
        text=True,
        capture_output=True,
        check=True,
        cwd=agy_bootstrap.parent.parent,
        env=bootstrap_env,
        timeout=10,
    )
    assert_denied_result("agy", json.loads(bootstrap_fallback_result.stdout))

    bootstrap_command_cwd = payload("agy", "rm -rf ./..")
    bootstrap_command_cwd["workspacePaths"] = []
    bootstrap_command_cwd["toolCall"]["args"]["Cwd"] = str(ROOT / "backend")
    bootstrap_command_cwd_result = subprocess.run(
        [sys.executable, str(agy_bootstrap)],
        input=json.dumps(bootstrap_command_cwd),
        text=True,
        capture_output=True,
        check=True,
        cwd=agy_bootstrap.parent.parent,
        env=bootstrap_env,
        timeout=10,
    )
    assert_denied_result("agy", json.loads(bootstrap_command_cwd_result.stdout))

    bootstrap_allow = subprocess.run(
        [sys.executable, str(agy_bootstrap)],
        input=json.dumps(payload("agy", "printf 'ok\\n'")),
        text=True,
        capture_output=True,
        check=True,
        cwd=agy_bootstrap.parent.parent,
        timeout=10,
    )
    assert json.loads(bootstrap_allow.stdout) == {"decision": "allow"}

    print("agent destructive command guard checks passed")


if __name__ == "__main__":
    main()
