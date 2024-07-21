# Makefile for dotfiles installation
.PHONY: all install theme tpm tmux git fzf clean backup

# Default target
all: backup install

# Backup existing configurations
backup:
	@echo "Creating backup of existing configurations..."
	@mkdir -p ~/.dotfiles_backup
	@[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml ~/.dotfiles_backup/ || true
	@[ -f ~/.gitconfig ] && cp ~/.gitconfig ~/.dotfiles_backup/ || true
	@[ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/.dotfiles_backup/ || true
	@[ -f ~/.gitignore_global ] && cp ~/.gitignore_global ~/.dotfiles_backup/ || true
	@echo "Backup completed"

# Install starship theme
theme:
	@echo "Installing starship theme..."
	@mkdir -p ~/.config
	@cp starship.toml ~/.config/starship.toml
	@echo "Starship theme installed"

# Install Tmux Plugin Manager
tpm:
	@echo "Installing TPM..."
	@if [ ! -d ~/.tmux/plugins/tpm ]; then \
		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; \
	else \
		echo "TPM already installed"; \
	fi

# Configure tmux
tmux: tpm
	@echo "Configuring tmux..."
	@cp .tmux.conf ~/.tmux.conf
	@echo "Remember to:"
	@echo "  - Press Ctrl+a+r to reload tmux config"
	@echo "  - Press Ctrl+a+I to install plugins"
	@echo "  - Visit https://github.com/tmux-plugins/tmux-yank for copy-paste setup"

# Install LazyVim configuration
lazyvim:
	@echo "Installing LazyVim configuration..."
	@mkdir -p ~/.config/nvim
	@cp lazy-lock.json ~/.config/nvim/
	@echo "LazyVim configuration installed"

# Configure git
git:
	@echo "Configuring git..."
	@cp .gitconfig .gitignore_global ~
	@echo "Git configuration installed"

# Install fzf
fzf:
	@echo "Installing fzf..."
	@if ! command -v fzf >/dev/null 2>&1; then \
		echo "Please install fzf from https://github.com/junegunn/fzf"; \
	else \
		echo "fzf is already installed"; \
	fi

# Configure shell
install: theme tpm tmux git fzf
	@echo "Configuring shell..."
	@if ! grep -q "starship init bash" ~/.bashrc; then \
		echo 'eval "$$(starship init bash)"' >> ~/.bashrc; \
	fi
	@if ! grep -q "alias ta='tmux attach'" ~/.bashrc; then \
		echo "alias ta='tmux attach'" >> ~/.bashrc; \
	fi
	@if ! grep -q "fzf --bash" ~/.bashrc; then \
		echo 'eval "$$(fzf --bash)"' >> ~/.bashrc; \
	fi
	@if ! grep -q "alias n='nvim'" ~/.bashrc; then \
		echo "alias n='nvim'" >> ~/.bashrc; \
	fi
	@if ! grep -q "zoxide init bash" ~/.bashrc; then \
		echo 'eval "$$(zoxide init bash)"' >> ~/.bashrc; \
	fi
	@echo "Shell configuration completed"

# Clean installed configurations
clean:
	@echo "Cleaning up configurations..."
	@rm -f ~/.config/starship.toml
	@rm -f ~/.tmux.conf
	@rm -f ~/.gitconfig ~/.gitignore_global
	@echo "Cleanup completed"
