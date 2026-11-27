#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$repo_root"

shellcheck scripts/dev/agent-call-pi.sh scripts/dev/check-agent-call-pi.sh
python3 -m py_compile \
  scripts/dev/pi_harness.py \
  scripts/dev/pi-sandbox.py \
  scripts/dev/test_pi_harness.py
node --check scripts/dev/pi-broker.mjs
node --test scripts/dev/test-pi-broker.mjs
python3 scripts/dev/test_pi_harness.py
python3 - <<'PY'
from pathlib import Path
import json

root = Path.cwd()
policy = json.loads((root / "scripts/dev/pi-harness-policy.json").read_text())
sandbox = (root / "scripts/dev/pi-sandbox.py").read_text()
assert policy["cli_policy"] == "current-with-capability-probes"
assert not any(key in policy for key in ("pi_version", "runtime_sha256", "node_sha256"))
assert policy["status"] == "candidate-only"
assert policy["provider"] == "openai-codex"
assert policy["models"] == ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-6.1-sol"]
assert "if config['role'] == 'contributor' else 'read,grep,ls'" in sandbox
assert "read,bash,edit,write,grep,find,ls" not in sandbox

sections = []
for runtime in ('.codex', '.agents', '.claude'):
    skill = root / runtime / 'skills/cross-harness-workflow'
    assert 'Muse/Pi/Copilot calls' in (skill / 'SKILL.md').read_text()
    assert 'Pi is not part of the default council roster' in (skill / 'references/council-planning.md').read_text()
    direct = (skill / 'references/direct-collaboration.md').read_text()
    section = direct.split('## Direct Pi Candidate Call\n', 1)[1].split('\n## ', 1)[0]
    assert 'scripts/dev/agent-call-pi.sh' in section
    assert (skill / 'references/../../../../docs/pi-harness-candidate.md').resolve().is_file()
    sections.append(section)
assert len(set(sections)) == 1, 'Pi contract mirror drift'
print('Pi candidate registry and mirrored routing contracts passed')
PY
