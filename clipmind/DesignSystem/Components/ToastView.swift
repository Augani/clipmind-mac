//
//  ToastView.swift
//  clipmind
//
//  Toast notification system for user feedback
//

import SwiftUI
import Combine

/// Toast notification types
enum ToastType {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

/// Toast notification model
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: TimeInterval

    init(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

/// Toast notification view
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.type.color)

            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .fill(DesignTokens.Colors.glassPrimary)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            toast.type.color.opacity(0.3),
                            toast.type.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: toast.type.color.opacity(0.2), radius: 12, x: 0, y: 8)
        .frame(maxWidth: 400)
        .offset(x: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto-dismiss after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

/// Toast manager for showing notifications
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: Toast?

    private init() {}

    func show(_ toast: Toast) {
        currentToast = toast
    }

    func show(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        show(Toast(type: type, message: message, duration: duration))
    }

    func dismiss() {
        currentToast = nil
    }

    // Convenience methods
    func success(_ message: String, duration: TimeInterval = 3.0) {
        show(type: .success, message: message, duration: duration)
    }

    func error(_ message: String, duration: TimeInterval = 4.0) {
        show(type: .error, message: message, duration: duration)
    }

    func warning(_ message: String, duration: TimeInterval = 3.5) {
        show(type: .warning, message: message, duration: duration)
    }

    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(type: .info, message: message, duration: duration)
    }
}

/// Toast container modifier
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content

            if let toast = toastManager.currentToast {
                ToastView(toast: toast) {
                    toastManager.dismiss()
                }
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.trailing, DesignTokens.Spacing.xl)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

extension View {
    /// Add toast notification support to any view
    func toast(manager: ToastManager = .shared) -> some View {
        modifier(ToastModifier(toastManager: manager))
    }
}

// MARK: - Preview

#Preview("Toast Success") {
    VStack {
        Spacer()
    }
    .frame(width: 600, height: 400)
    .onAppear {
        ToastManager.shared.success("Workspace created successfully!")
    }
    .toast()
}

#Preview("Toast Error") {
    VStack {
        Spacer()
    }
    .frame(width: 600, height: 400)
    .onAppear {
        ToastManager.shared.error("Failed to delete workspace")
    }
    .toast()
}
