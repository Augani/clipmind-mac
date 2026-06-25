//
//  NotchHUDController.swift
//  clipmind
//
//  Manages the borderless notch HUD panel and its lifecycle
//

import AppKit
import SwiftUI
import Combine

final class NotchHUDController {
    static let shared = NotchHUDController()

    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?
    private var cancellable: AnyCancellable?

    private var isEnabled: () -> Bool = { true }

    private let displayDuration: TimeInterval = 1.4
    private let panelWidth: CGFloat = 64
    private let panelHeight: CGFloat = 40

    private init() {}

    func start(observing store: ClipboardStore, isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        cancellable = store.$lastCaptured
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] item in
                guard self?.isEnabled() == true else { return }
                self?.present(item: item)
            }
    }

    func present(item: ClipboardItem) {
        guard !item.isMarkedSensitive else { return }

        let hosting = NSHostingView(rootView: NotchHUDView())
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let targetPanel = panel ?? makePanel()
        panel = targetPanel
        targetPanel.contentView = hosting
        position(targetPanel)
        targetPanel.alphaValue = 1
        targetPanel.orderFrontRegardless()
        armDismiss()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - panelHeight
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func armDismiss() {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: work)
    }

    private func dismiss() {
        dismissWork?.cancel()
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }
}
