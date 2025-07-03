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
    if [ $# -lt 4 ]; then
      echo "Usage: git-tools commit-push \"commit message\" <remote> <branch>"
      exit 1
    fi
    msg="$2"
    remote="$3"
    branch="$4"
    git add .
    git commit -m "$msg"
    git push "$remote" "$branch"
    ;;

  stash-safe)
    echo "🔒 Trying to apply stash safety..."
    if got stash apply --index; then 
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
    ;;

  *)
    echo "❌ Unknown command: $1"
    echo "Run 'git-tools {help|-h|--help}' for usage."
    ;;
esac
