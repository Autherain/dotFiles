# Dotfiles

Personal configuration files for development environment setup.

## Components

- **Shell**: Starship prompt
- **Git**: Global config and ignore files
- **Tmux**: Terminal multiplexer with Catppuccin theme
- **Neovim**: LazyVim-based configuration
- **Makefile**: Easy installation and backup

## Quick Start

1. Clone this repository:

   ```bash
   git clone <repository-url> ~/.dotfiles
   cd ~/.dotfiles
   ```

2. Install everything:

   ```bash
   make install
   ```

   Or individual components:

   ```bash
   make theme   # Starship
   make tmux    # Tmux config
   make git     # Git config
   make lazyvim # Neovim config
   ```

## Backup & Cleanup

Your existing configs are backed up to `~/.dotfiles_backup/` automatically.

Manual backup:

```bash
make backup
make backup-lazyvim  # For Neovim config
```

Remove installed configs:

```bash
make clean
```

## Features

- Tmux: Session management, mouse support, vim-like navigation, session persistence
- Neovim: LSP support, code formatting, Git integration, file navigation
- Git: Global ignore patterns, pull rebase, auto-setup remote
