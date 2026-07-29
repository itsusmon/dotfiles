# Neovim

## What it is

Neovim is a modern, extensible, Vim-based text editor.

## Why I use it

It is the primary editor for quick edits, config work, and terminal-based coding.
It is configured in Lua with a curated plugin set (LSP, Treesitter, Telescope, Neo-tree, gitsigns) for an IDE-like experience that stays fast.

## What's here

The config is modular Lua, loaded by `init.lua`:

- `lua/core/` - editor settings that don't depend on plugins:
  - `options.lua` - vim options (also sets the leader key before lazy.nvim loads).
  - `keymaps.lua` - keybindings.
  - `autocmds.lua` - autocommands.
- `lua/plugins/` - plugin specs, managed by lazy.nvim:
  - `init.lua` - bootstraps lazy.nvim and imports the specs below.
  - `ui.lua` - colorscheme (Catppuccin Macchiato, transparent) and UI.
  - `editor.lua` - editing plugins (Telescope, Neo-tree, gitsigns, and friends).
  - `treesitter.lua` - syntax parsing and highlighting.
  - `lsp.lua` - language servers.

The plugin manager is lazy.nvim, auto-bootstrapped on first launch (git-cloned into the data dir).
`lazy-lock.json` is intentionally not tracked, since it is an app-managed lockfile.

`launcher/` contains the reproducible source for a macOS Finder launcher:

- `NvimLauncher.applescript` resolves Neovim at launch and asks Ghostty to open it in a native tab.
- `NvimLauncherHelper.swift` provides canonical path handling, private session state, exact-argument process launch, and Neovim RPC routing.
- `Info.plist` supplies the stable `com.usmon.nvim-launcher` identity and the `public.text` and `public.folder` document associations.
- `Nvim.icon/` contains the official Neovim mark on separate light and dark backgrounds plus the Icon Composer manifest.

The generated application is intentionally not tracked.
`nvim-app install` stages, validates, ad hoc signs, and installs it at `~/Applications/Nvim.app`.
The main `install.sh` runs that command automatically on macOS and skips it on other operating systems.
An unchanged, complete, correctly signed installation is left alone.

## Nvim.app prerequisites

- macOS 13 or newer.
- Xcode Command Line Tools, including `swiftc`.
- macOS 26 and Xcode 26 are required only for adaptive light and dark app icons.
- Ghostty 1.3 or newer in `/Applications` or `~/Applications`.
- Ghostty's `macos-applescript` setting must remain enabled.
- Neovim must be executable at `/opt/homebrew/bin/nvim`, `/usr/local/bin/nvim`, `/usr/bin/nvim`, or `~/.local/bin/nvim`, or be discoverable by the login shell.

Ghostty 1.3 introduced the native AppleScript API used for windows, tabs, initial commands, working directories, selection, and focus.
The installer checks the installed scripting dictionary for those commands instead of relying only on a version string.
The launcher addresses Ghostty by bundle identifier after discovering and validating its installed application.

## Working with it

- Plugins install and update via lazy.nvim; run `:Lazy` to manage them.
- The keymaps mirror the Vim/IdeaVim setup (see `../vim/`) so muscle memory carries between Neovim and JetBrains IDEs / Android Studio.
- Rebuild or update the Finder launcher with `nvim-app install`, or run the repository's `./install.sh`.
- Validate the installed launcher with `nvim-app verify`.
- Remove only the generated launcher with `nvim-app uninstall`.
- Run the focused RPC and state tests with `./scripts/verify-nvim-launcher-helper.sh`.

## Launcher-managed roots

Opening exactly one directory with `Nvim.app` starts a rooted launcher session.
Finder can send a folder through Open With or by dragging it onto `Nvim.app` because the bundle advertises `public.folder`.
The directory is canonicalized by resolving `.` and `..` components, repeated separators, and symlinked directories.
That canonical directory remains the session root even if Neovim's working directory later changes.

When Finder opens a file inside a live launcher root, the launcher uses Neovim's Unix-domain RPC server instead of creating another Ghostty tab.
Each incoming file opens in a new Neovim tabpage, and the final new tabpage remains selected.
The launcher then selects the stored Ghostty tab and terminal, activates its window, and brings Ghostty forward.
Opening exactly one nested directory intentionally creates its own root even while a broader parent root is active.
For a multi-file Finder event, files are grouped by their most specific live root.
A nested root therefore wins over a broader parent root.
Containment is path-component aware, so `example-backup` is not inside `example`.

Only rooted sessions created by `Nvim.app` are eligible for reuse.
Manually started Neovim instances are not adopted because Ghostty 1.3 does not expose a robust mapping from an arbitrary Neovim RPC server and process to its exact terminal object.
A file-only launch remains an independent, unrooted Neovim process and is never published as a reusable session.
It receives a private one-shot RPC socket only during startup so the launcher can verify the process and attach exact surface-lifecycle metadata.

