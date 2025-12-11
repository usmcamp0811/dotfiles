# fino-root.zsh-theme
# Root-specific version of fino theme with distinctive styling

# Use with a dark background and 256-color terminal!
# Borrowing from fino.zsh-theme but with root-specific modifications

function virtualenv_prompt_info {
  [[ -n ${VIRTUAL_ENV} ]] || return
  echo "${ZSH_THEME_VIRTUALENV_PREFIX:=[}${VIRTUAL_ENV:t}${ZSH_THEME_VIRTUALENV_SUFFIX:=]}"
}

function prompt_char {
  command git branch &>/dev/null && echo "🚧" || echo "⚡"
}

function box_name {
  local box="${SHORT_HOST:-$HOST}"
  [[ -f ~/.box-name ]] && box="$(< ~/.box-name)"
  echo "${box:gs/%/%%}"
}

local ruby_env='$(ruby_prompt_info)'
local git_info='$(git_prompt_info)'
local virtualenv_info='$(virtualenv_prompt_info)'
local prompt_char='$(prompt_char)'

# ROOT PROMPT - Red theme with radioactive emoji for high visibility
PROMPT="${FG[196]}╭─☢️  ${FG[196]}%B%n%b ${FG[196]}on ${FG[196]}$(box_name) ${FG[196]}in %B${FG[226]}%~%b${git_info}${ruby_env}${virtualenv_info}
${FG[196]}╰─${prompt_char}%{$reset_color%} "

ZSH_THEME_GIT_PROMPT_PREFIX=" ${FG[196]}on%{$reset_color%} ${FG[255]}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="${FG[196]}🔥"
ZSH_THEME_GIT_PROMPT_CLEAN="${FG[196]}✔️"

ZSH_THEME_RUBY_PROMPT_PREFIX=" ${FG[196]}using${FG[196]} ‹"
ZSH_THEME_RUBY_PROMPT_SUFFIX="›%{$reset_color%}"

export VIRTUAL_ENV_DISABLE_PROMPT=1
ZSH_THEME_VIRTUALENV_PREFIX=" ${FG[196]}using${FG[196]} «"
ZSH_THEME_VIRTUALENV_SUFFIX="»%{$reset_color%}"
