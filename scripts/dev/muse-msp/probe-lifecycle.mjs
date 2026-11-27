// Diagnostic teardown stays bounded even if the OS never reports process exit.
export async function boundedProbeExit(exit, signal, { termMs = 1000, killMs = 5000, deadlineMs = 10000 } = {}) {
  let term, kill, deadline, signalError;
  const send = kind => { try { signal(kind); } catch (error) { signalError = error.code ?? 'signal-failed'; } };
  try {
    term = setTimeout(() => send('SIGTERM'), termMs);
    kill = setTimeout(() => send('SIGKILL'), killMs);
    const result = await Promise.race([exit, new Promise(resolve => {
      deadline = setTimeout(() => resolve({ timedOut: true }), deadlineMs);
    })]);
    return { ...result, ...(signalError ? { signalError } : {}) };
  } finally {
    clearTimeout(term); clearTimeout(kill); clearTimeout(deadline);
  }
}
