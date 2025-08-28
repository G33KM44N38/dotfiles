# tmux-navigate.sh

## Overview and Purpose

`tmux-navigate.sh` is a bash script that provides an interactive way to navigate to project directories and automatically create or switch to corresponding tmux sessions. It uses fuzzy finding (fzf) to present a searchable list of directories from predefined search paths, allowing for quick project switching and tmux session management.

## Key Features and Improvements

### Core Features
- **Interactive Directory Selection**: Uses fzf for fuzzy searching through directories
- **Tmux Session Integration**: Automatically creates new tmux sessions or switches to existing ones
- **Session Name Indication**: Prefixes existing tmux sessions with `[TMUX]` in the selection list
- **Cross-Session Compatibility**: Works both inside and outside existing tmux sessions

### Recent Improvements
- **Duplicate Removal**: Uses `find | sort -u` for efficient deduplication of directory paths
- **Enhanced Conflict Resolution**: When multiple directories share the same basename, displays full paths for disambiguation instead of showing only one canonical path
- **Simplified Path Handling**: Streamlined logic for building the selection list, improving performance and readability

## Usage Instructions

### Basic Usage
```bash
./tmux-navigate.sh
```
This launches the interactive selector showing all available directories.

### Direct Directory Selection
```bash
./tmux-navigate.sh /path/to/directory
```
Creates or switches to a tmux session for the specified directory without interactive selection.

### Integration with Shell
Add to your shell configuration for quick access:
```bash
alias tn='./tmux-navigate.sh'
```

## Dependencies

- **bash**: Shell environment
- **tmux**: Terminal multiplexer for session management
- **fzf**: Fuzzy finder for interactive selection
- **find**: Unix utility for directory traversal
- **awk**: Text processing utility

## Configuration

### Search Paths
The script searches for directories in the following predefined paths (configurable in the `raw_paths` array):

```bash
raw_paths=(
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/"
    "~/backup/"
    "~/coding/"
    "~/coding/work/"
    "~/coding/perso/"
    "~/goinfre/"
    "~/.dotfiles/"
    "~/.dotfiles/.config/"
)
```

To modify search paths, edit the `raw_paths` array in the script. Only existing directories are included in the search.

## Examples

### Typical Workflow
1. Run `./tmux-navigate.sh`
2. Type to fuzzy search for a project (e.g., "myproject")
3. Press Enter to select
4. Script automatically creates/switches to tmux session named after the directory

### Handling Conflicts
If you have directories like:
- `/home/user/projects/work/myproject`
- `/home/user/projects/personal/myproject`

The script will display:
```
myproject	/home/user/projects/work/myproject
myproject	/home/user/projects/personal/myproject
```

### Existing Session Indication
If a tmux session already exists for a directory, it appears as:
```
[TMUX] myproject	/home/user/projects/myproject
```

## Troubleshooting

### No Directories Found
**Error**: "No valid search directories found."
**Solution**: Check that at least one directory in `raw_paths` exists and is accessible.

### No Selection Made
**Error**: "No directory selected"
**Solution**: This is normal when canceling fzf selection (Ctrl+C or Esc).

### Tmux Not Running
**Issue**: Script fails when tmux is not available
**Solution**: Ensure tmux is installed and accessible in PATH.

### Permission Issues
**Issue**: Some directories not appearing in selection
**Solution**: Check read permissions on search path directories.

### Session Name Conflicts
**Issue**: Directory basename conflicts with existing tmux session names
**Solution**: The script handles this by showing full paths for disambiguation.

## Changelog

### Recent Modifications (Latest Version)
- **Simplified Duplicate Removal**: Replaced manual canonicalization with `find | sort -u` for better performance
- **Enhanced Conflict Resolution**: Improved handling of duplicate basenames by displaying all conflicting paths separately
- **Code Refactoring**: Streamlined the logic for building fzf input, making it more maintainable
- **Path Handling**: Optimized path processing to reduce unnecessary operations

### Previous Features
- Initial implementation with basic directory scanning
- Tmux session creation and switching
- Fuzzy search integration with fzf
- Existing session detection and indication

## Technical Details

- **Session Naming**: Uses directory basename with dots converted to underscores
- **Path Cleanup**: Automatically removes trailing slashes from selected paths
- **Error Handling**: Graceful handling of missing directories and tmux unavailability
- **Performance**: Efficient directory scanning with built-in deduplication