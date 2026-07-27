# Troubleshooting Notes

Documentation for known issues and their solutions, mirroring the
`troubleshooting/` directory in the Ubuntu repo.

| File | Issue |
|------|-------|
| _(none yet)_ | |

## Adding a note

Create `troubleshooting/<short-name>.md` with:

```markdown
# <Issue title>

**Symptom:** what you observe
**Affects:** macOS version, hardware, app version
**Cause:** why it happens
**Fix:** the steps that resolve it
**Reference:** any upstream issue or docs link
```

Then add a row to the table above and to the table in the main README.

## Quick diagnostics

```bash
# Which Homebrew prefix is in use
brew --prefix

# Anything broken in the Homebrew install
brew doctor

# Is a LaunchAgent loaded
launchctl list | grep workstation

# What is holding a port
lsof -nP -iTCP:8080 -sTCP:LISTEN

# Is the default route a tunnel (VPN active)
route -n get default | awk '/interface:/ {print $2}'

# Read a defaults key this repo sets
defaults read com.apple.dock tilesize
```
