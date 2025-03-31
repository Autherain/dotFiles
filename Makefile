# Makefile for dotfiles installation
.PHONY: all install theme tpm tmux git fzf dive k9s clean backup backup-lazyvim lazyvim
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

# Backup LazyVim
backup-lazyvim:
	@echo "Backing up LazyVim config..."
	@mkdir -p ./nvim-backup
	@[ -d ~/.config/nvim ] && cp -r ~/.config/nvim ./nvim-backup/config || echo "No nvim config to backup"
	@echo "LazyVim config backup completed and saved to repository"

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
	@if [ -d ./nvim-backup/config/nvim ]; then \
		cp -r ./nvim-backup/config/nvim/* ~/.config/nvim/; \
		echo "Installed LazyVim configuration from backup"; \
	else \
		echo "No LazyVim config files found in ./nvim-backup/config/nvim. Please run 'make backup-lazyvim' first"; \
		exit 1; \
	fi
	@echo "LazyVim configuration installed successfully"

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

# Install dive (Docker image explorer)
dive:
	@echo "Installing dive..."
	@if ! command -v dive >/dev/null 2>&1; then \
		if [ -f /etc/debian_version ]; then \
			wget https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.deb -O /tmp/dive.deb && \
			sudo apt install /tmp/dive.deb && \
			rm /tmp/dive.deb; \
		elif [ -f /etc/redhat-release ]; then \
			curl -OL https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.rpm && \
			sudo rpm -i dive_0.11.0_linux_amd64.rpm && \
			rm dive_0.11.0_linux_amd64.rpm; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install dive; \
		else \
			echo "Please install dive manually from https://github.com/wagoodman/dive"; \
		fi; \
	else \
		echo "dive is already installed"; \
	fi

# Install k9s (Kubernetes CLI UI)
k9s:
	@echo "Installing k9s..."
	@if ! command -v k9s >/dev/null 2>&1; then \
		if command -v snap >/dev/null 2>&1; then \
			sudo snap install k9s; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install k9s; \
		elif command -v go >/dev/null 2>&1; then \
			go install github.com/derailed/k9s@latest; \
		else \
			echo "Please install k9s manually from https://github.com/derailed/k9s"; \
		fi; \
	else \
		echo "k9s is already installed"; \
	fi

# Configure shell
install: theme tpm tmux git fzf dive k9s
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
