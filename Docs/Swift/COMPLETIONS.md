# Shell Completion for EbookMechanic CLI

The EbookMechanic CLI supports shell completion for Bash, Zsh, Fish, and PowerShell.

## Quick Start

Generate all completion scripts at once:

```bash
make cli-completions
```

This creates completion scripts in the `./completions/` directory.

## Installation

### Bash

**macOS (Homebrew):**
```bash
cp completions/ebook-mechanic.bash $(brew --prefix)/etc/bash_completion.d/
```

**macOS (manual):**
```bash
sudo cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/
```

**Linux:**
```bash
sudo cp completions/ebook-mechanic.bash /etc/bash_completion.d/
```

After installation, restart your shell or source your `.bashrc`:
```bash
source ~/.bashrc
```

### Zsh

**macOS:**
```bash
sudo cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/
```

**Linux:**
```bash
sudo cp completions/_ebook-mechanic /usr/share/zsh/site-functions/
```

After installation, reload completions:
```bash
rm -f ~/.zcompdump
compinit
```

Or simply restart your shell.

### Fish

```bash
mkdir -p ~/.config/fish/completions
cp completions/ebook-mechanic.fish ~/.config/fish/completions/
```

Fish automatically loads completions from this directory. No restart needed.

### PowerShell

Add the completion script to your PowerShell profile:

```powershell
# Find your profile location
echo $PROFILE

# Add this line to your profile
. /path/to/completions/ebook-mechanic.ps1
```

Or source it in your current session:
```powershell
. ./completions/ebook-mechanic.ps1
```

## Manual Generation

You can also generate completion scripts individually:

```bash
# Bash
ebook-mechanic --generate-completion bash > ebook-mechanic.bash

# Zsh
ebook-mechanic --generate-completion zsh > _ebook-mechanic

# Fish
ebook-mechanic --generate-completion fish > ebook-mechanic.fish

# PowerShell
ebook-mechanic --generate-completion powershell > ebook-mechanic.ps1
```

## What Gets Completed

The completion scripts provide intelligent suggestions for:

- **All CLI options:** `-h`, `--help`, `--version`, `-d`, `--dir`, etc.
- **Directory paths:** When using `-d`/`--dir` or `-c`/`--corrupted-dir`
- **Shell types:** When using `--generate-completion` (bash, zsh, fish, powershell)
- **Context-aware completion:** Different completions based on the previous argument

## Testing Completion

After installation, test that completion works:

### Bash/Zsh
```bash
ebook-mechanic --[TAB]
```

### Fish
```fish
ebook-mechanic --[TAB]
```

### PowerShell
```powershell
ebook-mechanic --[TAB]
```

You should see a list of available options.

## Troubleshooting

### Bash: Completions Not Working

1. Ensure bash-completion is installed:
   ```bash
   # macOS
   brew install bash-completion
   
   # Ubuntu/Debian
   sudo apt-get install bash-completion
   ```

2. Make sure bash-completion is loaded in your `.bashrc`:
   ```bash
   [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion
   ```

### Zsh: Completions Not Working

1. Ensure completion system is enabled in your `.zshrc`:
   ```zsh
   autoload -Uz compinit
   compinit
   ```

2. Clear the completion cache:
   ```bash
   rm -f ~/.zcompdump*
   compinit
   ```

3. Verify the file is in the correct location and has proper permissions:
   ```bash
   ls -l /usr/local/share/zsh/site-functions/_ebook-mechanic
   ```

### Fish: Completions Not Working

1. Verify the file is in the correct location:
   ```fish
   ls -l ~/.config/fish/completions/ebook-mechanic.fish
   ```

2. Reload completions:
   ```fish
   fish_update_completions
   ```

### PowerShell: Completions Not Working

1. Check your execution policy:
   ```powershell
   Get-ExecutionPolicy
   ```

2. If needed, set it to allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Verify the script is sourced in your profile:
   ```powershell
   cat $PROFILE
   ```

## Uninstalling

To remove completions:

**Bash:**
```bash
sudo rm /usr/local/etc/bash_completion.d/ebook-mechanic.bash
```

**Zsh:**
```bash
sudo rm /usr/local/share/zsh/site-functions/_ebook-mechanic
```

**Fish:**
```bash
rm ~/.config/fish/completions/ebook-mechanic.fish
```

**PowerShell:**
Remove the `. /path/to/completions/ebook-mechanic.ps1` line from your `$PROFILE`.
