ghprc() {
  gh pr create --draft --fill
  gh pr view
}

ghprm() {
  if ! gh pr merge --squash -d; then
    if _confirm_yes_no "Pull Request still draft, mark as ready and merge?"; then
      gh pr ready
      gh pr merge --squash -d
    else
      echo "Aborting..."
      return 1
    fi
  fi

  ghprv
  if command -v ggrm >/dev/null 2>&1; then
    ggrm
  fi
}

ghpush() {
  local force_flag=false
  local OPTIND=1

  while getopts "F" opt; do
    case "$opt" in
      F) force_flag=true ;;
    esac
  done

  if _on_main_branch && [[ "$force_flag" == false ]]; then
    echo "On main branch, use -F flag to bypass"
    return 1
  fi

  git push

  if _on_main_branch; then
    git log -n 5 --oneline
    return 0
  fi

  if ! gh pr view >/dev/null 2>&1; then
    if _confirm_yes_no "No PR linked to branch, do you want to create a draft PR?"; then
      ghprc
    fi
  fi

  git log -n 5 --oneline
}

ghprch() {
  gh pr checkout "$@"
}

ghprd() {
  gh pr diff "$@"
}

ghprv() {
  gh pr view "$@"
}

ghrv() {
  gh repo view --web
}

ghprac() {
  local branch

  branch=$(_current_git_branch)
  if _on_protected_pr_branch "$branch"; then
    echo "You are on a protected branch ($branch). Switch to a feature branch."
    return 1
  fi

  git add .
  git commit -m "$*" || {
    echo "Commit failed. Aborting..."
    return 1
  }
  git push || {
    echo "Push failed. Aborting..."
    return 1
  }

  gh pr create --fill
  gh pr view
}
