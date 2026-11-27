#!/usr/bin/env python3
"""Restrict Muse's internal bridge to local file tools, without delegation.

The outer filesystem sandbox remains the confinement boundary. This hook is
defence in depth: Muse hook failure semantics must be qualified separately.
"""
import json
import sys

ALLOWED = frozenset(('read_file', 'write_file', 'edit_file', 'search', 'Read', 'Write', 'Edit', 'Grep'))


def allowed(payload):
    return isinstance(payload, dict) and payload.get('tool_name') in ALLOWED


if __name__ == '__main__':
    try:
        payload = json.loads(sys.stdin.read(262145))
        permit = allowed(payload)
    except (ValueError, TypeError):
        permit = False
    if not permit:
        print('The parent owns orchestration. This Muse bridge permits only local file tools; delegation, shell and external tools are denied.', file=sys.stderr)
        raise SystemExit(2)
