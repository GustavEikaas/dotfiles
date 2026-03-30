alias c='clear'
alias v='$EDITOR'
alias vim='$EDITOR'

_cpt_flags=(
  --allow-all-tools
  --deny-tool="shell(rm)"
  --deny-tool="shell(chmod)"
  --deny-tool="shell(git push)"
)

alias cpt='copilot "${_cpt_flags[@]}"'
alias cptr='copilot "${_cpt_flags[@]}" --resume'
