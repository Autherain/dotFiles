# Makefile for dotfiles installation
.PHONY: all install theme tpm tmux git fzf dive k9s yazi zed lazygit delta clean backup
# Default target
all: backup install

# Backup existing configurations
backup:
	@echo "Creating backup of existing configurations..."
	@mkdir -p ~/.dotfiles_backup
	@[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml ~/.dotfiles_backup/ || true
	@[ -f ~/.gitconfig ] && cp ~/.gitconfig ~/.dotfiles_backup/ || true
	@[ -f ~/.gitconfig-delta ] && cp ~/.gitconfig-delta ~/.dotfiles_backup/ || true
	@[ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/.dotfiles_backup/ || true
	@[ -f ~/.gitignore_global ] && cp ~/.gitignore_global ~/.dotfiles_backup/ || true
	@[ -d ~/.config/yazi ] && cp -r ~/.config/yazi ~/.dotfiles_backup/ || true
	@[ -d ~/.config/zed ] && cp -r ~/.config/zed ~/.dotfiles_backup/ || true
	@[ -f ~/.config/lazygit/config.yml ] && cp ~/.config/lazygit/config.yml ~/.dotfiles_backup/ || true
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
	@echo "  - Press Ctrl+q+r to reload tmux config"
	@echo "  - Press Ctrl+q+I to install plugins"
	@echo "  - Visit https://github.com/tmux-plugins/tmux-yank for copy-paste setup"



# Configure git
git:
	@echo "Configuring git..."
	@cp .gitconfig .gitconfig-delta .gitignore_global ~
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

# Install yazi (terminal file manager)
yazi:
	@echo "Installing yazi..."
	@if ! command -v yazi >/dev/null 2>&1; then \
		if command -v brew >/dev/null 2>&1; then \
			brew install yazi ffmpeg sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick; \
		elif command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick --noconfirm; \
		elif command -v snap >/dev/null 2>&1; then \
			sudo snap install yazi --classic; \
		else \
			echo "Please install yazi manually: https://yazi-rs.github.io/docs/installation"; \
		fi; \
	else \
		echo "yazi is already installed"; \
	fi
	@echo "Installing Catppuccin Mocha theme for yazi..."
	@mkdir -p ~/.config/yazi
	@cp yazi/theme.toml yazi/yazi.toml ~/.config/yazi/
	@cp yazi/Catppuccin-mocha.tmTheme ~/.config/yazi/
	@echo "Yazi theme and config installed"

# Install delta (git diff pager)
delta:
	@echo "Installing delta..."
	@if ! command -v delta >/dev/null 2>&1; then \
		if [ -f /etc/debian_version ]; then \
			sudo apt install -y git-delta; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install git-delta; \
		elif command -v pacman >/dev/null 2>&1; then \
			sudo pacman -S git-delta --noconfirm; \
		else \
			echo "Please install delta manually from https://github.com/dandavison/delta/releases"; \
		fi; \
	else \
		echo "delta is already installed"; \
	fi

# Configure lazygit
lazygit:
	@echo "Configuring lazygit..."
	@mkdir -p ~/.config/lazygit
	@cp lazygit/config.yml ~/.config/lazygit/config.yml
	@echo "Lazygit configuration installed"

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
install: theme tpm tmux git fzf dive k9s yazi zed lazygit delta
	@echo "Configuring shell..."
	@if ! grep -q "stty -ixon" ~/.bashrc; then \
		echo 'stty -ixon # Disable XON/XOFF so Ctrl+q reaches tmux' >> ~/.bashrc; \
	fi
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
	@if ! grep -q "alias y='yazi'" ~/.bashrc; then \
		echo "alias y='yazi'" >> ~/.bashrc; \
	fi
	@if ! grep -q "zoxide init bash" ~/.bashrc; then \
		echo 'eval "$$(zoxide init bash)"' >> ~/.bashrc; \
	fi
	@if ! grep -q "alias g='git'" ~/.bashrc; then \
		echo "alias g='git'" >> ~/.bashrc; \
	fi
	@if ! grep -q "alias lg='lazygit'" ~/.bashrc; then \
		echo "alias lg='lazygit'" >> ~/.bashrc; \
	fi
	@if ! grep -q "alias k='kubecolor'" ~/.bashrc; then \
		echo "alias k='kubecolor'" >> ~/.bashrc; \
	fi
	@if ! grep -q "alias kctx" ~/.bashrc; then \
		echo "alias kctx='kubectl ctx'" >> ~/.bashrc; \
	fi
	@if ! grep -q "alias kns" ~/.bashrc; then \
		echo "alias kns='kubectl ns'" >> ~/.bashrc; \
	fi
	@if ! grep -q "kubectl completion bash" ~/.bashrc; then \
		echo 'if command -v kubectl &>/dev/null; then' >> ~/.bashrc; \
		echo '  source <(kubectl completion bash)' >> ~/.bashrc; \
		echo '  complete -o default -F __start_kubectl kubectl' >> ~/.bashrc; \
		echo '  complete -o default -F __start_kubectl k' >> ~/.bashrc; \
		echo '  complete -o default -F __start_kubectl kubecolor' >> ~/.bashrc; \
		echo 'fi' >> ~/.bashrc; \
	fi
	@if ! grep -q '\.local/bin' ~/.bashrc; then \
		echo 'export PATH=$$HOME/.local/bin:$$PATH' >> ~/.bashrc; \
	fi
	@if ! grep -q 'KREW_ROOT' ~/.bashrc; then \
		echo 'PATH="$${KREW_ROOT:-$$HOME/.krew}/bin:$$PATH"' >> ~/.bashrc; \
	fi
	@echo "Shell configuration completed"

# Configure Zed editor
zed:
	@echo "Configuring Zed..."
	@mkdir -p ~/.config/zed
	@cp zed/settings.json ~/.config/zed/settings.json
	@cp zed/keymap.json ~/.config/zed/keymap.json
	@echo "Zed configuration installed"

# Clean installed configurations
clean:
	@echo "Cleaning up configurations..."
	@rm -f ~/.config/starship.toml
	@rm -rf ~/.config/yazi
	@rm -f ~/.tmux.conf
	@rm -f ~/.gitconfig ~/.gitconfig-delta ~/.gitignore_global
	@rm -rf ~/.config/zed
	@rm -f ~/.config/lazygit/config.yml
	@echo "Cleanup completed"
