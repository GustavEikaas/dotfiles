_confirm_yes_no() {
  local response

  read -r -p "$1 (y/n): " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

_current_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

_on_main_branch() {
  [[ "$(_current_git_branch)" == "main" ]]
}

_on_protected_pr_branch() {
  [[ "$1" =~ ^(main|master|dev)$ ]]
}
