# Dino Royale

A 100-player Roblox battle royale with dinosaurs.

## Development Setup

1. Install Roblox Studio
2. Install Rojo plugin in Studio
3. Run `wally install` to get packages
4. Run `rojo serve` to start sync
5. Connect Rojo in Studio
6. Run `claude` to start AI-assisted development

## Commands

```bash
# Start Rojo sync server
rojo serve

# Install packages
wally install

# Lint code
selene src/

# Format code
stylua src/

# Start Claude Code
claude
```

## Project Structure

```
src/
├── server/     # ServerScriptService
├── client/     # StarterPlayerScripts
└── shared/     # ReplicatedStorage
```
