"""Provider-free regressions for Muse outer namespace admission."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HARNESS = Path(__file__).resolve().parent


class BackendSelectionTests(unittest.TestCase):
    def select(self, requested, bundled, system):
        helpers = (HARNESS / "check-muse-linux-sandbox.sh").read_text().split(
            "\nroot=$(git rev-parse --show-toplevel)", 1
        )[0]
        return subprocess.run(
            ["bash", "-c", helpers + '\nselect_outer_backend "$@"\n'
             'printf "%s %s" "$status" "$outer_backend_selected"',
             "test", requested, bundled, system],
            capture_output=True, text=True, check=False,
        )

    def test_all_namespace_outcomes(self):
        for bundled in ("ok", "denied", "failed"):
            for system in ("ok", "denied", "failed", "absent"):
                for request in ("auto", "0", "1"):
                    with self.subTest(bundled=bundled, system=system, request=request):
                        selected = "system_bwrap" if request == "1" or (
                            request == "auto" and bundled != "ok" and system == "ok"
                        ) else "muse_bundled_bwrap"
                        usable = system == "ok" if selected == "system_bwrap" else bundled == "ok"
                        status = "ready" if usable else (
                            "blocked_no_usable_outer_backend" if bundled != "ok" and system != "ok"
                            else "blocked_selected_outer_backend"
                        )
                        result = self.select(request, bundled, system)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout, f"{status} {selected}")

    def test_invalid_override_fails_closed(self):
        for request in ("", "yes", "2", "AUTO"):
            with self.subTest(request=request):
                result = self.select(request, "ok", "ok")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("MUSE_OUTER_BWRAP_SYSTEM must be", result.stderr)


class WrapperAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="muse-sandbox-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.scripts = self.root / "scripts/dev"
        self.scripts.mkdir(parents=True)
        shutil.copy2(HARNESS / "agent-call-muse.sh", self.scripts)
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.root), "LANG": "C.UTF-8"}

    def run_wrapper(self, report, effort="max"):
        (self.root / "report.json").write_text(json.dumps(report))
        preflight = self.scripts / "check-muse-linux-sandbox.sh"
        preflight.write_text('#!/bin/sh\ncat report.json\n')
        preflight.chmod(0o700)
        return subprocess.run(
            [str(self.scripts / "agent-call-muse.sh"), "--target-class", "public",
             "--model", "muse-spark-1.3-contributor", "--effort", effort],
            cwd=self.root, env=self.env, input="Sandbox regression fixture\n",
            text=True, capture_output=True, timeout=15, check=False,
        )

    def test_blocked_preflight_stops_before_credentials_and_cleans_run(self):
        for status in ("blocked_selected_outer_backend", "blocked_no_usable_outer_backend"):
            for effort in ("low", "high", "xhigh", "max"):
                with self.subTest(status=status, effort=effort):
                    result = self.run_wrapper({
                        "status": status, "capability_probe": "ok",
                        "outer_backend_selected": "muse_bundled_bwrap",
                        "namespace_probe": {"bundled": "denied", "system_bwrap": "ok"},
                    }, effort)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("sandbox unavailable before provider startup", result.stderr)
                    self.assertNotIn("auth file", result.stderr)
                    self.assertEqual(list((self.root / "tmp/codex-claude/calls").iterdir()), [])

    def test_ready_requires_matching_successful_probe(self):
        for selected, probes in (
            ("unknown", {"bundled": "ok", "system_bwrap": "ok"}),
            ("muse_bundled_bwrap", {"bundled": "denied", "system_bwrap": "ok"}),
            ("system_bwrap", {"bundled": "ok", "system_bwrap": "absent"}),
            ("system_bwrap", {}),
        ):
            with self.subTest(selected=selected, probes=probes):
                result = self.run_wrapper({"status": "ready", "capability_probe": "ok",
                                           "outer_backend_selected": selected, "namespace_probe": probes})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("sandbox unavailable before provider startup", result.stderr)


if __name__ == "__main__":
    unittest.main()
