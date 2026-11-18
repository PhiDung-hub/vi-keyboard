# Vietnamese Telex Keyboard

Type Vietnamese Telex and English in the same text field. The Rime schema runs locally through Fcitx 5 on Linux and Weasel on Windows. It preserves known English words, passes through shortcuts, and shows the converted word before you commit it.

## Install

Download and extract `vi-keyboard-0.1.1.zip` from the [latest release](https://github.com/PhiDung-hub/vi-keyboard/releases/latest).

| Platform | Prerequisites | Rime user folder |
| --- | --- | --- |
| Linux | Fcitx 5, its Rime addon, and librime-lua. On Fedora, run `sudo dnf install fcitx5-rime librime-lua`. | `${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/rime` |
| Windows | Install [Weasel 0.17.4 or later](https://github.com/rime/weasel/releases). | `%APPDATA%\Rime` by default, or open the user folder from the Weasel tray menu. |

1. Copy the **contents** of the extracted `rime` directory into the Rime user folder. Merge its `lua` directory with your existing files.
2. In the Rime user folder, create `default.custom.yaml` with the following contents. If the file already exists, merge the `schema_list` entry into its existing `patch` and keep any schemas you use.

   ```yaml
   patch:
     schema_list:
       - schema: vi_keyboard
   ```

3. On Linux, add **Rime** in Fcitx 5 Configuration and select **Deploy** from the Rime menu. On Windows, select **Deploy** from the Weasel tray menu. Choose **Vietnamese Telex** if Rime offers more than one schema.

## Type

- `Tieengs Vieejt` gives `Tiếng Việt`. Telex uses `aa`, `aw`, `ee`, `oo`, `ow`, `uw`, and `dd` for letter shapes and `s`, `f`, `r`, `x`, and `j` for tones. `z` clears marks while composing.
- `this is a test` stays `this is a test`. The keyboard preserves known English words regardless of casing and converts other tokens only when they form a complete Vietnamese syllable, so `reform`, `params`, and `nextjs` stay as typed. An incomplete syllable also stays as typed. Unlisted English words that spell a valid syllable in Telex can still convert.
- Press **Shift+Space** to force the Vietnamese reading of the current word and add a space. For example, `as` normally stays `as`, and `as` followed by Shift+Space gives `á`.
- Press **Ctrl+Shift+Space** to switch between Vietnamese and plain English while this schema is active. **Esc** cancels the current word. Backspace edits its raw keystrokes.

## Verify

`tests/integration.py` deploys the schema in an isolated Rime profile and feeds real Rime key events. It uses Python 3.9+ and only the standard library. Run it with the path to the librime shared library, the frontend's shared data folder, and a new work directory. On Linux, pass `--lua-module` if librime-lua is packaged as a separate shared library.

```text
python tests/integration.py --library PATH --shared-data PATH --work-dir NEW_PATH [--lua-module PATH]
```

The code is MIT licensed. The English exceptions are derived from the [SCOWL en_US Hunspell dictionary, version 2026.02.25](https://github.com/en-wl/wordlist/releases/tag/rel-2026.02.25). The project filters the dictionary to words that can collide with Telex, and adds contractions plus common names, abbreviations, and code words such as `usr`, `sys`, and `deps`. See [SCOWL's terms](licenses/SCOWL.txt).
