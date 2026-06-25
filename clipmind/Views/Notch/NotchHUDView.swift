//
//  NotchHUDView.swift
//  clipmind
//
//  Tiny capture-confirmation animation that drops from the camera notch
//

import SwiftUI

struct NotchShape: Shape {
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct NotchHUDView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var capIn = false
    @State private var paperVisible = false
    @State private var paperLanded = false
    @State private var squashing = false
    @State private var checkIn = false

    private let teal = Color(red: 0.18, green: 0.83, blue: 0.75)
    private let warm = Color(red: 0.98, green: 0.45, blue: 0.09)

    var body: some View {
        ZStack {
            clipboard
            paper
            checkmark
        }
        .frame(width: 64, height: 30)
        .background(NotchShape().fill(Color.black))
        .overlay(NotchShape().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
        .scaleEffect(capIn ? 1 : 0.6, anchor: .top)
        .offset(y: capIn ? 0 : -14)
        .opacity(capIn ? 1 : 0)
        .frame(width: 64, height: 40, alignment: .top)
        .onAppear(perform: animate)
    }

    private var clipboard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.white, lineWidth: 1.7)
                .frame(width: 13, height: 15)
            RoundedRectangle(cornerRadius: 1.6, style: .continuous)
                .fill(warm)
                .frame(width: 6, height: 3.6)
                .offset(y: -7.3)
        }
        .scaleEffect(x: squashing ? 1.12 : 1, y: squashing ? 0.82 : 1, anchor: .bottom)
        .opacity(checkIn ? 0 : 1)
    }

    private var paper: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(warm)
            .frame(width: 10, height: 12)
            .scaleEffect(paperLanded ? 0.35 : 1)
            .offset(x: paperLanded ? 0 : -14, y: paperLanded ? 0 : -10)
            .opacity(paperVisible ? 1 : 0)
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(teal)
            .scaleEffect(checkIn ? 1 : 0)
            .opacity(checkIn ? 1 : 0)
    }

    private func animate() {
        guard !reduceMotion else {
            capIn = true
            withAnimation(.easeOut(duration: 0.15)) { checkIn = true }
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { capIn = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            paperVisible = true
            withAnimation(.easeIn(duration: 0.24)) { paperLanded = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.10)) { paperVisible = false }
            withAnimation(.easeOut(duration: 0.10)) { squashing = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { squashing = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { checkIn = true }
        }
    }
}
