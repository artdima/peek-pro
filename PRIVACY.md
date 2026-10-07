# Privacy

Peek Pro collects nothing. It has no analytics, no crash reporting and no
accounts, and it sends nothing to its developer or to anyone else.

What it handles stays on your Mac:

- **Calls from your apps.** An app with
  [`peek_remote`](https://github.com/artdima/peek/tree/main/packages/peek_remote)
  sends Peek Pro the calls it recorded, after the app's own redaction. Peek
  Pro keeps them in memory while it runs; they reach the disk only when you
  save or export them.
- **Files.** `.peek` files you open or save, and the list of recent ones.
- **Paired devices.** A token for each device you paired, in your keychain.
- **Settings.** In Peek Pro's own preferences.

Peek Pro listens on the local network, on port 9741, and announces itself
over Bonjour so that apps can find the Mac. It takes calls only from devices
you paired, and it makes no connections of its own.

Questions go to [the issues](https://github.com/artdima/peek-pro/issues).
