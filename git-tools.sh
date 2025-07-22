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
    echo "Made by jhonkeithman123"
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

  clone)
    read -p "🔗 Enter the Git repository URL to clone: " repo_url
    if [[ -z "$repo_url" ]]; then
      echo "❌ No URL provided. Aborting."
      exit 1
    fi

    read -p "📁 Folder to clone into (leave blank for default): " folder_name
    read -p "🌍 Rename remote from 'origin' to (leave blank to keep 'origin'): " new_remote
    read -p "🌿 Rename default branch after cloning? (leave blank to keep current): " new_branch

    # build clone command
    if [[ -n "$folder_name" ]]; then
       git clone "$repo_url" "$folder_name"
      if ! cd "$folder_name"; then
        echo "❌ Failed to enter folder '$folder_name'. Retrying with mkdir..."
        mkdir -p "$folder_name"
        cd "$folder_name" || { echo "❌ Still failed to cd into '$folder_name'. Exiting."; exit 1; }
      fi
    else
      git clone "$repo_url"
      repo_basename=$(basename -s .git "$repo_url")
      if ! cd "$repo_basename"; then
        echo "❌ Failed to enter folder '$repo_basename'. Retrying with mkdir..."
        mkdir -p "$repo_basename"
        cd "$repo_basename" || { echo "❌ Still failed to cd into '$repo_basename'. Exiting."; exit 1; }
      fi
    fi

    if [[ -n "$new_remote" && "$new_remote" != "origin" ]]; then
      git remote rename origin "$new_remote"
      echo "✅ Remote renamed to '$new_remote'"
    else
      echo "ℹ️ Keeping default remote name: origin"
    fi

    if [[ -n "$new_branch" ]]; then
      current_branch=$(git rev-parse --abbrev-ref HEAD)
      git branch -m "$current_branch" "$new_branch"
      echo "✅ Branch renamed to '$new_branch'"
    else
      echo "ℹ️ Keeping current branch name."
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

  create-repo)
    if ! command -v gh &>/dev/null; then
      echo "❌ GitHub CLI (gh) not found. Attempting to install..."

      if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &>/dev/null; then
          echo "🔧 Installing GitHub CLI via apt..."
          type -p curl >/dev/null || sudo apt update && sudo apt install curl -y
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
          sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          sudo apt update
          sudo apt install gh -y

        elif command -v dnf &>/dev/null; then
          echo "🔧 Installing Github CLI via dnf..."
          sudo dnf install 'dnf-command(config-manager)' -y
          sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
          sudo dnf install gh -y

        elif command -v pacman &>/dev/null; then
          echo "🔧 Installing GitHub CLI via pacman..."
          sudo pacman -Syu && sudo pacman -Sy gh --noconfirm

        else
          echo "⚠️ Unsupported Linux package manager. Please install Github CLI manually from https://cli.github.com"
          exit 1
        fi
      
      elif [[ "$OSTYPE"  == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
          echo "🔧 Installing GitHub CLI via HomeBrew..."
          brew install gh
        else
          echo "⚠️ Homebrew not founf. Please install Homebrew first: https://brew.sh/"
          exit 1
        fi
      
      elif grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
        echo "🧰 Detected WSL. Installing GitHub CLI via apt..."
        curl -fsSl https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/urs/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y

      else
        echo "⚠️ Unsupported OS. Please install GitHUb CLI manually from https://cli.github.com"
        exit 1
      fi

      # Check again after installation
      if ! command -v gh &>/dev/null; then
        echo "❌ Failed to install GitHub CLI. Please install manually."
        exit 1
      else
        echo "✅ GitHub CLI successfully installed!"
        echo "Resuming repository creation"
        read -p "press ENTER to continue:"
      fi
    fi

    echo "📦 Let's create a GitHub repository interactively!"

    # Ask for repo name
    read -p "📛 Repository name (required): " repo_name
    [[ -z "$repo_name" ]] && echp "❌ Repo name is required." && exit 1

    # Ask for visibility
    echo "🔐 Visibility options:"
    echo "1) Public"
    echo "2) Private"
    echo "3) Internal (only for enterprise orgs)"
    read -p "Select visibility [1/2/3]: " vis_choice
    case "$vis_choice" in
      2) visibility="--private" ;;
      3) visibility="--visibility=internal" ;;
      *) visibility="--public" ;;
    esac

    # Description (optional)
    read -p "📝 Repository description (optional): " description
    [[ -n "$description" ]] && description_flag="--description=\"$description\""

    # Gitignore template
    read -p "📄 Gitignore template (e.g., Node, Python) or leave blank: " gitignore
    [[ -n "$gitignore" ]] && gitignore_flag="--gitignore=$gitignore"

    # License template
    read -p "📜 License template (e.g., mit, apache-2.0) or leave blank: " license
    [[ -n "$license" ]] && license_flag="--license=$license"

    # Create with remote?
    read -p "🔗 Add remote? (y/n) [default: y]: " add_remote
      
    if [[ "$add_remote" =~ ^[Nn]$ ]]; then
      remote_flag="--remote=none"
    else
      # Prompt for remote name only if user said yes or pressed Enter
      read -p "🌍 Remote name [default: origin]: " remote_name
      remote_name=${remote_name:-origin} # Use "origin" if blank
      remote_flag="--remote=$remote_name"
    fi

    # Use current directory or new folder?
    read -p "📁 Use current folder as repo source? (y/n) [default: y]: " use_current
    [[ "$use_current" =~ ^[Nn]$ ]] && source_flag="" || source_flag="--source=."

    # Confirm before running
    echo
    echo "⚙️ Ready to create repo with the following options:"
    echo "- Name: $repo_name"
    echo "- Visibility: $visibility"
    [[ -n "$description" ]] && echo "-  Description: $description"
    [[ -n "$gitignore" ]] && echo "-  Gitignore: $gitignore"
    [[ -n "$license" ]] && echo "-  License: $license"
    echo "- Remote: $remote_flag"
    echo "- Source: $([[ "$use_current" =~ ^[Nn]$ ]] && echo 'New folder' || echo 'Current directory')"
    echo
    read -p "✅ Proceed with creation? (y/n): " confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && echo "❌ Cancelled." && exit 0

    # Build command
    echo "🚀 Creating repository on GitHub..."
    eval gh repo create \"$repo_name\" $visibility $description_flag $gitignore_flag $license_flag $remote_flag $source_flag

    # Optional push after
    read -p "🚚 Push code to GitHub now? (y/n): " push_now
    if [[ "$push_now" =~ ^[Yy]$ ]]; then
      current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

      if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
        echo "❌ No current branch found. You might not be inside a Git repo or haven't made a commmit yet."
        exit 1
      fi

      current_remote=$(git remote | head -n 1)
      if [[ -z "$current_remote" ]]; then
        echo "❌ No remote configured. Skipping push."
      else
        git push -u "$current_remote" "$current_branch"
      fi
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
    echo "  git-tools clone                                       # Cloning a repository with interactive process."
    echo "  git-tools commit-push[:msg] [--dry-run] [--confirm] [--verbose] [<remote>] [<branch>]  # Commit and push, auto-rebase on conflicts"
    echo "  git-tools configure-user                              # Configure Git user identity and credentials"
    echo "  git-tools create-repo                                 # Create a repository in Github using GitHub CLI"
    echo "  git-tools current-branch                              # Show current Git branch"
    echo "  git-tools {--h|-help} git <--all | help | (category 'add, commit, etc.') | --export | (leave blank)>"
    echo "  git-tools list-commits                                # Show recent commits in one-line format"
    echo "  git-tools prev-commit                                 # Soft reset to previous commit"
    echo "  git-tools squash <N>                                  # Interactively squash last N commits"
    echo "  git-tools stash-safe                                  # Apply stash only if clean, then drop"
    echo "  git-tools sync                                        # Pull and rebase from origin/<current-branch>"
    echo "  git-tools undo-last-commit                            # Undo last commit but keep changes staged"
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