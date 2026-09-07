# Monitors — Notification Copy and Rate Doctrine

> House doctrine — not an upstream mirror. The `monitors.json` schema and delivery mechanics live in ../../anthropic-docs/references/plugins-reference.md § Monitors.

Every stdout line a monitor prints is injected into the session as a notification the agent will read mid-task, with no surrounding context. The line is therefore a tiny piece of agent-directed prose engineering — the same discipline as a hook's `additionalContext`, compressed to one line. For imperative-force calibration and urgency tiers, the `persuasion` skill is the authority; this reference applies it to the monitor case.

## The anatomy of a good line

```text
tsdoc: @scope/pkg has 3 ae-*/tsdoc- issues in prod — dispatch the tsdoctor agent or /silk:tsdoc to fix, unless an agent is already working this package: if a build or fixing agent is in flight, let it finish before dispatching another rather than acting on this line immediately
```

Four parts, in order:

1. **Source tag** (`tsdoc:`) — which monitor is speaking. The agent may have several monitors feeding one session; an untagged line is unattributable.
2. **Finding with identifiers** — the package/file/count, specific enough that the agent can act without re-scanning. "Something is wrong with the build" forces a redundant investigation; "@scope/pkg has 3 ae-* issues in prod" doesn't.
3. **The action** — name the exact next step: an agent to dispatch, a slash command to run, a file to fix. A line that only states a fact leaves the agent to guess the intended response.
4. **The hold-back clause** — when NOT to act. This is the part most authors omit and the part that prevents the worst failure mode: the notification arrives while another agent is already fixing the thing, and the session dispatches a second, colliding fix. Say it explicitly: "unless an agent is already working this — let it finish rather than acting on this line immediately."

Rules that follow from delivery mechanics:

- **One line.** Multi-line output is multiple notifications; the parts arrive as disconnected fragments.
- **Self-contained.** The agent reading it has none of the monitor's state. Never reference "the previous notification" or "the count above."
- **No markdown, no color codes.** It's a notification string, not a rendered document.
- **Present tense, imperative for the action.** "has 3 issues — dispatch X" not "there were issues detected; it might be worth considering X."

## Rate doctrine

A monitor that notifies too often trains the session to ignore it — worse than no monitor. The harness enforces the mechanics; the author owes the calibration:

- **Debounce anything an agent or build mutates.** A value mid-churn (a fixing agent peeling issues one by one, a build writing artifacts) must not fire. `stablePolls` × `pollMs` is the quiet period; ~6s (3 × 2000ms) is the proven default.
- **Notify once per finding, re-arm on recovery.** The harness's dedup fires once per stable fingerprint and resets when `isClear` — so a regression after a fix notifies again, but a persistent problem doesn't repeat every poll.
- **`--once` skips the quiet period by design** — it's a single-shot check with no history, used for verification and CI-ish spot checks, not the resident mode.
- **Expose the knob.** `<PLUGIN>_<MONITOR>_STABLE_POLLS` (0 = fire immediately) so a user can tune the monitor without editing the plugin.

## Stream/tail monitors

The poll harness assumes the monitor samples state; some sources are inherently push — `tail -F` of a log, a socket subscription, a filesystem watcher. A stream monitor is legitimate when the source is low-volume and already event-shaped (a deploy-status feed, an error log that logs rarely). The house rules still apply, shifted:

- **Coalesce bursts** — the debounce equivalent. A crash that emits 40 log lines must become one notification, not 40. Buffer over a short window and summarize.
- **Never crash; reconnect.** A stream source that goes away (log rotated, socket dropped) is a retry-with-backoff, not an exit — a dead monitor is silent for the rest of the session and nobody is told.
- **stdout stays sacred** — only the finished notification line; the raw stream never passes through.
- **Same copy anatomy** — tag, finding, action, hold-back.

There is no stream harness yet — one real monitor exists (silk's tsdoc watcher) and it polls. Build the first real stream monitor by hand against the rules above; when a second one appears, extract the shared shape into `lib/` next to the poll harness rather than inventing the abstraction speculatively.
