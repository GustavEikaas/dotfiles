ggp() {
  git pull "$@"
}

ggpm() {
  git pull origin main
}

ggu() {
  git reset --soft HEAD~
  git restore --staged .
}

gga() {
  git add "$@"
}

ggc() {
  git commit "$@"
}

ggs() {
  git status --porcelain -sb "$@"
}

ggch() {
  if [[ "$#" -ge 1 ]]; then
    git checkout "$@"
    return
  fi

  local selected_branch
  local selection
  local -a branches

  git fetch --all
  mapfile -t branches < <(git branch -r | grep -v 'HEAD' | sed 's/.*origin\///' | tr -d ' ')

  echo "Select a remote branch:"
  for i in "${!branches[@]}"; do
    echo "$((i + 1)). ${branches[$i]}"
  done

  read -r -p "Enter the number of the branch you want to select: " selection

  if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#branches[@]}" ]]; then
    selected_branch="${branches[$((selection - 1))]}"
    git checkout "$selected_branch"
  else
    echo "Invalid selection. Please enter a valid number."
    return 1
  fi
}

ggr() {
  local remote_tracking_branch

  git reset --hard
  git clean -f -d
  remote_tracking_branch=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)

  if [[ -n "$remote_tracking_branch" ]]; then
    ggp
  else
    echo "No remote tracking branch is set. Skipping pull."
  fi
}

ggrf() {
  local file_path="$1"
  local source_ref="${2:-origin/main}"

  if [[ -z "$file_path" ]]; then
    echo "Error: filePath parameter is mandatory."
    return 1
  fi

  git restore "$file_path" --source="$source_ref"
}

ggrm() {
  local base
  local current_branch

  ggr

  base=$(git branch --merged | sed 's/^[* ]*//' | grep -E '^(main|master|dev|develop|test)$' | head -n 1)
  current_branch=$(_current_git_branch)

  if [[ -z "$base" ]] && ! [[ "$current_branch" =~ ^(main|master|dev|develop|test)$ ]]; then
    echo "Failed to find common ancestor [main,master,dev,develop,test]"
    return 1
  fi

  if [[ -n "$base" ]] && [[ "$base" != "$current_branch" ]]; then
    ggch "$base"
  fi

  ggp
}

ggpush() {
  local bypass=false
  local arg
  local current_branch
  local -a pass_args=()

  for arg in "$@"; do
    if [[ "$arg" == "-F" ]]; then
      bypass=true
    else
      pass_args+=("$arg")
    fi
  done

  current_branch=$(_current_git_branch)
  if [[ "$current_branch" == "main" ]] && [[ "$bypass" == false ]]; then
    echo "On main branch, use -F flag to bypass"
    return 1
  fi

  git push "${pass_args[@]}"
  git log -n 5 --oneline
}

ggac() {
  local text="$1"

  if [[ -z "$text" ]]; then
    echo 'Error: Commit message required. Usage: ggac "Your message here"'
    return 1
  fi

  ggs
  git add .
  git commit -m "$text"
}

ggd() {
  git diff "$@"
}

gitstats() {
  echo "What do you want to know?"
  PS3="Enter a number (1-6): "
  
  options=(
    "Top 20 most-changed files (last year)"
    "Top contributors"
    "Top 20 bug-prone files"
    "Commit count by month"
    "Firefighting commits (last year)"
    "Quit"
  )

  select opt in "${options[@]}"; do
    case $REPLY in
      1)
        echo -e "\n📊 Top 20 most-changed files in the last year:"
        git log --format=format: --name-only --since="1 year ago" | sort | uniq -c | sort -nr | head -20
        break
        ;;
      2)
        echo -e "\n🏆 Top contributors (excluding merges):"
        git shortlog -sn --no-merges
        break
        ;;
      3)
        echo -e "\n🐛 Top 20 files associated with bug fixes:"
        git log -i -E --grep="fix|bug|broken" --name-only --format='' | sort | uniq -c | sort -nr | head -20
        break
        ;;
      4)
        echo -e "\n📅 Commit count by month:"
        git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
        break
        ;;
      5)
        echo -e "\n🔥 Firefighting commits in the last year:"
        git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
        break
        ;;
      6)
        echo "Exiting..."
        break
        ;;
      *)
        echo "Invalid option. Please enter a number between 1 and 6."
        ;;
    esac
  done
}
