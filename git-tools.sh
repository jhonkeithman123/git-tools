#!/bin/bash

VERSION="1.0.0"

# Git Tools CLI by Keith

#* Functions

function configure_git_user() {
  echo "🔧 Starting Git user setup..."

  read -p "Enter your Git username: " username
  read -p "Enter your Git email: " email
  read -p "Enter your Git token: " token
  echo ""

  # Check if user.name and user.email are already set
  existing_name=$(git config --global user.name)
  existing_email=$(git config --global user.email)

  if [[ -n "$existing_name" || -n "$existing_email" ]]; then
    echo "Existing configuration found:"
    echo "🧑‍💻 Username: $existing_name"
    echo "📧 Email: $existing_email"
    read -p "Do you want to overwrite it? (y/N): " overwrite

    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
      git config --global user.name "$username"
      git config --global user.email "$email"
      echo "✅ Git global config updated."
    else
      echo "Would you like to create a local config instead?"
      read -p "Enter path to your project (leave blank to skip): " project_path

      if [[ -n "$project_path" && -d "$project_path" ]]; then
        cd "$project_path"
        git config user.name "$username"
        git config user.email "$email"
        echo "✅ Local Git config updated for $project_path."
      else
        echo "❌ Invalid project path. Skipping local config."
      fi
    fi
  else
    git config --global user.name "$username"
    git config --global user.email "$email"
    echo "✅ Git global config set."
  fi

  git config --global credential.helper store
  read -p "Enter the Git repository URL (or leave blank to skip storing credentials): " repo_url

  if [[ -n "$repo_url" ]]; then
    echo "$repo_url" > ~/.git-credentials
    echo "username=$username" >> ~/.git-credentials
    echo "password=$token" >> ~/.git-credentials
    echo "🔐 Credentials saved for $repo_url"

  else
    echo "username=$username" > ~/.git-credentials
    echo "password=$token" >> ~/.git-credentials

    echo "🔐 Credentials saved without a specific repository URL."
  fi

  echo "🔒 Credentials stored using 'store' helper."
}

