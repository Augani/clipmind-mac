#!/usr/bin/swift
//
//  clipmind-cli.swift
//  clipmind CLI
//
//  Command-line interface for ClipMind clipboard manager
//
//  Usage:
//    clipmind list [--limit N] [--json]
//    clipmind search <query> [--json]
//    clipmind paste <id>
//    clipmind delete <id>
//    clipmind copy <id>
//    clipmind clear
//    clipmind workspaces
//    clipmind stats
//

import Foundation
import AppKit

// MARK: - CLI Models

struct CLIOutput: Codable {
    let success: Bool
    let message: String?
    let data: [String: AnyCodable]?
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

// MARK: - Database Path Helper

func getDatabasePath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let clipmindDir = appSupport.appendingPathComponent("ClipMind")
    return clipmindDir.appendingPathComponent("clipboard.db").path
}

// MARK: - CLI Commands

enum Command {
    case list(limit: Int, json: Bool)
    case search(query: String, json: Bool)
    case paste(id: String)
    case copy(id: String)
    case delete(id: String)
    case clear
    case workspaces
    case stats
    case help
    case version
}

// MARK: - CLI Parser

func parseArguments(_ args: [String]) -> Command? {
    guard args.count > 1 else { return .help }

    let command = args[1].lowercased()
    let remainingArgs = Array(args.dropFirst(2))

    switch command {
    case "list", "ls":
        var limit = 20
        var json = false

        for (index, arg) in remainingArgs.enumerated() {
            if arg == "--limit" || arg == "-l", index + 1 < remainingArgs.count {
                limit = Int(remainingArgs[index + 1]) ?? 20
            }
            if arg == "--json" || arg == "-j" {
                json = true
            }
        }

        return .list(limit: limit, json: json)

    case "search", "find":
        guard !remainingArgs.isEmpty else {
            print("Error: search query required")
            return nil
        }

        let json = remainingArgs.contains("--json") || remainingArgs.contains("-j")
        let query = remainingArgs.filter { !$0.hasPrefix("-") }.joined(separator: " ")

        return .search(query: query, json: json)

    case "paste":
        guard !remainingArgs.isEmpty else {
            print("Error: item ID required")
            return nil
        }
        return .paste(id: remainingArgs[0])

    case "copy":
        guard !remainingArgs.isEmpty else {
            print("Error: item ID required")
            return nil
        }
        return .copy(id: remainingArgs[0])

    case "delete", "rm":
        guard !remainingArgs.isEmpty else {
            print("Error: item ID required")
            return nil
        }
        return .delete(id: remainingArgs[0])

    case "clear":
        return .clear

    case "workspaces", "ws":
        return .workspaces

    case "stats", "info":
        return .stats

    case "help", "--help", "-h":
        return .help

    case "version", "--version", "-v":
        return .version

    default:
        print("Error: unknown command '\(command)'")
        return .help
    }
}

// MARK: - Command Execution

func executeCommand(_ command: Command) {
    switch command {
    case .list(let limit, let json):
        listItems(limit: limit, json: json)

    case .search(let query, let json):
        searchItems(query: query, json: json)

    case .paste(let id):
        pasteItem(id: id)

    case .copy(let id):
        copyItem(id: id)

    case .delete(let id):
        deleteItem(id: id)

    case .clear:
        clearAll()

    case .workspaces:
        listWorkspaces()

    case .stats:
        showStats()

    case .help:
        showHelp()

    case .version:
        showVersion()
    }
}

// MARK: - Command Implementations

func listItems(limit: Int, json: Bool) {
    // In a real implementation, this would query the database
    // For now, we'll communicate with the app via XPC or read the database directly

    if json {
        let output = CLIOutput(
            success: true,
            message: "Listed \(limit) items",
            data: ["items": AnyCodable([])]
        )
        printJSON(output)
    } else {
        print("📋 Recent Clipboard Items (limit: \(limit))")
        print("─────────────────────────────────────────")
        print("Note: Direct database access not yet implemented.")
        print("Please use the ClipMind GUI for now.")
    }
}

