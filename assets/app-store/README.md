# App Store

What goes into App Store Connect for Peek Pro, field by field; the texts in
code blocks are ready to paste. The screenshots beside this file are
2880 × 1800, a size the Mac App Store takes.

## App information

| Field | Value |
| --- | --- |
| Name | Peek Pro |
| Subtitle | Network logger for Flutter |
| Bundle ID | `com.artdima.Peek-Pro` |
| SKU | `peek-pro` |
| Primary language | English (U.S.) |
| Category | Developer Tools |
| Content rights | No third-party content |
| Age rating | Every answer “None” / “No” — 4+ |
| Price | Free |

## Version 1.0.0

**Promotional text**

```text
Every network call your Flutter app makes, live from a phone, a simulator or an emulator, or from a saved .peek file — on a big screen, with search across everything.
```

**Description**

```text
Peek Pro is the desk companion to Peek, the network inspector that lives inside a Flutter app. It shows the same calls on your Mac: live from a phone, a simulator or an emulator, or from a .peek file someone saved — with a bigger screen, a real table, search across everything and several apps at once.

It is not a proxy. Nothing passes through Peek Pro on its way to the server, no certificate is installed and no traffic is rewritten. It shows what Peek already recorded inside the app, after the app's own redaction.

LIVE FROM THE DEVICE
• An app with the peek_remote package streams its calls over the local network.
• Each run is a session in the sidebar; several devices and apps stream at once.
• A device that reconnects comes back to its own session, with its history.

PAIR ONCE WITH A CODE
• Peek Pro shows four digits; type them into the app once, and the device is remembered.
• Peek Pro announces itself over Bonjour, so the app lists the Mac by name.
• A long token for CI, where nobody types.

FIND THE CALL
• Search, filters, and the All, Errors, Pending and Pinned modes.
• Sorting and grouping, issues and insights at a glance, pins for the calls worth keeping.
• Smooth at a hundred thousand calls.

EVERY DETAIL
• The summary with timing and sizes.
• The request and the response with headers, cookies, query and body — JSON as a tree or as text, images and the rest.
• The error behind a failure, and any call as cURL.
• Any call opens in a window of its own.

FILES
• .peek files open from Finder; a live session saves as one, for a bug report or a colleague.
• Export as HAR, cURL, Markdown or text.

PRIVATE BY DESIGN
Peek Pro collects nothing and makes no connections of its own. It takes calls only from devices you paired.

To connect a Flutter app, add peek_remote and start it in debug builds; the guide is at github.com/artdima/peek. Peek and Peek Pro are free and open source.
```

**Keywords**

`http,dio,chopper,api,rest,debug,inspector,requests,traffic,json,curl,har,devtools,ios,android`

| Field | Value |
| --- | --- |
| Support URL | https://github.com/artdima/peek-pro/issues |
| Marketing URL | https://github.com/artdima/peek-pro |
| Copyright | 2026 Dmitriy Medyannik |

## App Privacy

| Field | Value |
| --- | --- |
| Privacy Policy URL | https://github.com/artdima/peek-pro/blob/main/PRIVACY.md |
| Data collection | Data Not Collected |

## App Review

**Notes**

```text
Peek Pro is a developer tool: a viewer for the network calls that the open-source Peek library records inside a Flutter app.

To try it without a Flutter app, open the attached sample session: unzip review-sample.zip, then double-click review-sample.peek (or File → Open… in Peek Pro). The calls appear in the console; select one to see its summary, request, response, headers and body, or Request → Copy as cURL. File → Export saves the calls as HAR or text.

Live viewing needs a Flutter app with the peek_remote package on the same network: the app finds the Mac over Bonjour, and the person types the four-digit code that Peek Pro shows. The setup guide: https://github.com/artdima/peek/blob/main/doc/remote.md

No account or sign-in is needed. Peek Pro makes no outgoing connections; it listens on port 9741 and takes calls only from paired devices.
```

**Attachment**

`review-sample.zip` — a session saved from the Peek example app.