case "$1" in
  --version)
    echo "Git Tools CLI version $VERSION"
    exit 0
    ;;
  list-commits)
    git log --oneline --graph --decorate --all --color
    ;;

  prev-commit)
    echo "⚠️ Reverting to previous commit (soft reset)..."
    git reset --soft HEAD~1
    ;;

  undo-last-commit)
    echo "⚠️ Undoing last commit (soft reset)..."
    git reset --soft HEAD~1
    ;;

  current-branch)
    git rev-parse --abbrev-ref HEAD
    ;;

  commit-push*)
    # 1) Extract built-in message if caller used commit-push:Your message
    if [[ "$1" == commit-push:* ]]; then
      preset_msg="${1#commit-push:}"
    else
      preset_msg=""
    fi
    shift  # Drop the commit-push token

    # 2) Parse flags
    dry_run=false; confirm=false; verbose=false
    for a in "$@"; do
      case "$a" in
        --dry-run)  dry_run=true  ;;
        --confirm)  confirm=true  ;;
        --verbose)  verbose=true  ;;
      esac
    done

    # 3) Remove flags from positional args
    positional=()
    for a in "$@"; do
      [[ "$a" != "--dry-run" && "$a" != "--confirm" && "$a" != "--verbose" ]] && positional+=("$a")
    done

    # 4) Load existing remotes and branches
    mapfile -t remotes  < <(git remote)
    mapfile -t branches < <(git branch --format='%(refname:short)')

    msg=""; remote=""; branch=""

    # 5) Identify each positional argument
    for a in "${positional[@]}"; do
      if [[ -z "$msg" && ( "$a" =~ ^\".*\"$ || "$a" =~ [[:space:]] ) ]]; then
        # Quoted string or contains space → commit message
        msg="${a%\"}"  
        msg="${msg#\"}"
      elif [[ -z "$remote" && " ${remotes[*]} " == *" $a "* ]]; then
        # Matches a remote name
        remote="$a"
      elif [[ -z "$branch" && " ${branches[*]} " == *" $a "* ]]; then
        # Matches a branch name
        branch="$a"
      elif [[ -z "$msg" ]]; then
        # Fallback: first unassigned → message
        msg="$a"
      fi
    done

    # 6) If no msg from positionals but preset exists, use it
    [[ -z "$msg" && -n "$preset_msg" ]] && msg="$preset_msg"

    # 7) Ordinal suffix helper
    ordinal_suffix() {
      n=$1
      if (( n == 0 )); then echo "initial"; return; fi
      last_two=$((n % 100))
      if (( last_two >= 11 && last_two <= 13 )); then suffix="th"
      else
        case $((n % 10)) in
          1) suffix="st" ;;
          2) suffix="nd" ;;
          3) suffix="rd" ;;
          *) suffix="th" ;;
        esac
      fi
      echo "${n}${suffix}"
    }

    # 8) Ensure we're in a Git repo
    if [ ! -d .git ]; then
      echo "❌ Not a Git repository. Run 'git init' first."
      exit 1
    fi

    # 9) Handle empty repo (no commits yet)
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      echo "📁 Empty repository detected."
      git_user_name=$(git config user.name)
      git_user_email=$(git config user.email)
      if [ -z "$git_user_name" ]; then
        read -p "👤 Enter your name for Git: " input_name
        git config user.name "$input_name"
      fi
      if [ -z "$git_user_email" ]; then
        read -p "📧 Enter your email for Git: " input_email
        git config user.email "$input_email"
      fi
    fi

    # 10) Auto-detect or prompt for remote
    if [ -z "$remote" ]; then
      if [ ${#remotes[@]} -eq 0 ]; then
        read -p "📡 No remotes. Name [default origin]: " input_r
        remote="${input_r:-origin}"
        read -p "🔗 Remote URL: " url
        git remote add "$remote" "$url"
      elif [ ${#remotes[@]} -gt 1 ]; then
        echo "⚠️ Multiple remotes: ${remotes[*]}"
        read -p "👉 Choose remote [default ${remotes[0]}]: " sel
        remote="${sel:-${remotes[0]}}"
      else
        remote="${remotes[0]}"
      fi
    fi

    # 11) Auto-detect or prompt for branch
    if [ -z "$branch" ]; then
      current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -z "$current" ] || [ "$current" == "HEAD" ]; then
        read -p "🌿 No branch. Name [default main]: " input_b
        branch="${input_b:-main}"
        git checkout -b "$branch"
      else
        branch="$current"
      fi
    fi

    # 12) Auto-generate commit message if empty
    if [ -z "$msg" ]; then
      count=$(git rev-list --count HEAD 2>/dev/null || echo 0)
      ord=$(ordinal_suffix "$count")
      if (( count == 0 )); then
        msg="initial commit"
      else
        msg="$count commits made: ${ord} commit"
      fi
    fi

    # 13) Show summary
    echo "📝 Commit message: \"$msg\""
    echo "📦 Remote:        $remote"
    echo "🌿 Branch:        $branch"
    $dry_run && { echo "🔍 Dry run – exiting."; exit 0; }

    # 14) Stage, commit, and optionally show diff
    git add .
    $verbose && { echo "🔍 Staged changes:"; git diff --staged; echo; }
    git commit -m "$msg"

    # 15) Confirm before push if requested
    if $confirm; then
      while true; do
        read -p "❓ Push to $remote/$branch? [y/n/r/b]: " choice
        case "$choice" in
          [Yy]) break ;;
          [Nn]) echo "❌ Push cancelled."; exit 0 ;;
          [Rr]) git remote -v ;;
          [Bb]) git branch -a ;;
          *) echo "⚠️ Enter y, n, r, or b." ;;
        esac
      done
    fi

    # 16) Push and handle rebase on failure
    echo "🚀 Pushing to $remote/$branch..."
    if git push "$remote" "$branch"; then
      echo "✅ Push successful."
    else
      echo "⚠️ Push failed. Rebasing and retrying..."
      git pull --rebase "$remote" "$branch" && git push "$remote" "$branch" \
        && echo "✅ Push successful after rebase." \
        || echo "❌ Still failed. Resolve conflicts manually."
    fi
    ;;

  stash-safe)
    echo "🔒 Trying to apply stash safety..."
    if git stash apply --index; then 
      git stash drop
      echo "✅ Stash applied and dropped."
    else
      echo "❌ Stash could not be applied cleanly. Keeping it intact."
    fi
    ;;

  configure-user)
    configure_git_user
    ;;
  
  sync)
    branch=$(git rev-parse --abbrev-ref HEAD)
    remote=$(git remote show | head -n 1)

    if [ -z "$remote" ]; then
      echo "❌ No remote found. Are you in a Git repo?"
      exit 1
    fi
    
    echo "🔄 Syncing with remote branch" '$branch...'
    git pull --rebase "$remote" "$branch"
    ;;

  squash)
    if [ -z "$2" ]; then
      echo "Usage: git-tools squash <N>"
      exit 1
    fi
    echo "🧬 Squashing last $2 commits..."
    git rebase -i HEAD~"$2"
    ;;

  help|--help|-h)
    echo "🛠️ Git Tools CLI"
    echo "Usage:"
    echo "  git-tools list-commits                                # Show recent commits in one-line format"
    echo "  git-tools prev-commit                                 # Soft reset to previous commit"
    echo "  git-tools undo-last-commit                            # Undo last commit but keep changes staged"
    echo "  git-tools current-branch                              # Show current Git branch"
    echo "  git-tools commit-push \"message\" <remote> <branch>   # Add, commit, and push in one step"
    echo "  git-tools stash-safe                                  # Apply stash only if clean, then drop"
    echo "  git-tools sync                                        # Pull and rebase from origin/<current-branch>"
    echo "  git-tools squash <N>                                  # Interactively squash last N commits"
    echo "  git-tools commit-push[:msg] [--dry-run] [--confirm] [--verbose] [<remote>] [<branch>]  # Commit and push, auto-rebase on conflicts"
    echo "  git-tools {--h|-help} git <--all | help | (category 'add, commit, etc.') | --export | (leave blank)>"
    echo "  git-tools configure-user                              # Configure Git user identity and credentials"
    echo "  git-tools --version                                   # Show version of Git Tools CLI"
    ;;

  --h|-help)
    if [[ "$2" == "git" ]]; then
      category="$3"

      show_all_categories() {
        echo "📚 Git Help Categories:"
        echo "  add       → Staging files"
        echo "  commit    → Saving changes"
        echo "  branch    → Working with branches"
        echo "  remote    → Connecting to remotes"
        echo "  pushpull  → Syncing with remotes"
        echo "  stash     → Temporary changes"
        echo "  config    → Git identity & settings"
        echo "  misc      → Other useful commands"
        echo
        echo "👉 Usage: git-tools --h git <category>"
        echo "👉 Or:    git-tools --h git --all"
      }

      show_category() {
        case "$1" in
        add)
           echo -e "\n📂 Category: add"
            cat <<EOF
