#!/bin/bash

# Git Tools CLI by Keith

case "$1" in
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

  commit-push)
    #* Flag parsing
    dry_run=false
    confirm=false
    verbose=false
    remote_name=""
    override_branch=""

    args=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dry-run) dry_run=true ;;
        --confirm) confirm=true ;;
        --verbose) verbose=true ;;
        --remote-name)
          shift
          remote_name="$1"
          ;;
        --branch)
          shift
          override_branch="$1"
          ;;
        *)
          args+=("$1")
          ;;
      esac
      shift
    done

    #* Ordinal suffix generator
    ordinal_suffix() {
      n=$1
      if [[ $n -eq 0 ]]; then echo "initial"; return; fi
      last_digit=$((n % 10))
      last_two=$((n % 100))
      if [[ $last_two -ge 11 && $last_two -le 13 ]]; then suffix="th"
      else
        case $last_digit in
          1) suffix="st" ;;
          2) suffix="nd" ;;
          3) suffix="rd" ;;
          *) suffix="th" ;;
        esac
      fi
      echo "${n}${suffix}"
    }

    #* Flexible argument parsing
    repo_link=""
    new_branch=""
    msg=""

    for arg in "${args[@]}"; do
      if [[ "$arg" =~ ^(https://|git@) ]]; then
        repo_link="$arg"
      elif git check-ref-format --branch "$arg" &>/dev/null; then
        new_branch="$arg"
      else
        msg="$arg"
      fi
    done

    #* Auto-generate commit message if empty
    if [ -z "$msg" ]; then
      commit_count=$(git rev-list --count HEAD 2>/dev/null || echo 0)
      ordinal=$(ordinal_suffix "$commit_count")
      if [ "$commit_count" -eq 0 ]; then
        msg="no commits made: initial commit"
      else
        msg="$commit_count commits made: ${ordinal} commit"
      fi
    fi

    #* Initialize Git repo if needed
    if [ ! -d .git ]; then
      echo "🧱 Initializing Git repository..."
      git init
    fi

    #* Auto-detect or create remote
    remotes=($(git remote))
    if [ ${#remotes[@]} -eq 0 ]; then
      if [[ -n "$repo_link" ]]; then
        if [ -z "$remote_name" ]; then
          read -p "📛 Enter remote name [default: origin]: " remote_name
          remote_name="${remote_name:-origin}"
        else
          echo "📛 Using remote name from flag: $remote_name"
        fi
        git remote add "$remote_name" "$repo_link"
        remote="$remote_name"
      else
        echo "❌ No remote found and no repo link provided."
        exit 1
      fi
    else
      remote="${remotes[0]}"
      echo "📦 Using existing remote: $remote"
    fi

    #* Auto-detect or override branch
    if [ -n "$override_branch" ]; then
      new_branch="$override_branch"
      echo "🌿 Using branch from flag: $new_branch"
    elif [ -z "$new_branch" ]; then
      new_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -z "$new_branch" ] || [ "$new_branch" = "HEAD" ]; then
        new_branch="main"
      fi
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$new_branch" ]; then
      echo "🌿 Creating and switching to branch: $new_branch"
      git checkout -b "$new_branch"
    fi
    branch="$new_branch"

    echo "📝 Commit message: \"$msg\""
    echo "📦 Remote: $remote"
    echo "🌿 Branch: $branch"

    if $dry_run; then
      echo "🔍 Dry run mode: no changes will be made."
      exit 0
    fi

    git add .

    if $verbose; then
      echo "🔍 Showing staged changes:"
      git diff --staged
      echo
    fi

    git commit -m "$msg"

    if $confirm; then
      while true; do
        echo
        echo "❓ Confirm push to remote: '$remote' on branch: '$branch'"
        echo "   [y] Yes, push"
        echo "   [r] Show remotes"
        echo "   [b] Show branches"
        echo "   [n] No, cancel"
        read -p "👉 Your choice [y/r/b/n]: " choice

        case "$choice" in
          [Yy]) break ;;
          [Rr])
            echo "📡 Available remotes:"
            git remote -v
            ;;
          [Bb])
            echo "🌿 Available branches:"
            git branch -a
            ;;
          [Nn])
            echo "❌ Push cancelled."
            exit 0
            ;;
          *)
            echo "⚠️ Invalid choice. Please enter y, r, b, or n."
            ;;
        esac
      done
    fi

    echo "🚀 Pushing to $remote/$branch..."
    if git push "$remote" "$branch"; then
      echo "✅ Push successful."
    else
      echo "⚠️ Push failed. Attempting to rebase and retry..."
      git pull --rebase "$remote" "$branch"
      if git push "$remote" "$branch"; then
        echo "✅ Push successful after rebase."
      else
        echo "❌ Push still failed. Please resolve conflicts manually."
      fi
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
    echo "  git-tools commit-push \"msg\" <remote> <branch>  # Commit and push, auto-rebase if needed"
    echo "  git-tools {--h|-help} git <--all | help | (category 'add, commit, etc.') | --export | (leave blank)>"
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
