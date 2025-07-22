# git-tools
# Version 1.0.0

## Overview

This is a custom Bash script providing a command-line interface (CLI) to streamline common Git operations. It includes features such as committing and pushing changes, user configuration, syncing, interactive squash, and educational Git command help.

See the instruction on how to use it in terminal [here](#-installation--usage-in-bash). 


## 📦 Features

-   *Configure Git username, email, and store credentials*

-   *Commit and push changes with auto-branch/remote detection*

-   *Interactive commit squashing*

-   *Safe stash apply*

-   *Git command help and documentation export*

-   *Auto-generated commit messages and branch creation*

-   *Rebase and retry logic for push conflicts*


## 📖 Commands

### General

    -   git-tools help

    -   git-tools --help

    -   git-tools -h

-    *Displays all available commands.*

### Git Utilities

    git-tools list-commits


-    *Show recent commits in graphs view.*


    git-tools prev-commit


    git-tools undo-last-commit


-    *Soft reset to the previous commit.*


    git-tools current-branch


-    *show the current branch name.*


    git-tools commit-push [:message] [<remote>] [<branch>] [--dry-run] [--confirm] [--verbose]


-    *Stages, commits, and pushes changes in one step with support for dry-run, confirmation, and verbose output. You can also leave the commands after commit-push empty if you are really lazy.*


-   *Example:*

```bash
git-tools commit-push:"Your Message" origin main --dry-run --no-confirm --verbose
```

-   *Or*

```bash
git-tools commit-push
```

-   *You can also use it like this if you are really lazy, just remember that it will automatically create a commit message depending on how many commit you have made and if you there are no remote name exist, it will prompt you to type a name of remote, if you enter without entering anything, it will default to origin, the same as branch name, it will default to main if you just entered.*

```bash
git-tools stash-safe
```
-    *Applies stash only if cleanly applicable; drops stash if successful.*


    git-tools sync

-    *Rebase-pulss from current branch and remote.*


    git-tools squash <N>

-    *Interactively squash last N commits.*


    git-tools configure-user
    
-    *Prompts for Git username, email, and token, with global or local config options.*


## 📘 Git Help System

    git-tools --h git

    git-tools --h git <category>

    git-tools --h git --all

    git-tools --h git --export


### Categories:

-    *add – Staging files*

-    *commit – Saving changes*

-    *branch – Working with branches*

-    *remote – Connecting to remotes*

-    *pushpull – Syncing with remotes*

-    *stash – Temporary changes*

-    *config – Git identity settings*

-    *misc – Miscellaneous helpful commands*

-    *Use --export to generate a clean HTML version of the command guide.*


## 🔐 Credential Handling

-    *Credentials are stored using the store helper.*

-    *Saved in ~/.git-credentials with optional repo URL.*


## 🧠 Notes

-    *The script is written in Bash and uses standard Unix tools.*

-    *It assumes git is installed and configured in the environment.*

-    *Compatible with WSL, macOS, and Linux.*


## 🧰 Installation & Usage in Bash

To make git-tools (and other custom CLI scripts) available globally in your terminal, follow these steps:

### 📁 Step 1: Create a directory for your CLI tools

-   *If you haven’t already:*

```bash
mkdir -p ~/scripts/bin
```

-   *You can place git-tools and other custom scripts inside this bin directory.*

### 📄 Step 2: Move the script

-   *Copy or move your git-tools Bash script to the folder:*

```bash
cp git-tools ~/scripts/bin/
```

-   *Make sure it's executable:*

```bash
chmod +x ~/scripts/bin/git-tools
```

### 🛠️ Step 3: Add the folder to your PATH

-   *Open your ~/.bashrc (or ~/.bash_profile on macOS) with your preferred editor:*

```bash
nano ~/.bashrc
```

-   *Then add the following line at the bottom:*

```bash
export PATH="$HOME/scripts/bin:$PATH"
```

-   *press CTRL + O and CTRL + X to save and exit the nano.*

-   *Finally, Reload the bash terminal:*

```bash
source ~/.bashrc (or ~/.bash_profile if you are on a macOS.)
```

### ✅ Step 4: Run it from anywhere

-   *Now you can run git-tools from any terminal session like a normal command:*

```bash
git-tools --version
```

-   *It should output this: Git Tools CLI version $VERSION*
-   *Made by jhonkeithman123*

## 🛠️ Author

-   *Keith Justine Virgenes*


## 💡 Contribution

-   *If you'd like to improve or contribute, feel free to fork and PR.*