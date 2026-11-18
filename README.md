# reword

Command-line tool that rewrites text with the **on-device Apple Intelligence model** (FoundationModels). Nothing leaves your Mac. It reads stdin and writes the result to stdout, so it plugs into any shortcut tool: a Hammerspoon hotkey on the Mac, or an iPhone Shortcut over SSH.

## Requirements

- macOS 26 or later, on a Mac with Apple Intelligence enabled and its model downloaded
- Swift 6.2 toolchain (Xcode 26)
- Optional: [Hammerspoon](https://www.hammerspoon.org) for global hotkeys

## Install

```bash
git clone https://github.com/anishda/reword.git
cd reword
make install        # release build, copied to ~/.local/bin/reword
reword --check      # {"available": true} when the model is ready
```

Make sure `~/.local/bin` is in your `PATH`. Use `PREFIX=/usr/local make install` to install elsewhere. `make test` runs the unit tests.

## Usage

```bash
echo "je sui content de te voir" | reword fix
pbpaste | reword formal | pbcopy
```

| Mode | What it does |
|---|---|
| `fix` | Spelling, grammar, punctuation. Minimal changes, same tone. |
| `rephrase` | Different, clearer wording. Same meaning, tone and length. |
| `shorten` | About 40% shorter (input limited to 4000 characters). |
| `formal` | Professional, polite register (uses "vous" in French). |
| `translate` | French to English, anything else to French. |
| `translate-en` / `translate-fr` | Force the target language. |

Options: `--timeout N` (seconds, default 20), `--strict`, `--debug` (timing on stderr). `reword --list-modes` prints the available modes.

Long texts are split into chunks and reassembled. The output is checked against a length ratio and cleaned of preambles, quotes and code fences; unusable output makes the command fail instead of replacing your text.

Exit codes: `0` ok, `2` usage, `3` empty input, `10` model unavailable, `11` unsupported language, `12` blocked by Apple guardrails, `13` text too long for the mode, `14` timeout, `15` generation error, `16` unusable output.

### Custom prompts

```bash
mkdir -p ~/.config/reword
reword --dump-modes > ~/.config/reword/modes.json
```

Edit the file to change prompts, temperature or length ratios. Entries override built-in modes with the same name; new names add modes.

## Hammerspoon hotkeys

```bash
cp hammerspoon/reword.lua ~/.hammerspoon/
echo 'require("reword")' >> ~/.hammerspoon/init.lua
```

Reload the Hammerspoon config, select text in any app, then press:

| Shortcut | Action |
|---|---|
| ⌃⌥F | fix |
| ⌃⌥R | rephrase |
| ⌃⌥S | shorten |
| ⌃⌥T | formal |
| ⌃⌥E | translate |
| ⌃⌥Z | undo the last replacement |
| ⌃⌥Space | pick a mode from a list |

The script copies the selection, runs `reword`, pastes the result and restores your clipboard. Edit `BINDINGS`, `hyper` and `TIMEOUT` at the top of the file to customize. Hammerspoon needs the Accessibility permission. Run `hs.settings.set("reword.debug", true)` in the Hammerspoon console to log to `/tmp/reword-hs.log` (the log contains your text).

## iPhone shortcut (SSH over Tailscale)

The model runs on your Mac, so an iPhone can use it by running `reword` over SSH. With [Tailscale](https://tailscale.com) on both devices, the Mac is reachable by its MagicDNS name from anywhere.

1. On the Mac, enable *System Settings → General → Sharing → Remote Login*. Generate a dedicated SSH key on the iPhone (in the Shortcuts SSH action or an SSH app) and add its public key to `~/.ssh/authorized_keys`.
2. On the iPhone, create a Shortcut:
   - *Get Clipboard* (or *Receive Text from Share Sheet*)
   - *Run Script Over SSH*: host `<your-mac>.<your-tailnet>.ts.net`, user `<your-mac-username>`, the key from step 1, script `~/.local/bin/reword fix` (or another mode), input *Shortcut Input*
   - *Copy to Clipboard* (or *Show Result*)
3. Add the Shortcut to the Share Sheet or the Action Button.

Use the full path to `reword`, since a non-interactive SSH shell may not have `~/.local/bin` in its `PATH`. Keep the Mac awake and reachable on the tailnet. Tip: restrict the key in `authorized_keys` with `no-pty,no-port-forwarding,no-agent-forwarding` and, if you only need one mode, a forced `command="/Users/<you>/.local/bin/reword fix"`.

This SSH setup is not covered by the test suite: check that `reword --check` succeeds from an SSH session on your Mac before relying on it.

## Notes

- Everything runs locally: no network access, no telemetry.
- Language support depends on what Apple's on-device model supports (`reword` exits with code `11` otherwise).
- The built-in prompts are in English; notifications in the Hammerspoon script are in French.

## License

[MIT](LICENSE)