Runtime session state and short-lived surface-close requests are stored in the private directory `/tmp/com.usmon.nvim-launcher-UID`, where `UID` is the current numeric user ID.
Each JSON record contains the canonical root, deterministic socket path, random launch token, verified Neovim process ID, and stable Ghostty window, tab, and terminal IDs.
Records are atomically replaced under a short-lived file lock.
The launcher verifies the RPC server's root, token, protocol version, and process ID before every reuse.
Invalid or expired records and stale sockets are removed lazily.
Neovim also removes its record during `VimLeavePre`, and its Unix socket naturally becomes unusable when the process exits.

Ghostty receives Neovim as the surface's lifetime-owning command through the bundled helper.
The helper replaces itself with Neovim, and the surface uses `wait after command = false`.
Ghostty 1.3.1 can retain an AppleScript-created surface after its command exits even with that per-surface setting.
As a verified fallback, `VimLeavePre` starts one bounded helper that observes the exact Neovim process with the macOS process-event API.
After that process exits, the helper atomically publishes a single-use close request and asks Launch Services to run the installed `Nvim.app`.
Launch Services delivers the request through the private `nvim-launcher` URL scheme.
`Nvim.app` consumes that request and closes a surface only after the stored Ghostty window, tab, and terminal IDs all identify the same current object hierarchy.
Ghostty 1.3 exposes no additional immutable surface property, while terminal names and working directories are mutable.
The three stable IDs, exact process-exit event, immediate delivery, 30-second expiry, and one-time consumption prevent a delayed helper from acting on an unrelated surface without introducing a fragile mutable-property check.
The helper never sends Ghostty Apple events, so Automation control is attributed to the installed `Nvim.app`, not to a changing nested helper or a temporary build path.
The helper runs only during process exit, times out after ten seconds, and is not a persistent monitor or daemon.
Closing an internal Neovim tabpage does not affect Ghostty while the Neovim process remains alive.
The launcher-created Ghostty tab closes after `:qa`, `:qall`, or any normal exit of the final Neovim window.
Normal Ghostty tabs are not affected.

## First use on each Mac

1. Install compatible Ghostty and Neovim.
2. Clone the dotfiles repository and run `./install.sh`.
3. Open a text file with `Nvim.app`.
4. Approve the macOS Automation request allowing Nvim to control Ghostty.
5. In Finder, choose Nvim under Open With for a desired file type and use Change All when wanted.

Automation approval and Finder defaults are machine-local and are not transferred by this repository.
An ad hoc signature can change when launcher contents change, so macOS may request Automation approval again after an update.

## Portability

Only the launcher source is portable between Macs.
Do not copy the generated `Nvim.app`.
The bundled Swift helper is compiled for the current Mac's architecture, `osacompile` copies operating-system resources, and the local build receives a machine-local ad hoc signature.
The build accepts Apple silicon `arm64` and Intel `x86_64` hosts and passes the detected host architecture explicitly to `swiftc`.
On macOS 26 with Xcode 26, the build compiles the two appearance sources into native adaptive icon assets.
Older toolchains install the light `.icns` fallback because those macOS releases do not support the new adaptive app icon appearances.
Rebuilding on each Mac avoids macOS version, Gatekeeper, quarantine, code-signing, and Launch Services differences.
Automation approval and Finder file associations must still be configured on each device.
The Intel build path is structurally covered but still requires execution on an actual Intel Mac.

## Troubleshooting

If Automation was denied, open System Settings, go to Privacy & Security, then Automation, and enable Ghostty for Nvim.
To reset only this launcher's Apple Events decision, run `tccutil reset AppleEvents com.usmon.nvim-launcher`, then open a file again.

If Nvim does not appear under Open With, rebuild it with `nvim-app install`.
If needed, refresh Launch Services manually with:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$HOME/Applications/Nvim.app"
```

The build uses only repository source and standard macOS tools.
The Neovim mark is the [official artwork](https://github.com/neovim/neovim.github.io/blob/master/static/logos/neovim-mark.svg) by Jason Long and Neovim, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
The mark itself is unchanged; the launcher sources only scale it onto separate light and dark rounded backgrounds.
Temporary build resources live in a hidden staging directory under `~/Applications` and are removed after installation.
Ephemeral RPC sockets, reservations, session records, and single-use close requests live only under the private runtime state directory in `/tmp`.
No application bundle, signing identity, Automation state, Launch Services database, Finder preferences, or machine-specific path is stored in Git.

If a rooted session is not reused, run `nvim-app verify`, confirm its session socket exists under `/tmp/com.usmon.nvim-launcher-UID/sockets`, and check that the Neovim process still responds to that socket.
Stale state is normally removed on the next Finder open.
If the file opens remotely but the stored Ghostty terminal ID no longer exists, Nvim activates Ghostty and shows a notification instead of selecting an unrelated terminal or creating a duplicate editor.
