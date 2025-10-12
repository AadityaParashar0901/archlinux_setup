#  Aaditya's Terminal Theme (Green on Black)

# Font hint (Roboto Mono is installed)
export TERMINAL_FONT="Roboto Mono"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Color scheme (neon green on black)
BLACK='\[\e[0;30m\]'
GREEN='\[\e[38;5;46m\]'
WHITE='\[\e[0;37m\]'
RESET='\[\e[0m\]'

# Simple custom prompt
# Shows: [user@host ~/currentdir] $
PS1="${GREEN}[\u@\h ${WHITE}\w${GREEN}]${WHITE}\$ ${RESET}"

# Quality-of-life aliases

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias ..='cd ..'
alias ...='cd ../../'

alias update='sudo pacman -Syu'
alias edit='nano'

# Neofetch on shell start
if command -v neofetch &> /dev/null; then
  neofetch --ascii_distro arch_small --color_blocks off --stdout
fi

# Fancy ASCII welcome banner
clear
echo -e "${GREEN}"
cat <<'EOF'
Welcome back, Aaditya
Stay curious. Keep building.
EOF
echo -e "${RESET}"
echo -e "${GREEN}Welcome, Aaditya - your system is ready.${RESET}"
echo

# End of file