func searchItems(query: String, json: Bool) {
    if json {
        let output = CLIOutput(
            success: true,
            message: "Search results for '\(query)'",
            data: ["items": AnyCodable([])]
        )
        printJSON(output)
    } else {
        print("🔍 Search Results for: \"\(query)\"")
        print("─────────────────────────────────────────")
        print("Note: Direct database access not yet implemented.")
        print("Please use the ClipMind GUI for now.")
    }
}

func pasteItem(id: String) {
    print("📋 Pasting item: \(id)")
    print("Note: Paste functionality requires ClipMind app to be running.")

    // Would trigger paste via XPC to the running app
    sendCommandToApp(command: "paste", args: ["id": id])
}

func copyItem(id: String) {
    print("📋 Copying item to clipboard: \(id)")
    print("Note: Copy functionality requires ClipMind app to be running.")

    // Would trigger copy via XPC to the running app
    sendCommandToApp(command: "copy", args: ["id": id])
}

func deleteItem(id: String) {
    print("🗑 Deleting item: \(id)")
    print("Note: Delete functionality requires ClipMind app to be running.")

    // Would trigger delete via XPC to the running app
    sendCommandToApp(command: "delete", args: ["id": id])
}

func clearAll() {
    print("⚠️  This will delete all clipboard history. Are you sure? (y/N): ", terminator: "")

    guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
        print("Cancelled.")
        return
    }

    print("🗑 Clearing all clipboard items...")
    print("Note: Clear functionality requires ClipMind app to be running.")

    // Would trigger clear via XPC to the running app
    sendCommandToApp(command: "clear", args: [:])
}

func listWorkspaces() {
    print("📁 Workspaces")
    print("─────────────────────────────────────────")
    print("Note: Direct database access not yet implemented.")
    print("Please use the ClipMind GUI for now.")
}

func showStats() {
    print("📊 ClipMind Statistics")
    print("─────────────────────────────────────────")
    print("Total items:        N/A")
    print("Workspaces:         N/A")
    print("Database size:      N/A")
    print("")
    print("Note: Stats require ClipMind app to be running.")
}

func showHelp() {
    print("""
    ClipMind CLI - Command-line interface for ClipMind

    Usage:
      clipmind <command> [options]

    Commands:
      list, ls                    List recent clipboard items
        --limit, -l N             Limit results to N items (default: 20)
        --json, -j                Output as JSON

      search, find <query>        Search clipboard history
        --json, -j                Output as JSON

      paste <id>                  Paste item by ID
      copy <id>                   Copy item to clipboard by ID
      delete, rm <id>             Delete item by ID
      clear                       Clear all clipboard history
      workspaces, ws              List all workspaces
      stats, info                 Show statistics

      help, --help, -h            Show this help message
      version, --version, -v      Show version information

    Examples:
      clipmind list --limit 10
      clipmind search "TODO"
      clipmind paste abc123
      clipmind list --json

    Notes:
      - Most commands require ClipMind app to be running
      - Use --json flag for machine-readable output
      - IDs are shown in list/search output
    """)
}

func showVersion() {
    print("ClipMind CLI v1.0.0")
    print("Copyright © 2024 ClipMind. All rights reserved.")
}

// MARK: - XPC Communication (Placeholder)

func sendCommandToApp(command: String, args: [String: String]) {
    // This would establish XPC connection to the running ClipMind app
    // For now, just a placeholder
    print("Note: XPC communication not yet implemented.")
    print("Command would be sent: \(command) with args: \(args)")
}

// MARK: - JSON Output

func printJSON(_ output: CLIOutput) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    if let jsonData = try? encoder.encode(output),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    }
}

// MARK: - Main Entry Point

let arguments = CommandLine.arguments

if let command = parseArguments(arguments) {
    executeCommand(command)
    exit(0)
} else {
    exit(1)
}
