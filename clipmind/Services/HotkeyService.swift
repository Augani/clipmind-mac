//
//  HotkeyService.swift
//  clipmind
//
//  Global hotkey registration service using Carbon API
//

import SwiftUI
import Combine
import Carbon.HIToolbox

/// Service for managing global hotkeys
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotkeyHandler: (() -> Void)?

    // Default hotkey: ⌘+Shift+V
    @AppStorage("hotkey_keycode") private var storedKeyCode: Int = kVK_ANSI_V
    @AppStorage("hotkey_modifiers") private var storedModifiers: Int = Int(cmdKey | shiftKey)

    private init() {
        setupEventHandler()
    }

    deinit {
        unregisterHotkey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    /// Setup Carbon event handler for hotkey events
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, userData in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()

            DispatchQueue.main.async {
                service.hotkeyHandler?()
            }

            return OSStatus(noErr)
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(),
                          handlerCallback,
                          1,
                          &eventType,
                          userData,
                          &eventHandler)
    }

    /// Register a global hotkey
    func registerHotkey(keyCode: Int? = nil,
                       modifiers: Int? = nil,
                       handler: @escaping () -> Void) -> Bool {
        // Unregister existing hotkey if any
        unregisterHotkey()

        let key = keyCode ?? storedKeyCode
        let mods = modifiers ?? storedModifiers

        // Save hotkey preferences
        if let keyCode = keyCode {
            storedKeyCode = keyCode
        }
        if let modifiers = modifiers {
            storedModifiers = modifiers
        }

        hotkeyHandler = handler

        // Create hotkey ID with 'clip' signature
        let hotKeyID = EventHotKeyID(signature: OSType(0x636C6970), id: 1)

        // Register the hotkey
        let status = RegisterEventHotKey(UInt32(key),
                                        UInt32(mods),
                                        hotKeyID,
                                        GetEventDispatcherTarget(),
                                        0,
                                        &eventHotKeyRef)

        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return false
        }

        print("Hotkey registered successfully")
        return true
    }

    /// Unregister the current hotkey
    func unregisterHotkey() {
        if let hotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            eventHotKeyRef = nil
            hotkeyHandler = nil
        }
    }

    /// Check if a hotkey combination is already in use
    func isHotkeyAvailable(keyCode: Int, modifiers: Int) -> Bool {
        // Temporarily register to check availability
        let testID = EventHotKeyID(signature: OSType(0x74657374), id: 999) // 'test' signature
        var testRef: EventHotKeyRef?

        let status = RegisterEventHotKey(UInt32(keyCode),
                                        UInt32(modifiers),
                                        testID,
                                        GetEventDispatcherTarget(),
                                        0,
                                        &testRef)

        if status == noErr, let ref = testRef {
            UnregisterEventHotKey(ref)
            return true
        }

        return false
    }

    /// Get human-readable string for hotkey combination
    static func hotkeyDescription(keyCode: Int, modifiers: Int) -> String {
        var keys: [String] = []

        // Add modifiers
        if (modifiers & Int(cmdKey)) != 0 { keys.append("⌘") }
        if (modifiers & Int(shiftKey)) != 0 { keys.append("⇧") }
        if (modifiers & Int(optionKey)) != 0 { keys.append("⌥") }
        if (modifiers & Int(controlKey)) != 0 { keys.append("⌃") }

        // Add key
        let keyString = keyCodeToString(keyCode)
        keys.append(keyString)

        return keys.joined(separator: "")
    }

    /// Convert key code to string representation
    private static func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Escape"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Unknown"
        }
    }
}