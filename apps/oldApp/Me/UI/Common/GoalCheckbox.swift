import SwiftUI

/// Animated checkbox used for goal/intervention completion with a satisfying fill animation.
struct GoalCheckbox: View {
    /// Whether the checkbox is checked (completed).
    var isChecked: Bool

    private let size: CGFloat = 28

    @State private var showSplash: Bool = false

    var body: some View {
        ZStack {
            // Outline circle
            Circle()
                .stroke(isChecked ? Color.green.opacity(0.7) : Color.secondary, lineWidth: 2)
                .frame(width: size, height: size)

            // Fill circle with overshoot scale
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
                .scaleEffect(isChecked ? 1.15 : 0) // stronger overshoot
                .animation(isChecked ? .interpolatingSpring(stiffness: 600, damping: 16).speed(1.4) : .easeOut(duration: 0.15), value: isChecked)
                .onChange(of: isChecked) { val in
                    if val { triggerSplash() }
                }

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .opacity(isChecked ? 1 : 0)
                .scaleEffect(isChecked ? 1 : 0.5)
                .animation(isChecked ? .spring(response: 0.25, dampingFraction: 0.5) : .linear(duration: 0.1), value: isChecked)

            // Splash particles
            if showSplash {
                SplashView(color: .green, size: size)
                    .transition(.scale)
            }
        }
        .frame(width: 36, height: 36)
    }

    private func triggerSplash() {
        showSplash = true
        // Hide after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSplash = false }
    }

    /// Radial burst of small circles
    private struct SplashView: View {
        var color: Color
        var size: CGFloat
        @State private var animate: Bool = false

        var body: some View {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .offset(y: -size/2)
                        .rotationEffect(.degrees(Double(i) / 8 * 360))
                        .scaleEffect(animate ? 1 : 0.2)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 0.3).delay(0.02 * Double(i)), value: animate)
                }
            }
            .frame(width: size, height: size)
            .onAppear { animate = true }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GoalCheckbox(isChecked: false)
        GoalCheckbox(isChecked: true)
    }
    .padding()
}
