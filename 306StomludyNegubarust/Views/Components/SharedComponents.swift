import SwiftUI
import UIKit

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color("AppBackground")
                Image("bg_main")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(colorScheme == .dark ? 0.55 : 0.14)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

struct PaperCard<Content: View>: View {
    var stackDepth: Int = 2
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<stackDepth, id: \.self) { index in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color("AppSurface").opacity(0.55 + Double(index) * 0.12))
                    .offset(x: CGFloat(stackDepth - index) * 3, y: CGFloat(stackDepth - index) * 4)
            }
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color("AppSurface"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color("AppTextPrimary").opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.trailing, CGFloat(stackDepth) * 3)
        .padding(.bottom, CGFloat(stackDepth) * 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Dismisses keyboard on background tap without stealing button/cell taps.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct TopicChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(isSelected ? Color("AppTextPrimary") : Color("AppTextSecondary"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color("AppPrimary").opacity(0.85) : Color("AppSurface").opacity(0.9))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color("AppAccent").opacity(isSelected ? 0.9 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct BannerHeader: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color("AppAccent").opacity(0.25), lineWidth: 1)
                )
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppTextPrimary"))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color("AppTextSecondary"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CircularMilestoneChart: View {
    let progress: Double
    let known: Int
    let total: Int

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                drawChart(context: context, size: size)
            }
            VStack(spacing: 4) {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                Text("\(known)/\(total) known")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))
            }
        }
        .frame(height: 220)
        .accessibilityLabel("Milestone progress \(Int(clamped * 100)) percent")
    }

    private func drawChart(context: GraphicsContext, size: CGSize) {
        let minSide = min(size.width, size.height)
        let inset: CGFloat = 14
        let origin = CGPoint(x: (size.width - minSide) / 2 + inset, y: (size.height - minSide) / 2 + inset)
        let side = minSide - inset * 2
        let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side / 2

        context.stroke(Path(ellipseIn: rect), with: .color(Color("AppSurface")), lineWidth: 18)

        var arc = Path()
        arc.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        let shading: GraphicsContext.Shading = .color(Color("AppPrimary"))
        context.stroke(arc, with: shading, style: StrokeStyle(lineWidth: 18, lineCap: .round))

        let tickColor = Color("AppTextSecondary").opacity(0.45)
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * Double.pi * 2 - Double.pi / 2
            let cosA = CGFloat(cos(angle))
            let sinA = CGFloat(sin(angle))
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + cosA * (radius - 4), y: center.y + sinA * (radius - 4)))
            tick.addLine(to: CGPoint(x: center.x + cosA * (radius + 8), y: center.y + sinA * (radius + 8)))
            context.stroke(tick, with: .color(tickColor), lineWidth: 2)
        }
    }
}

struct SoftConfettiView: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<18, id: \.self) { index in
                    Circle()
                        .fill(index % 2 == 0 ? Color("AppPrimary") : Color("AppAccent"))
                        .frame(width: CGFloat(6 + index % 5), height: CGFloat(6 + index % 5))
                        .opacity(animate ? 0 : 0.85)
                        .offset(
                            x: animate ? CGFloat((index % 6) - 3) * 48 : 0,
                            y: animate ? -CGFloat(80 + index * 8) : 20
                        )
                        .position(
                            x: geo.size.width * (0.2 + CGFloat(index % 5) * 0.15),
                            y: geo.size.height * 0.55
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.35)) {
                animate = true
            }
        }
        .onDisappear { animate = false }
    }
}

enum CategoryStyle {
    static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "methods": return Color("AppPrimary")
        case "organization": return Color("AppAccent")
        case "practice": return Color(red: 0.45, green: 0.72, blue: 0.55)
        case "focus": return Color(red: 0.95, green: 0.62, blue: 0.38)
        case "memory": return Color(red: 0.55, green: 0.68, blue: 0.95)
        default: return Color("AppTextSecondary")
        }
    }

    static func symbol(for category: String) -> String {
        switch category.lowercased() {
        case "methods": return "lightbulb.fill"
        case "organization": return "square.stack.3d.up.fill"
        case "practice": return "flame.fill"
        case "focus": return "timer"
        case "memory": return "sparkles"
        default: return "folder.fill"
        }
    }
}

struct DailyGoalCard: View {
    @EnvironmentObject private var store: LearningStore

    var body: some View {
        PaperCard(stackDepth: 1) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Daily goal")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Color("AppTextPrimary"))
                    Spacer()
                    Text("\(store.stats.cardsReviewedToday)/\(store.preferences.dailyGoal)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AppAccent"))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color("AppBackground").opacity(0.7))
                        Capsule()
                            .fill(Color("AppAccent"))
                            .frame(width: max(8, geo.size.width * store.dailyGoalProgress))
                    }
                }
                .frame(height: 10)
                Text(store.dailyGoalProgress >= 1 ? "Goal reached — nice work." : "Keep reviewing to hit today's target.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))
            }
        }
    }
}

struct AchievementToastOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            PaperCard(stackDepth: 2) {
                HStack(spacing: 12) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color("AppPrimary"))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Achievement unlocked")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color("AppAccent"))
                        Text(achievement.title)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("AppTextPrimary"))
                        Text(achievement.detail)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color("AppTextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                onDismiss()
            }
        }
        .onTapGesture { onDismiss() }
    }
}
