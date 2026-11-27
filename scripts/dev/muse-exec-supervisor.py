#!/usr/bin/env python3
"""Own one Muse process tree, including descendants that create new sessions.

Credential bytes travel only through inherited stdin. The receipt contains no
command, output, environment or credential data. Linux subreaping prevents an
exiting intermediate wrapper from orphaning work outside our ownership tree.
"""
import argparse
import ctypes
import json
import os
import signal
import subprocess
import time


def descendants():
    parents = {}
    for entry in os.scandir('/proc'):
        if not entry.name.isdecimal():
            continue
        try:
            fields = open(entry.path + '/stat').read().rsplit(')', 1)[1].split()
            parents[int(entry.name)] = (int(fields[1]), fields[19])
        except (OSError, ValueError, IndexError):
            continue
    owned = {os.getpid()}
    for _ in range(128):
        added = {pid for pid, (parent, _) in parents.items() if parent in owned} - owned
        if not added:
            break
        owned.update(added)
    return {pid: parents[pid][1] for pid in owned if pid != os.getpid()}


def signal_owned(sig):
    for pid, born in descendants().items():
        try:
            fields = open(f'/proc/{pid}/stat').read().rsplit(')', 1)[1].split()
            if fields[19] == born:
                os.kill(pid, sig)
        except (ProcessLookupError, FileNotFoundError):
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--deadline', type=float, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or not 0 < args.deadline <= 3600:
        parser.error('bounded deadline and command required')
    receipt_fd = os.open(args.receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), 'subreaper unavailable')
    stopping = [False]
    def stop(_sig, _frame):
        stopping[0] = True
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    child = subprocess.Popen(command, start_new_session=True)
    deadline = time.monotonic() + args.deadline
    child_status = None
    stop_at = None
    escalated = False
    while True:
        no_children = False
        while True:
            try:
                pid, status = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                no_children = True
                break
            except InterruptedError:
                continue
            if pid == 0:
                break
            if pid == child.pid:
                child_status = os.waitstatus_to_exitcode(status)
                child.returncode = child_status
        if no_children:
            break
        now = time.monotonic()
        if stopping[0] or now >= deadline or child_status is not None:
            stop_at = stop_at or now
            escalated = now - stop_at >= 5
            signal_owned(signal.SIGKILL if escalated else signal.SIGTERM)
            if now - stop_at >= 10:
                break
        time.sleep(0.025)
    empty = no_children and not descendants()
    result = {'schema': 1, 'cleanupConfirmed': empty, 'cancelled': stopping[0],
              'timedOut': time.monotonic() >= deadline, 'escalated': escalated,
              'childExitCode': child_status}
    os.write(receipt_fd, (json.dumps(result) + '\n').encode())
    os.fsync(receipt_fd)
    os.close(receipt_fd)
    if empty and result['timedOut'] and not stopping[0]:
        return 124
    return 0 if empty and child_status == 0 and not stopping[0] and not result['timedOut'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
