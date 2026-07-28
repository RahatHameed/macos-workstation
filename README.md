# macOS Setup Scripts

Automated macOS workstation setup with modular installation, dry-run support, and easy customization.

The macOS counterpart to [ubuntu-workstation](https://github.com/RahatHameed/ubuntu-workstation) — same architecture, same flags, same module names. See [Differences from the Ubuntu repo](#differences-from-the-ubuntu-repo) for what could not map 1:1.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/RahatHameed/macos-workstation/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/RahatHameed/macos-workstation.git
cd macos-workstation
./install.sh
```

## Features

- **Modular** - Install only what you need
- **Dry-run mode** - Preview changes before applying
- **Interactive mode** - Choose components during installation
- **Config file** - Customize via YAML config
- **Idempotent** - Safe to run multiple times
- **Reversible** - `uninstall.sh` undoes what the modules change

## What's Included

### Modules

| Module | Description |
|--------|-------------|
| `homebrew` | Homebrew + Xcode Command Line Tools (prerequisite) |
| `shell` | Zsh + Oh My Zsh + autosuggestions/syntax-highlighting |
| `git` | Git user, defaults, aliases, global `.DS_Store` ignore |
| `ssh` | SSH key generation + Keychain integration |
| `signing` | Signed commits via SSH key |
| `apps` | Chrome, Slack, Teams, JetBrains Toolbox, etc. |
| `docker` | Docker Desktop or Colima |
| `vpn` | Mullvad, NordVPN, or ProtonVPN |

### Available Applications

**Default (installed automatically):**

| App | Cask |
|-----|------|
| Google Chrome | `google-chrome` |
| Slack | `slack` |
| Microsoft Teams | `microsoft-teams` |
| Microsoft Outlook | `microsoft-outlook` |
| JetBrains Toolbox | `jetbrains-toolbox` |

**Optional (via config or interactive mode):**

| App | Cask |
|-----|------|
| VS Code | `visual-studio-code` |
| Discord | `discord` |
| Zoom | `zoom` |
| Postman | `postman` |
| Spotify | `spotify` |
| DBeaver | `dbeaver-community` |
| Rectangle | `rectangle` |
| iTerm2 | `iterm2` |
| Raycast | `raycast` |

### A note on casks that need sudo

Most casks just drop a `.app` into `/Applications` and need no password. A few
(Microsoft Teams among them) wrap a `.pkg` and shell out to `/usr/sbin/installer`
under `sudo`. In an unattended run there is no terminal for the prompt, so those
fail.

They no longer abort the rest of the run — the failure is recorded, the
remaining apps install, and a summary at the end lists what to re-run
interactively:

```
[!] The following casks did not install:
  - microsoft-teams

[i] Re-run these interactively so you can enter your password:

  brew install --cask microsoft-teams
```

## Usage

### Full Installation (defaults)

```bash
./install.sh
```

### Interactive Mode

```bash
./install.sh -i
```

### Install Specific Module

```bash
./install.sh -m homebrew   # Bootstrap Homebrew + Xcode CLT
./install.sh -m shell      # Only Zsh + Oh My Zsh
./install.sh -m git        # Only Git configuration
./install.sh -m ssh        # Only SSH setup
./install.sh -m signing    # Only commit signing
./install.sh -m apps       # Only applications
./install.sh -m docker     # Only Docker
./install.sh -m vpn        # Only VPN setup
```

### Dry-Run Mode

```bash
./install.sh --dry-run
./install.sh -m apps --dry-run
```

### Custom Config

```bash
cp config.example.yaml config.yaml
# Edit config.yaml to customize
./install.sh -c config.yaml
```

### Include Claude Code

```bash
./install.sh --claude
```

## Configuration

Copy `config.example.yaml` to `config.yaml` and customize:

```yaml
modules:
  homebrew: true
  shell: true
  apps: true
  docker: true

apps:
  - chrome
  - slack
  - teams
  - jetbrains-toolbox

docker:
  runtime: docker-desktop   # or colima
```

## Uninstall

```bash
./uninstall.sh              # Interactive mode
./uninstall.sh -m apps      # Uninstall specific module
./uninstall.sh --all        # Uninstall everything
./uninstall.sh --dry-run    # Preview changes
```

**Safe by default:**
- SSH keys are kept (remove manually if needed)
- Git user.name/email kept
- Homebrew itself is kept — other tooling likely depends on it
- Docker images and volumes are kept
- IPv6 is restored to automatic when the VPN is removed

## Directory Structure

```
macos-workstation/
├── install.sh              # Main installer
├── uninstall.sh            # Uninstaller
├── config.example.yaml     # Example configuration
├── LICENSE                 # MIT License
├── modules/
│   ├── common.sh           # Shared functions
│   ├── homebrew.sh         # Homebrew + Xcode CLT bootstrap
│   ├── shell.sh            # Zsh + Oh My Zsh
│   ├── git.sh              # Git configuration
│   ├── ssh.sh              # SSH key + keychain
│   ├── signing.sh          # Signed commits (SSH)
│   ├── apps.sh             # Work applications
│   ├── docker.sh           # Docker Desktop / Colima
│   └── vpn.sh              # VPN installation
├── startup/
│   └── startup-office.sh   # Login apps launcher (via LaunchAgent)
├── docker/
│   └── docker-cleanup.sh   # Port conflict diagnosis + prune (state and disk)
├── vpn/
│   ├── vpn-connect.sh      # VPN connection wrapper
│   ├── ipv6-toggle.sh      # IPv6 leak protection
│   └── providers/          # Pluggable VPN providers
│       ├── _template.sh    # Template for new providers
│       ├── mullvad.sh
│       ├── nordvpn.sh
│       └── protonvpn.sh
├── troubleshooting/        # Issue tracking and solutions
└── README.md
```

## Homebrew Module

The `homebrew` module has no Ubuntu equivalent and must run first:

- **Xcode Command Line Tools** - triggers the installer and *polls until it finishes* (the `xcode-select --install` dialog returns immediately, so a naive script races ahead)
- **Homebrew** - installed non-interactively
- **PATH setup** - Apple Silicon installs to `/opt/homebrew`, which is not on the default PATH; Intel installs to `/usr/local`, which is. The `brew shellenv` line is appended to `~/.zprofile` either way
- **Essentials** - `git`, `curl`, `wget`, `jq`, `mas`

## Git Module

Configures:

- **User setup** - Prompts for name/email if not set
- **Default branch** - Sets to `main`
- **Editor** - Auto-detects VS Code or vim
- **`core.precomposeunicode`** - macOS normalises filenames differently from Linux; without this, filenames with accents show as modified
- **Global gitignore** - `~/.gitignore_global` with `.DS_Store` and friends
- **Aliases:** `st`, `co`, `br`, `ci`, `lg`, `lga`, `df`, `dfs`, `unstage`, `last`

## SSH Module

- **Generates SSH key** (ed25519) if none exists
- **Stores the passphrase in the login Keychain** so the key unlocks automatically after a reboot
- **Sets up `~/.ssh/config`** with `AddKeysToAgent`, `UseKeychain`, and GitHub/GitLab hosts
- **Copies the public key to the clipboard** with `pbcopy`

There is no shell-rc `ssh-agent` block as on Linux — launchd already runs an agent for every session.

## Signing Module

Enables signed commits using your existing SSH key.

```yaml
signing:
  method: ssh   # ssh | none
```

Since git 2.34 you can sign commits with an SSH key (`gpg.format=ssh`). GitHub
verifies those signatures and renders the same **Verified** badge as GPG, with
nothing extra to install and no second keypair to back up.

### The GitHub gotcha

**You must add the same key to GitHub twice** — once as an *Authentication
key* and once as a *Signing key*. They are separate entries even though the
key material is byte-identical. With only the authentication entry your
pushes work but every commit shows as **Unverified**.

Both go through https://github.com/settings/ssh/new — just change the
**Key type** dropdown on the second one.

### What the module sets

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

The `allowed_signers` file is what makes **local** verification work. Without
it, git can produce signatures but `git log --show-signature` reports
`No principal matched` — GitHub still verifies fine, but you cannot check your
own history offline.

Verify with:

```bash
git log --show-signature -1
# Good "git" signature for you@example.com with ED25519 key SHA256:...
```

## Docker Module

macOS has no native Docker Engine — containers always run in a Linux VM. Two runtimes:

```yaml
docker:
  runtime: docker-desktop   # or colima
```

| | Docker Desktop | Colima |
|---|---|---|
| GUI | Yes | No |
| Kubernetes | Built in | Manual |
| Licence | Paid above Docker's company-size threshold | Open source |
| Resource control | GUI settings | `colima start --cpu 4 --memory 8` |

With Colima the module also links `docker-compose` and `docker-buildx` into `~/.docker/cli-plugins`, which Homebrew does not do.

## VPN Module

### macOS caveat: only Mullvad ships a CLI

On Linux all three providers have a real CLI. On macOS **only Mullvad does.**

| Provider | Install | Connect / disconnect | Status |
|----------|---------|----------------------|--------|
| Mullvad | `mullvad-vpn` cask | Full CLI control, including country/city | Exact, from the CLI |
| NordVPN | `nordvpn` cask | Opens the app — you click Connect | Tunnel detected via default route |
| ProtonVPN | `protonvpn` cask | Opens the app — you click Connect | Tunnel detected via default route |

If you want scripted VPN switching on macOS, use Mullvad. The other two are installed and configured, but `vpn-connect.sh connect` can only bring their window up.

Status detection for the GUI-only providers checks whether the default route runs over a `utun*` interface:

```bash
route -n get default | awk '/interface:/ {print $2}'
```

That is accurate for "a tunnel is up" but cannot tell you *which* provider or country, and it will also report true for other tunnels (iCloud Private Relay, a corporate VPN).


Set your provider in `config.yaml`:

```yaml
vpn:
  provider: mullvad          # mullvad, nordvpn, or protonvpn
  default_country: de
  default_city: ""
  auto_connect: false
  ipv6_disable: true
  account_number: ""
```

### VPN Connection Script

```bash
./vpn/vpn-connect.sh connect              # Connect to default country
./vpn/vpn-connect.sh connect de           # Connect to Germany
./vpn/vpn-connect.sh connect de fra       # Connect to Frankfurt
./vpn/vpn-connect.sh disconnect           # Disconnect
./vpn/vpn-connect.sh status               # Show status
./vpn/vpn-connect.sh is-connected         # Check connection (for scripts)
./vpn/vpn-connect.sh list-providers       # List available providers
```

Country/city arguments only take effect with Mullvad — see the VPN caveat above.

### IPv6 Leak Protection

VPNs often don't route IPv6 traffic, so your real IP leaks over it. On Linux this is a single sysctl; on macOS IPv6 is configured **per network service**, so `ipv6-toggle.sh` walks every active service with `networksetup`:

```bash
./vpn/ipv6-toggle.sh           # Apply config (disable if ipv6_disable: true)
./vpn/ipv6-toggle.sh disable   # Force disable IPv6
./vpn/ipv6-toggle.sh enable    # Restore IPv6 to automatic
./vpn/ipv6-toggle.sh status    # Per-service state + external IPv4/IPv6 + default route
```

**Requires sudo**, and unlike the Linux version the change is **already persistent** — there is no separate `persist` subcommand, because `networksetup` writes to the system network configuration rather than a runtime sysctl.

Because it needs sudo, `startup-office.sh` skips it silently at login when no password can be entered. If you want it applied at every login, either run it once manually (it persists) or add a sudoers rule.

### Adding a New VPN Provider

1. Copy the template:
   ```bash
   cp vpn/providers/_template.sh vpn/providers/myvpn.sh
   ```

2. Implement the required functions:
   ```bash
   provider_install()        # Install the VPN client
   provider_configure()      # Post-install setup instructions
   provider_connect()        # Connect to VPN
   provider_disconnect()     # Disconnect from VPN
   provider_status()         # Print status
   provider_is_connected()   # Return 0 if connected
   ```

3. Use it:
   ```bash
   VPN_PROVIDER=myvpn ./vpn/vpn-connect.sh connect
   ```

## Utility Scripts

### startup/startup-office.sh

Launches work apps at login: PhpStorm, Slack, Teams, Outlook, Chrome, Docker, iTerm2/Terminal. Apps that are not installed are skipped rather than erroring.

Not installed automatically — register it as a LaunchAgent yourself (the
script's header comment has the plist to paste). Then:

```bash
# Check it is loaded
launchctl list | grep startup-office

# Disable
launchctl unload ~/Library/LaunchAgents/com.workstation.startup-office.plist

# Logs
tail -f /tmp/startup-office.log
```

Apps open with `open -g` so they do not steal focus while you log in.

### docker/docker-cleanup.sh

```bash
./docker/docker-cleanup.sh                     # Prune networks, report port holders
./docker/docker-cleanup.sh --ports 80,443,3306 # Check specific ports
./docker/docker-cleanup.sh --remove-containers # Also force-remove ALL containers
./docker/docker-cleanup.sh --prune-cache       # Also clear build cache + dangling images
./docker/docker-cleanup.sh --prune-all         # As above, plus ALL unused images
./docker/docker-cleanup.sh --volumes           # Also remove unused volumes - DATA LOSS
./docker/docker-cleanup.sh --dry-run           # Report only, delete nothing
./docker/docker-cleanup.sh --prune-all --yes   # Skip the confirmation prompt
```

Unlike the Ubuntu version, removing containers is **opt-in**. The Linux script does it on every login; that is destructive enough that it should be a deliberate flag.

The script does two jobs, and only the first runs by default:

| | Default | Flags |
|---|---|---|
| Runtime state | port-conflict diagnosis, `network prune` | `--remove-containers` |
| Disk state | *nothing* | `--prune-cache`, `--prune-all`, `--volumes` |

That split exists because `startup-office.sh` runs this on every login. The default path never deletes anything you would miss and never prompts.

### Reclaiming disk

`--prune-cache` clears build cache, dangling images and stopped containers. `--prune-all` goes further: every unused image plus a full `docker builder prune -af`, because `system prune` alone leaves non-dangling build cache behind. `--volumes` is separate from both since it destroys data.

Anything destructive prompts for confirmation first — unless you pass `--yes`, or stdin is not a terminal. A non-interactive caller (login script, cron, CI) already stated its intent through the flags and must not block waiting on input.

macOS-specific caveat: containers live in a VM backed by a sparse disk image (`Docker.raw`, or colima's `diffdisk`). Pruning frees space *inside* the VM, but the host file only shrinks once the guest TRIMs it back, so `--prune-cache` prints the image size before and after. If it did not shrink, restart Docker Desktop — or `colima stop && colima start` — to trigger the TRIM.

Use `--dry-run` to see what would go before committing to it.

## Shell Aliases

Add to your `~/.zshrc`:

```bash
# Custom script aliases
alias docker-cleanup='$HOME/scripts/docker/docker-cleanup.sh'
alias vpn='$HOME/scripts/vpn/vpn-connect.sh'
alias ipv6='$HOME/scripts/vpn/ipv6-toggle.sh'
```

Then `source ~/.zshrc`.

| Alias | Script | Description |
|-------|--------|-------------|
| `docker-cleanup` | `docker/docker-cleanup.sh` | Diagnose port conflicts, prune networks and disk |
| `vpn` | `vpn/vpn-connect.sh` | VPN connection manager |
| `ipv6` | `vpn/ipv6-toggle.sh` | IPv6 leak protection |

## Requirements

- macOS 12 (Monterey) or newer
- Administrator account (sudo access)
- Internet connection

Both Apple Silicon and Intel are supported; the Homebrew prefix is detected automatically.

### A note on bash

macOS ships bash 3.2 (2007) at `/bin/bash` for licensing reasons. Every script here is written to run under it — no associative arrays, no `${var,,}`, and `sed -i ''` rather than GNU's `sed -i`. Keep that in mind when contributing.

## Post-Installation

1. **Open a new terminal** for shell and PATH changes to take effect
2. **Launch Docker.app once** to finish its setup and grant privileges
3. **Add your SSH key to GitHub** — it is already on your clipboard
4. **Sign into your VPN app** if using NordVPN or ProtonVPN

## Customization

### Add your own apps

Edit `modules/apps.sh`:

```bash
install_myapp() {
    cask_install "myapp" "MyApp"
}
```

Then add it to `install_apps()`, `install_apps_interactive()`, and `config.example.yaml`.

### Modify startup apps

Edit `startup/startup-office.sh`.

## License

MIT License - feel free to use and modify.

## Contributing

Contributions are welcome.

### Ideas for Contributions

| Area | Examples |
|------|----------|
| **New modules** | Node.js/nvm, Python/pyenv, Ruby/rbenv, Go, Rust |
| **New apps** | Add more casks to `modules/apps.sh` |
| **VPN providers** | Any vendor with a macOS CLI |
| **Dev tools** | Database clients, API tools, cloud CLIs |
| **Documentation** | Improve docs, add screenshots |
| **Bug fixes** | Fix issues, improve error handling |

### How to Contribute

1. **Fork** the repository
2. **Clone** your fork
3. **Create** a feature branch:
   ```bash
   git checkout -b feature/add-nodejs-module
   ```
4. **Make** your changes following the existing code style
5. **Test** your changes:
   ```bash
   ./install.sh -m your-module --dry-run
   bash -n modules/your-module.sh   # syntax check
   ```
6. **Commit** and open a **Pull Request**

### Adding a New Module

1. Create `modules/your-module.sh`:
   ```bash
   #!/bin/bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/common.sh"

   install_your_module() {
       print_section "Your Module"
       require_brew || return 1
       # Your installation logic
   }

   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
       install_your_module
   fi
   ```

2. Add to `install.sh` (`run_interactive`, `run_module`, `run_all`)
3. Add to `uninstall.sh`
4. Update `config.example.yaml`
5. Update `README.md`

### Guidelines

- Keep scripts **idempotent** (safe to run multiple times)
- Support **`--dry-run`** — route side effects through `run` or an explicit `$DRY_RUN` check
- Use functions from `modules/common.sh`
- **Every change must be reversible** in `uninstall.sh`
- Stay **bash 3.2 compatible**
- Add **error handling** for edge cases
