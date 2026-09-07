# Channels reference

> Verified against <https://code.claude.com/docs/en/channels-reference.md> — 2026-07-10

## Contents

- [Research preview status](#research-preview-status)
- [Testing gate](#testing-gate)
- [Server contract](#server-contract)
- [Notification format](#notification-format)
- [Reply tool](#reply-tool)
- [Sender gating](#sender-gating)
- [Permission relay](#permission-relay)
- [Packaging as a plugin](#packaging-as-a-plugin)

A channel is an MCP server, spawned as a subprocess and communicating over stdio, that pushes events into a Claude Code session so Claude can react to things happening outside the terminal. One-way channels forward alerts/webhooks/monitoring events; two-way channels (chat bridges) also expose a reply tool; a channel with a trusted sender path can additionally opt in to relay permission prompts.

## Research preview status

- Channels are in **research preview**. Requires Claude Code **v2.1.80 or later**.
- **Permission relay specifically requires v2.1.81 or later** — earlier versions ignore the `claude/channel/permission` capability entirely.
- Team and Enterprise organizations must explicitly enable channels (`channelsEnabled` org policy) before use.
- Telegram, Discord, iMessage, and fakechat are the pre-built channels included in the research preview.

## Testing gate

During the research preview, every channel must be on the approved (Anthropic-curated) allowlist to register. `--dangerously-load-development-channels` bypasses the allowlist for **specific entries**, after a confirmation prompt. The bypass is **per-entry**.

Entry forms:

```bash
# Testing a plugin-wrapped channel
claude --dangerously-load-development-channels plugin:yourplugin@yourmarketplace

# Testing a bare .mcp.json server (no plugin wrapper yet)
claude --dangerously-load-development-channels server:webhook
```

- Combining this flag with `--channels` does **not** extend the bypass to the `--channels` entries.
- The flag skips the allowlist only — the `channelsEnabled` org policy still applies. Don't use it for untrusted sources.
- First session start in a project: Claude Code asks for consent before using a new `.mcp.json` server ("New MCP server found in this project: `<name>`" — select **Use this MCP server**).
- Startup confirms registration with a dim notice: `Channels (experimental) messages from server:webhook inject directly in this session · restart without --dangerously-load-development-channels to stop`.
- "blocked by org policy" means an org admin must enable channels first.

## Server contract

Requirements (all three):

1. Declare the `claude/channel` capability → Claude Code registers a notification listener
2. Emit `notifications/claude/channel` events
3. Connect over **stdio transport** — Claude Code spawns the server as a subprocess; this is the required transport for channels

Constructor options — `capabilities.experimental['claude/channel']` and `capabilities.experimental['claude/channel/permission']` are channel-specific; `instructions` and `capabilities.tools` are standard MCP:

| Field | Type | Description |
| :--- | :--- | :--- |
| `capabilities.experimental['claude/channel']` | `object` | Required. Always `{}`. Presence registers the notification listener. |
| `capabilities.experimental['claude/channel/permission']` | `object` | Optional. Always `{}`. Declares this channel can receive permission relay requests — see [Permission relay](#permission-relay). |
| `capabilities.tools` | `object` | Two-way only. Always `{}`. Standard MCP tool capability — see [Reply tool](#reply-tool). |
| `instructions` | `string` | Recommended. Added to Claude's system prompt. Tell Claude what events to expect, what `<channel>` tag attributes mean, whether to reply and with which tool/attribute (e.g. `chat_id`). |

Omit `capabilities.tools` for a one-way channel. Capability declaration shape:

```ts
capabilities: {
  experimental: { 'claude/channel': {} },
  tools: {},  // omit for one-way channels
},
instructions: 'Messages arrive as <channel source="your-channel" ...>. Reply with the reply tool.',
```

## Notification format

Method: `notifications/claude/channel`. Params:

| Field | Type | Description |
| :--- | :--- | :--- |
| `content` | `string` | The event body — delivered as the body of the `<channel>` tag. |
| `meta` | `Record<string, string>` | Optional. Each entry becomes a `<channel>` tag attribute (chat ID, sender, severity, etc.). Keys must be identifiers — letters, digits, underscores only. Keys with hyphens or other characters are **silently dropped**. |

Minimal call shape:

```ts
await mcp.notification({
  method: 'notifications/claude/channel',
  params: { content: 'build failed on main: https://ci.example.com/run/1234', meta: { severity: 'high', run_id: '1234' } },
})
```

Rendering — the `source` attribute is set automatically from the server's configured name:

```text
<channel source="your-channel" severity="high" run_id="1234">
build failed on main: https://ci.example.com/run/1234
</channel>
```

**No-ack / silent-drop semantics**: notifications are not acknowledged. The `await` on `mcp.notification()` resolves when the message is written to the transport, not when Claude has processed it. If the session hasn't loaded the server as a channel, or org policy blocks it, events are **dropped silently with no error returned to the server**. For delivery confirmation, track event state server-side and expose a reply tool Claude can call to report status.

**Queueing**: events queue into the session and process in order. Several notifications arriving while Claude is busy are delivered together on the next turn and handled as a group. To process independent event streams concurrently, run separate sessions.

## Reply tool

A two-way channel exposes a **standard MCP tool** — nothing about the registration is channel-specific. Three components:

1. `tools: {}` in the `Server` constructor capabilities, so Claude Code discovers the tool
2. Tool handlers (`ListToolsRequestSchema` / `CallToolRequestSchema`) defining schema and send logic
3. An `instructions` string routing Claude to the tool and which inbound attribute to echo back (e.g. `chat_id` from the `<channel>` tag)

## Sender gating

An ungated channel is a prompt injection vector — anyone who can reach your endpoint can put text in front of Claude. A channel listening to a chat platform or public endpoint needs a real sender check before it ever calls `mcp.notification()`.

**Gate on the sender's identity, not the room's** — the critical rule:

```ts
if (!allowed.has(message.from.id)) return  // sender, not room — drop silently
```

`message.from.id`, never `message.chat.id`. In group chats these differ; gating on the room would let anyone in an allowlisted group inject messages into the session.

Telegram and Discord gate via a sender allowlist bootstrapped by pairing: user DMs the bot → bot replies with a pairing code → user approves it in their Claude Code session → platform ID added. iMessage instead detects the user's own addresses from the Messages database at startup and lets them through automatically, with other senders added by handle.

## Permission relay

> Requires Claude Code **v2.1.81 or later**. Earlier versions ignore the `claude/channel/permission` capability.

Covers tool-use approvals (`Bash`, `Write`, `Edit`, etc.). **Project trust and MCP server consent dialogs do not relay** — those only appear in the local terminal.

### How relay works

1. Claude Code generates a short request ID and notifies the server
2. The server forwards the prompt + ID to the chat app
3. The remote user replies yes/no + that ID
4. The inbound handler parses the reply into a verdict; Claude Code applies it only if the ID matches an **open** request

**First-answer-wins**: the local terminal dialog stays open throughout. If someone answers at the terminal before the remote verdict arrives, that answer is applied and the pending remote request is dropped (and vice versa).

**Only-if-sender-gated warning**: only declare the permission capability if the channel [authenticates the sender](#sender-gating) — anyone who can reply through the channel can approve or deny tool use in the session.

### Permission request fields

Outbound notification: `notifications/claude/channel/permission_request`. Same transport as the [channel notification](#notification-format) (standard MCP), method/schema are Claude Code extensions.

| Field | Description |
| :--- | :--- |
| `request_id` | Five lowercase letters drawn from `a`-`z` **without `l`** (never misread as `1`/`I` on a phone). Include verbatim in the outgoing prompt — Claude Code only accepts a verdict carrying an ID it issued. The local terminal dialog does not display this ID; the outbound handler is the only way to learn it. |
| `tool_name` | e.g. `Bash`, `Write`. |
| `description` | Human-readable summary of this specific call — same text the local terminal dialog shows. |
| `input_preview` | Tool arguments as a JSON string, truncated to 200 characters. Omit from the outgoing prompt if space-constrained. |

### Verdict notification shape

Sent back as `notifications/claude/channel/permission`:

| Field | Description |
| :--- | :--- |
| `request_id` | Echoes the ID from the request. |
| `behavior` | `'allow'` or `'deny'`. Allow proceeds; deny rejects the same as answering No locally. Neither affects future calls. |

### Capability declaration

```ts
capabilities: {
  experimental: {
    'claude/channel': {},
    'claude/channel/permission': {},  // opt in to permission relay
  },
  tools: {},
},
```

### Failure modes (dialog stays open in both cases)

- **Different format**: the inbound regex doesn't match — text like `approve it` or `yes` without an ID falls through as a normal chat message to Claude.
- **Right format, wrong ID**: the server emits a verdict but Claude Code finds no open request with that ID — dropped silently.

Regex used in the reference implementation: `/^\s*(y|yes|n|no)\s+([a-km-z]{5})\s*$/i` — `[a-km-z]` is the ID alphabet (lowercase, skips `l`); the `/i` flag tolerates phone autocorrect capitalization, so lowercase the captured ID before sending the verdict.

## Packaging as a plugin

Wrap the channel in a plugin and publish to a marketplace. Users install with `/plugin install`, then enable it per session with:

```bash
claude --channels plugin:<name>@<marketplace>
```

A channel published to your own marketplace still needs `--dangerously-load-development-channels` to run, since it isn't on the approved allowlist. The default allowlist is the channel plugins in `claude-plugins-official` (Anthropic-curated, at Anthropic's discretion). The in-app community-marketplace submission forms do **not** add plugins to the channel allowlist.

Team/Enterprise: an admin can include your plugin in the org's `allowedChannelPlugins` list, which replaces the default Anthropic allowlist. Otherwise, coordinate an official-marketplace listing through an Anthropic partner contact.
