# The remote viewing protocol

An app that uses Peek can show its calls on a desktop while it runs: the
[`peek_remote`](../../packages/peek_remote) package in the app streams them to
a viewer such as [Peek Pro](https://github.com/artdima/peek-pro). This document is the source of truth for what the
two say to each other. A viewer can be built from it without reading Peek's
Dart code; the reference frames in [`fixtures/remote/`](fixtures/remote/) are
written by `peek_remote`'s tests and fail them when they drift.

Protocol version described here: **1**.

Entries and bodies travel exactly as they are written in a `.peek` file, so
this document leans on [the session format](session-format.md) for them.

## At a glance

```
app → desktop  {"type":"hello","protocolVersion":1,"token":"k7Qx2mP9","sessionId":"3f2a…","session":{…}}
desktop → app  {"type":"welcome","protocolVersion":1,"server":{"name":"Peek Pro","version":"1.0.0"}}
app → desktop  {"type":"entry","op":"add","entry":{…}}          ← the history, one frame per call
app → desktop  {"type":"synced","count":42}                    ← the history ends here
app → desktop  {"type":"entry","op":"update","entry":{…}}       ← live changes from now on
desktop → app  {"type":"bodyRequest","requestId":"7","id":"e1","side":"response"}
app → desktop  {"type":"bodyResponse","requestId":"7","body":{…}}
```

## Roles and transport

- The **desktop is the server** and the **app is the client**: a phone can
  reach a laptop more easily than the other way round, and one desktop can
  watch several apps at once.
- The transport is a **WebSocket**. The desktop listens on port **9741** by
  default, at the path `/`: `ws://<desktop>:9741/`. An Android emulator
  reaches the host as `10.0.2.2`; an Android device on a cable can use
  `adb reverse tcp:9741 tcp:9741` and connect to `localhost`. An iPhone
  connects over Wi-Fi, cable or not.
- Every frame is one **text message** holding one JSON object. Binary
  messages are not used; a peer ignores one it receives.
- Every frame has a string `type`. Frames that go to the desktop come from
  the app and the other way round, as each section says; `ping` and `pong`
  go either way.

## Connecting

1. The app connects and sends `hello` as its first frame.
2. The desktop checks the protocol version and the token — the version
   first — and answers `welcome` or `denied`. After `denied` it closes the
   connection; the app shows the message in its log and does not retry until
   something changes (a new token, an update).
3. After `welcome` the app sends its **history** — an `entry` frame with
   `op: "add"` for every call it holds, oldest first — then `synced`, then
   every change as it happens.
4. Either side may close the connection at any time. The app reconnects on
   its own, waiting a little longer each time, and after a new `welcome`
   sends its history again.

A desktop recognises a session it has seen by `sessionId`: an app that
reconnects keeps it, and the desktop replaces what it held for that session
with the history that arrives, rather than showing a second session.

Frames before `welcome` other than `hello` — or a second `hello` — are
ignored.

## Leniency and versions

The rules of the session format apply to frames as well: a peer **ignores
keys it does not know**, reads **enum values it does not know** as the
fallback each enum names, treats `null` like an absent key, and ignores a
**frame of an unknown `type`**. A frame it cannot read — not JSON, not an
object, a required key missing or of the wrong type — is dropped; it never
closes the connection over one.

`protocolVersion` is an integer. The desktop accepts the versions it speaks
and turns the others away with `denied` / `protocolVersion`, saying which
side to update. The version goes up only when an older peer would
**misread** a frame; a new frame type, key or enum value does not raise it.

## Frames

### `hello` — app → desktop

| Key | Type | Required | Meaning |
|---|---|---|---|
| `protocolVersion` | integer | yes | The protocol the app speaks. |
| `token` | string | no | The token the desktop shows, as the app was given it, or the `deviceToken` a desktop issued to this device (see [Pairing](#pairing-with-a-code)). Absent when the app has neither. |
| `code` | string | no | The pairing code the desktop shows, typed by a person. Sent instead of `token`, and only until the desktop answers with a `deviceToken`. |
| `sessionId` | string | yes | Stays the same while the app runs, across reconnections. |
| `session` | object | yes | The app, as the header of a `.peek` file describes it: `peekVersion`, `name`, `platform`, `osVersion`, `startedAt`, with the same rules. `format` and `formatVersion` are not part of it. |

### `welcome` — desktop → app

| Key | Type | Required | Meaning |
|---|---|---|---|
| `protocolVersion` | integer | yes | The protocol the desktop speaks. |
| `server` | object | no | `name` and `version` of the desktop, and its `id` — a string that stays the same across launches, so the app knows whose `deviceToken` it holds. All strings, all optional. |
| `deviceToken` | string | no | Issued when the `hello` carried a right `code`: the token this device sends from now on, in `token`. |

### `denied` — desktop → app

| Key | Type | Required | Meaning |
|---|---|---|---|
| `reason` | string | yes | `token` — missing or wrong; `code` — the pairing code is wrong or has expired; `protocolVersion` — the desktop does not speak the app's version; `other`. Unknown values read as `other`. |
| `message` | string | yes | Why, for a person to read in the app's log. |

The desktop compares tokens and codes in constant time and closes the
connection after sending this frame.

### `entry` — app → desktop

| Key | Type | Required | Meaning |
|---|---|---|---|
| `op` | string | yes | `add` — a call the desktop has not seen; `update` — it replaces the call with the same id; `remove` — the call is gone. An unknown `op` makes the frame unreadable. |
| `entry` | [Entry](session-format.md#entry) | for `add` and `update` | The call, as a line of a `.peek` file holds it. |
| `id` | string | for `remove` | The id of the call that is gone. |

The desktop treats `add` for an id it holds as `update`, and `update` for an
id it does not hold as `add`: frames can be lost (see `dropped`), and what
arrives last is what the app holds.

Entries the app sends have already been through its redaction: masked values
arrive masked. Their bodies may be held back — see [Bodies](#bodies).

### `cleared` — app → desktop

The app's store was emptied. No keys.

### `synced` — app → desktop

The history after `welcome` ends here; live changes follow. A desktop can
show the history in one go on this frame instead of call by call.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `count` | integer | yes | How many `entry` frames the history held. |

### `dropped` — app → desktop

The app could not send as fast as calls happened and threw frames away
rather than slow itself down. The desktop says so; what it shows may be
missing calls or show them in an older state until they change again.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `count` | integer | yes | How many frames were lost since the last `dropped`. |

### `bodyRequest` — desktop → app

| Key | Type | Required | Meaning |
|---|---|---|---|
| `requestId` | string | yes | Chosen by the desktop; the answer carries it back. |
| `id` | string | yes | The call. |
| `side` | string | yes | `request` or `response`. |

### `bodyResponse` — app → desktop

Either a body or the reason there is none.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `requestId` | string | yes | The request this answers. |
| `body` | [Body](session-format.md#body) | no | The body, as a `.peek` file holds it. |
| `error` | string | when there is no `body` | `notFound` — no such call, or no response yet; `notHeld` — the app never had the body; `failed` — anything else. Unknown values read as `failed`. |
| `message` | string | no | Why, for a person to read. |

A desktop that hears nothing within a time of its choosing gives up on the
request and may ask again.

### `ping` and `pong` — either way

`ping` asks the other side to answer with `pong` as soon as it can. Neither
has keys. A side that sends `ping` and hears nothing for a while may close the
connection.

## Bodies

An app may send a body **inline**, in the entry, or **hold it back** and send
a `remote` body in its place — `size`, `type` and `truncated` from the body it
keeps (see [the session format](session-format.md#body)). The desktop fetches
a held-back body with `bodyRequest` when someone wants to read it, and
replaces the marker with the body that comes back.

A desktop must handle both. What an app sends inline is its own choice:
small bodies usually are, large ones are held back so that a download costs
nothing until someone looks at it.

## The token

The desktop makes up a token and shows it; the app is given it in code
(`PeekRemote(token: …)`). It keeps an app on the same network from streaming
into a desktop that did not ask for it. It is not encryption: the connection
is plain `ws://`, meant for a local network and a debug build.

## Pairing with a code

Typing a long token into code is fine for a script; a person at a phone is
better served by a short code. The desktop shows one — **four digits** — and
the app sends it in `hello.code`, with no `token`:

1. The desktop checks the version, then the code. A right code is answered
   with `welcome` carrying a fresh **`deviceToken`** — long and random — and
   `server.id`; a wrong or expired one with `denied` / `code`.
2. The app keeps the `deviceToken` (with the `server.id` it came from) and
   sends it as `token` on every connection from then on, never the code
   again. The desktop accepts it like the token it shows.
3. A desktop that has forgotten the device answers `denied` / `token`; the
   app drops the token and asks the person for a new code.

A four-digit code is not a secret that lasts: it is a one-time pairing, the
way a TV pairs a remote. The desktop keeps it short-lived — a few minutes,
then a new one — makes it **expire on success** and **after a handful of
wrong tries** (five is plenty; a new code appears), and compares it in
constant time. Which devices it remembers, and for how long, is the
desktop's to decide and to show. A desktop that does not pair may ignore
`code`; the app then sees `denied` / `token`.

## Finding the desktop

A desktop may advertise itself over Bonjour (DNS-SD), so that an app on the
same network can offer it by name instead of asking for an address:

- Service type **`_peek._tcp`**, in the `local.` domain.
- The service name is the desktop as a person knows it — the computer's
  name unless the person chose another. The network may rename it
  (`MacBook Pro (2)`) when two desktops clash; the name the app sees is the
  one to show.
- The SRV record gives the host and port to connect to; the path is `/` as
  always.
- The TXT record has `protocolVersion`: the newest protocol the desktop
  speaks, so an app can tell an old desktop apart before connecting. It may
  have `serverId`, the same `id` the `welcome` carries: an app that paired
  with that desktop sends its device token, and to any other desktop it
  sends none — a token is never offered to a desktop that did not issue it.

Advertising can be switched off, and many networks block multicast DNS, so
an app always accepts an address typed in; discovery is a convenience on
top. Browsing does not replace the token or the code: the `hello` still
carries one. On iOS an app browses through the system's Bonjour, which needs
`NSLocalNetworkUsageDescription` and `_peek._tcp` in `NSBonjourServices`;
multicast sockets of its own would need an entitlement Apple grants on
request.

## Reference frames

[`fixtures/remote/`](fixtures/remote/) holds one file per frame, each a single
line of JSON ending in `\n`, and
[`manifest.json`](fixtures/remote/manifest.json), which says for each file its
`type`, which way it travels (`toDesktop`, `toApp` or `either`), whether a
reader must ignore it (`ignored`), and which file it must read the same as
(`sameAs`).

| File | What it shows |
|---|---|
| `hello.json` | An app with a name, an OS version and a token. |
| `hello-code.json` | The same app pairing with a code instead. |
| `welcome.json`, `denied.json` | The two answers. |
| `welcome-paired.json`, `denied-code.json` | The answers to a code: a `deviceToken` with the desktop's `id`, or a refusal. |
| `entry-add.json`, `entry-update.json`, `entry-remove.json` | A call as it starts — its request body held back — as it completes, and as it goes. |
| `cleared.json`, `synced.json`, `dropped.json` | The frames without an entry. |
| `body-request.json`, `body-response.json`, `body-error.json` | A body asked for, sent, and refused. |
| `ping.json`, `pong.json` | Keeping the connection honest. |
| `unknown-type.json` | A frame from a newer peer: ignored. |
| `unknown-keys.json` | `hello.json` with a key added: reads the same. |

`peek_remote` regenerates them with `dart run melos run spec:update`.

## Changes to the protocol

Any change starts here, in this document and the reference frames, together
with the Dart code — and, when an older peer would misread the result, with a
new `protocolVersion`. Viewers elsewhere (Peek Pro) follow from this
document.
