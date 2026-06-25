//
//  CardCarousel.swift
//  clipmind
//
//  Horizontal card-shuffle carousel of recent clipboard items
//

import SwiftUI
import AppKit

struct DeckTransform {
    let offsetX: CGFloat
    let offsetY: CGFloat
    let scale: CGFloat
    let rotation: Double
    let opacity: Double
    let zIndex: Double
}

func deckTransform(offset: Int) -> DeckTransform {
    if offset < 0 {
        return DeckTransform(offsetX: -190, offsetY: 0, scale: 0.96, rotation: 0, opacity: 0, zIndex: Double(30 + offset))
    }
    if offset == 0 {
        return DeckTransform(offsetX: 0, offsetY: 0, scale: 1, rotation: 0, opacity: 1, zIndex: 20)
    }
    if offset > 2 {
        return DeckTransform(offsetX: 0, offsetY: 18, scale: 0.82, rotation: 0, opacity: 0, zIndex: 0)
    }
    let depth = CGFloat(offset)
    return DeckTransform(
        offsetX: 0,
        offsetY: depth * 9,
        scale: 1 - depth * 0.05,
        rotation: 0,
        opacity: 1,
        zIndex: Double(20 - offset)
    )
}

struct CardCarousel: View {
    let items: [ClipboardItem]
    @Binding var currentIndex: Int
    let onActivate: (ClipboardItem) -> Void
    var onDelete: ((ClipboardItem) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var monitors: [Any] = []
    @State private var lastScroll = Date.distantPast

    private let cardWidth: CGFloat = 248
    private let cardHeight: CGFloat = 166
    private let deckHeight: CGFloat = 196

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    card(index: index, item: item)
                }

                HStack {
                    chevron(forward: false)
                    Spacer()
                    chevron(forward: true)
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
            }
            .frame(height: deckHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())

            CarouselIndicator(count: items.count, index: clampedIndex)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .onAppear(perform: installMonitors)
        .onDisappear(perform: removeMonitors)
    }

    private var clampedIndex: Int {
        guard !items.isEmpty else { return 0 }
        return min(max(currentIndex, 0), items.count - 1)
    }

    private func card(index: Int, item: ClipboardItem) -> some View {
        let offset = index - clampedIndex
        let transform = deckTransform(offset: offset)
        let isFront = offset == 0
        let opacity = reduceMotion ? (isFront ? 1.0 : 0.0) : transform.opacity
        let scale = reduceMotion ? 1.0 : transform.scale
        let rotation = reduceMotion ? 0.0 : transform.rotation
        let xOffset = reduceMotion ? 0 : transform.offsetX + (isFront ? dragOffset : 0)
        let yOffset = reduceMotion ? 0 : transform.offsetY

        return CarouselCard(item: item)
            .frame(width: cardWidth, height: cardHeight)
            .opacity(opacity)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .zIndex(transform.zIndex)
            .allowsHitTesting(isFront)
            .onTapGesture { if isFront { onActivate(item) } }
            .gesture(isFront ? dragGesture : nil)
            .contextMenu {
                Button { onActivate(item) } label: { Label("Copy to Clipboard", systemImage: "doc.on.doc") }
                if let onDelete {
                    Divider()
                    Button(role: .destructive) { onDelete(item) } label: { Label("Delete", systemImage: "trash") }
                }
            }
    }

    private func chevron(forward: Bool) -> some View {
        let enabled = forward ? clampedIndex < items.count - 1 : clampedIndex > 0
        return Button {
            advance(forward ? 1 : -1)
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(DesignTokens.Colors.surfaceSecondary.opacity(0.5)))
                .overlay(Circle().strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.25)
        .disabled(!enabled)
        .accessibilityLabel(forward ? "Next item" : "Previous item")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in dragOffset = value.translation.width * 0.6 }
            .onEnded { value in
                let width = value.translation.width
                withAnimation(snap) {
                    if width < -46 { moveClamped(1) }
                    else if width > 46 { moveClamped(-1) }
                    dragOffset = 0
                }
            }
    }

    private var snap: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : DesignTokens.Animation.spring
    }

    private func advance(_ delta: Int) {
        withAnimation(snap) { moveClamped(delta) }
    }

    private func moveClamped(_ delta: Int) {
        guard !items.isEmpty else { return }
        currentIndex = min(max(clampedIndex + delta, 0), items.count - 1)
    }

    private func installMonitors() {
        guard monitors.isEmpty else { return }
        let scroll = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event)
            return event
        }
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 123 { advance(-1); return nil }
            if event.keyCode == 124 { advance(1); return nil }
            return event
        }
        monitors = [scroll, keys].compactMap { $0 }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    private func handleScroll(_ event: NSEvent) {
        let now = Date()
        guard now.timeIntervalSince(lastScroll) > 0.3 else { return }
        let delta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        guard abs(delta) > 1.5 else { return }
        lastScroll = now
        advance(delta < 0 ? 1 : -1)
    }
}

struct CarouselCard: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppIconView(
                    bundleIdentifier: item.sourceBundleIdentifier,
                    appName: item.sourceApp,
                    size: 26,
                    origin: item.origin
                )

                Text(item.sourceApp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                ContentTypeBadge(type: item.type, size: .small)
            }

            Text(item.truncatedPreview(maxLength: 140))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: DesignTokens.Spacing.xs) {
                if item.origin == .universalClipboard {
                    HStack(spacing: 3) {
                        Image(systemName: "iphone").font(.system(size: 9, weight: .medium))
                        Text("iPhone").font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DesignTokens.Colors.accentPrimary.opacity(0.16)))
                    .foregroundStyle(DesignTokens.Colors.accentSecondary)
                }

                Spacer(minLength: 0)

                TimestampLabel(item.timestamp)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                .fill(DesignTokens.Colors.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

struct CarouselIndicator: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<max(count, 1), id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary.opacity(0.4))
                        .frame(width: dot == index ? 16 : 6, height: 6)
                }
            }

            Text("\(index + 1) / \(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .monospacedDigit()
        }
    }
}