🔹 git add <file>
    → Stages a specific file for commit.

🔹 git add .
    → Stages all changed files.
EOF
          ;;
        commit)
          echo -e "\n📂 Category: commit"
          cat <<EOF
🔹 git commit -m "message"
    → Saves your staged changes with a message.

🔹 git reset --soft HEAD~1
    → Undoes the last commit but keeps your changes staged.
EOF
          ;;
        branch)
          echo -e "\n📂 Category: branch"
          cat <<EOF
🔹 git branch
    → Lists all local branches.

🔹 git checkout <branch>
    → Switches to another branch.

🔹 git merge <branch>
    → Merges another branch into your current one.
EOF
          ;;
        remote)
          echo -e "\n📂 Category: remote"
          cat <<EOF
🔹 git remote -v
    → Shows the remotes connected to your repo.

🔹 git clone <url>
    → Copies a remote repo to your local machine.
EOF
          ;;
        pushpull)
          echo -e "\n📂 Category: pushpull"
          cat <<EOF
🔹 git push
    → Sends your commits to the remote repo.

🔹 git pull
    → Fetches and integrates changes from the remote.

🔹 git fetch
    → Downloads changes but doesn’t merge them.
EOF
          ;;
        stash)
          echo -e "\n📂 Category: stash"
          cat <<EOF
