# Changelog

## 1.0.0

The first release, signed with Developer ID and notarized by Apple. Peek Pro
needs macOS 26 or later; live viewing needs `peek_remote` 2.0.0 or later in
the app.

- **Live from the device.** An app with `peek_remote` streams its calls over
  the local network — from a phone, a simulator or an emulator. Each run is a
  session; several devices and apps stream at once, and a device that
  reconnects comes back to its own session with its history.
- **Pairing.** A four-digit code, typed once on the device, which is
  remembered from then on. Peek Pro announces itself over Bonjour, so the app
  lists the Mac by name. A long token for CI.
- **The console.** A table or a list; search, filters, the All, Errors,
  Pending and Pinned modes, sorting and grouping, issues and insights, pins.
  Smooth at a hundred thousand calls.
- **Every detail.** The summary with timing and sizes; the request and the
  response with their headers, cookies, query and body — JSON as a tree or as
  text, images and the rest; the error behind a failure; the call as cURL.
  Any call opens in a window of its own.
- **Files.** `.peek` files open from Finder, and a live session saves as one.
  Export as HAR, cURL, Markdown or text.
