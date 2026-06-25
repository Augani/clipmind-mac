# ClipMind CLI & Automation

Command-line interface and AppleScript support for ClipMind.

## CLI Installation

1. Make the CLI executable:
```bash
chmod +x CLI/clipmind-cli.swift
```

2. Create a symlink (optional):
```bash
sudo ln -s /path/to/clipmind/CLI/clipmind-cli.swift /usr/local/bin/clipmind
```

## CLI Usage

### List Recent Items
```bash
# List last 20 items
clipmind list

# List last 50 items
clipmind list --limit 50

# Output as JSON
clipmind list --json
```

### Search
```bash
# Search for text
clipmind search "TODO"

# Search with JSON output
clipmind search "API key" --json
```

### Copy & Paste
```bash
# Copy item by ID
clipmind copy abc-123-def

# Paste item by ID
clipmind paste abc-123-def
```

### Delete
```bash
# Delete single item
clipmind delete abc-123-def

# Clear all items
clipmind clear
```

### Workspaces
```bash
# List all workspaces
clipmind workspaces

# Show statistics
clipmind stats
```

## AppleScript Support

ClipMind is fully scriptable via AppleScript. Here are some examples:

### Get All Clipboard Items
```applescript
tell application "ClipMind"
    get every clipboard item
end tell
```

### Search Clipboard
```applescript
tell application "ClipMind"
    search "TODO"
end tell
```

### Get Item Properties
```applescript
tell application "ClipMind"
    set allItems to every clipboard item
    repeat with anItem in allItems
        set itemContent to content of anItem
        set itemApp to source app of anItem
        set itemTime to timestamp of anItem
        -- Do something with the data
    end repeat
end tell
```

### Copy Item to Clipboard
```applescript
tell application "ClipMind"
    set items to search "important note"
    if (count of items) > 0 then
        copy item (id of item 1 of items)
    end if
end tell
```

### Delete Items
```applescript
tell application "ClipMind"
    -- Delete a specific item
    delete item "abc-123-def"

    -- Or clear all items
    clear all
end tell
```

### Get Items from Workspace
```applescript
tell application "ClipMind"
    items in workspace "Development"
end tell
```

### Filter and Process Items
```applescript
tell application "ClipMind"
    set allItems to every clipboard item
    set codeItems to {}

    repeat with anItem in allItems
        if type of anItem is "code" then
            set end of codeItems to anItem
        end if
    end repeat

    return codeItems
end tell
```

### Get Statistics
```applescript
tell application "ClipMind"
    set totalItems to item count
    set allWorkspaces to every workspace

    return {itemCount:totalItems, workspaceCount:(count of allWorkspaces)}
end tell
```

## Automation Examples

### Save Daily Summary
```applescript
-- Save clipboard summary to file daily
tell application "ClipMind"
    set today to current date
    set todayItems to every clipboard item whose timestamp > (today - 1 * days)

    set summaryText to ""
    repeat with anItem in todayItems
        set summaryText to summaryText & (content of anItem) & return
    end repeat

    -- Save to file
    set theFile to (path to desktop as text) & "clipboard-summary.txt"
    write summaryText to file theFile
end tell
```

### Auto-Tag by Content
```applescript
-- Automatically categorize items
tell application "ClipMind"
    set allItems to every clipboard item

    repeat with anItem in allItems
        set itemContent to content of anItem

        -- Check for code patterns
        if itemContent contains "function" or itemContent contains "class" then
            -- Would assign to Code workspace
        else if itemContent contains "http" then
            -- Would assign to Links workspace
        end if
    end repeat
end tell
```

### Shell Integration
```bash
#!/bin/bash
# Search clipboard and copy to current clipboard

query="$1"
results=$(clipmind search "$query" --json)

# Parse JSON and get first result ID
# (requires jq or similar JSON parser)
id=$(echo "$results" | jq -r '.data.items[0].id')

if [ ! -z "$id" ]; then
    clipmind copy "$id"
    echo "Copied item: $id"
else
    echo "No results found for: $query"
fi
```

## Integration with Other Tools

### Alfred Workflow
Create an Alfred workflow that calls:
```bash
clipmind search "{query}" --json
```

### Keyboard Maestro
Use the CLI commands in Keyboard Maestro macros:
```bash
clipmind list --limit 1
```

### Hammerspoon
```lua
hs.task.new("/usr/local/bin/clipmind", function(exitCode, stdOut, stdErr)
    if exitCode == 0 then
        -- Process results
    end
end, {"search", "important"}):start()
```

## Notes

- The CLI requires ClipMind app to be running for most operations
- Use `--json` flag for machine-readable output
- AppleScript support requires macOS 10.14 or later
- All timestamps are in local time
- IDs are UUID strings

## Future Enhancements

- Direct database access mode (doesn't require app running)
- Webhook support for automation
- REST API server mode
- Watch mode for monitoring clipboard changes
- Pipe support for Unix-style workflows