🔹 git stash
    → Temporarily saves your changes.

🔹 git stash pop
    → Restores the most recent stash.
EOF
          ;;
        config)
          echo -e "\n📂 Category: config"
          cat <<EOF
🔹 git config --global user.name "Your Name"
    → Sets your Git username.

🔹 git config --global user.email "you@example.com"
    → Sets your Git email.
EOF
          ;;
        misc)
          echo -e "\n📂 Category: misc"
          cat <<EOF
🔹 git status
    → Shows the current state of your working directory.

🔹 git log
    → Shows a history of commits.

🔹 git diff
    → Shows changes not yet staged.
EOF
          ;;
      esac
    }

    if [[ "$category" == "--all" ]]; then
        show_all_categories
        for cat in add commit branch remote pushpull stash config misc; do
          show_category "$cat"
        done
      elif [[ -z "$category" || "$category" == "help" ]]; then
        show_all_categories
      elif [[ "$category" == "--export" ]]; then
        output="git-guide.html"
        echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Git Guide</title>" > "$output"
        echo "<style>body{font-family:sans-serif;padding:20px;} h2{color:#2c3e50;} pre{background:#f4f4f4;padding:10px;border-left:4px solid #3498db;}</style></head><body>" >> "$output"
        echo "<h1>📚 Git Command Guide</h1>" >> "$output"

        for cat in add commit branch remote pushpull stash config misc; do
          echo "<h2>📂 Category: $cat</h2>" >> "$output"
          case "$cat" in
            add)
              cat <<EOF >> "$output"
<pre>git add &lt;file&gt;
→ Stages a specific file for commit.

git add .
→ Stages all changed files.</pre>
EOF
              ;;
            commit)
              cat <<EOF >> "$output"
<pre>git commit -m "message"
→ Saves your staged changes with a message.

git reset --soft HEAD~1
→ Undoes the last commit but keeps your changes staged.</pre>
EOF
              ;;
            branch)
              cat <<EOF >> "$output"
<pre>git branch
→ Lists all local branches.

git checkout &lt;branch&gt;
→ Switches to another branch.

git merge &lt;branch&gt;
→ Merges another branch into your current one.</pre>
EOF
              ;;
            remote)
              cat <<EOF >> "$output"
<pre>git remote -v
→ Shows the remotes connected to your repo.

git clone &lt;url&gt;
→ Copies a remote repo to your local machine.</pre>
EOF
              ;;
            pushpull)
              cat <<EOF >> "$output"
<pre>git push
→ Sends your commits to the remote repo.

git pull
→ Fetches and integrates changes from the remote.

git fetch
→ Downloads changes but doesn’t merge them.</pre>
EOF
              ;;
            stash)
              cat <<EOF >> "$output"
<pre>git stash
→ Temporarily saves your changes.

git stash pop
→ Restores the most recent stash.</pre>
EOF
              ;;
            config)
              cat <<EOF >> "$output"
<pre>git config --global user.name "Your Name"
→ Sets your Git username.

git config --global user.email "you@example.com"
→ Sets your Git email.</pre>
EOF
              ;;
            misc)
              cat <<EOF >> "$output"
<pre>git status
→ Shows the current state of your working directory.

git log
→ Shows a history of commits.

git diff
→ Shows changes not yet staged.</pre>
EOF
              ;;
          esac
        done

        echo "</body></html>" >> "$output"
        echo "✅ Git guide exported to $output"
        exit 0
      elif [[ "add commit branch remote pushpull stash config misc" =~ $category ]]; then
        show_category "$category"
      else
        echo "❌ Unknown category: $category"
        show_all_categories
      fi
      exit 0
    fi
    ;;

  *)
    echo "❌ Unknown command: $1"
    echo "Run 'git-tools {help|-h|--help}' for usage."
    ;;
esac