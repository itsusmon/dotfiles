# Mac scripts

`./install.sh` links these commands from `scripts/bin` into `~/.local/bin` on a new Mac.

```sh
cycle                 # Battery cycles and averages since initial setup
```

`cycle` reads the MacBook battery through `ioreg`.
Its activation date is an approximation based on `/var/db/.AppleSetupDone`, and may change after reinstalling macOS.
It reports an error if the setup marker or battery cycle count is unavailable.


```sh
python3 scripts/verify-cycle.py
```

```sh
since 6-10-26                 # Calendar days between this date and today
since 6 Oct 2026 at 1:34pm    # Include elapsed hours and minutes
since yesterday 12:34:56     # Include seconds when supplied
```

`since` accepts day-first dates, ISO dates, month names, and `today`, `yesterday`, or `tomorrow`.
Times accept 24-hour or AM/PM notation, including compact forms such as `1234`.
Missing years use the current year, and two-digit years mean 2000-2099.
Time-only inputs use today, and elapsed durations use the local timezone.
The difference is always positive, including future dates, and is rounded down to minutes or seconds when a time is supplied.
It requires Python 3 with no extra packages; run `since --help` for details.

```sh
python3 scripts/verify-since.py
```

```sh
update                # Update supported developer tools and apps
update --check        # Check availability without installing updates
update --dry-run      # Preview selected steps without network access
update --verbose      # Stream full output (also works with --check)
```

`update` works with macOS Bash 3.2 and discovers tools from `PATH` and standard user directories.
It shows compact emoji status lines and elapsed time, continues after failures, and exits 1 if any step failed.
Every run ends with its total elapsed time in minutes and seconds, including failed or cancelled runs.
Failures include the last eight nonblank output lines and a path to the full log.
Check results and report-only steps remain visible.
Logs numbered in execution order and named after each step (for example, `01-homebrew-metadata.log` and `02-homebrew-formulae.log`) are saved in the temporary directory printed at the end; use `--verbose` to stream them live.
Ctrl-C stops the active step and its children, then exits 130 without starting another update.
Homebrew confirms upgrades automatically, and npm's routine notices and funding messages are suppressed.
Run it as your normal user; app installers and `mas` may request administrator authentication when required.
Check mode may refresh package metadata, but never invokes an updater or loads Neovim's user configuration.
A `MANUAL` result means availability or installation could not be automated safely, not that the tool is current.

Automatic updates cover Homebrew formulae and casks, App Store apps through an existing `mas` installation, npm globals, activated Corepack package managers, NVM release installations, Node within its current major, Rustup toolchains, Android CLI/SDK, standalone NextDNS, known Git-installed Zsh plugins, Git-installed fzf, and configured lazy.nvim/Mason/Tree-sitter components.
Android SDK updates use the stable channel with `android sdk update`; forced downgrades remain disabled.
Homebrew-owned Android CLI and NextDNS binaries are updated through Homebrew, without running their separate self-updaters.
Existing pipx and uv tool installations and cargo-update are also supported when present.
Node-based checks use the installed Node runtime; GitHub skill checks require Node 18 or newer.
Global skill updates select only tracked skills that still exist in the shared skills directories.
The Skills CLI's `check` alias is deliberately avoided because some releases perform updates through that alias.

Homebrew cask updates use `--greedy` to include apps with built-in updaters and unversioned casks.
This includes JetBrains Toolbox when installed as the `jetbrains-toolbox` cask; Toolbox continues to manage its IDE installations.
App Store updates run only when `mas` is installed; otherwise they are silently omitted.
Both become availability checks in `--check` mode.
Python user packages update together through pip's dependency resolver, followed by `pip check`.
When `~/.local/share/python` exists, its dedicated default environment is maintained instead.
Check mode previews the same resolution without installing anything.
Active virtual environments and editable installs are left untouched; pip's externally managed environment protection is never overridden.
On Python runtimes without OpenSSL 1.1.1+, urllib3 stays below version 2 for TLS compatibility.
Apple Command Line Tools updates are installed by their exact `Command Line Tools for Xcode` labels; `sudo` may request administrator authentication.
Check mode only reports matching labels.
macOS upgrades and other system updates are never selected or displayed.
Unmanaged binaries, manually installed JDKs, IDE plugins, and tools without a verified read-only check are reported for manual attention.
There is no separate global npx installation to update; cached commands are never launched just to update them.
The script does not install missing managers, migrate installation methods, edit project dependencies, remove old runtimes, force Git changes, or clear caches.
Exact NVM default pins, versioned Rust toolchains, Homebrew pins, and lazy.nvim configuration remain in effect.
Existing local changes in Git-installed tools cause that step to fail without overwriting them.

```sh
python3 scripts/verify-update.py
python3 scripts/verify-nvm.py
shellcheck scripts/bin/update
```

The verification uses temporary homes and fake commands, including failed updates and interrupted runs.
It does not install updates or access the network.
