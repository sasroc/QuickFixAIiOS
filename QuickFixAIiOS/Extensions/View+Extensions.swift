import SwiftUI

extension View {
    // MARK: - Card style
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(12)
    }

    // MARK: - Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    // MARK: - Shake animation (for error feedback)
    func shake(trigger: Bool) -> some View {
        self.modifier(ShakeModifier(trigger: trigger))
    }

    // MARK: - Branded primary button
    func primaryButtonStyle(disabled: Bool = false) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? Color.gray.opacity(0.4) : Color.brand)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .fontWeight(.semibold)
    }
}

// MARK: - Shake modifier

struct ShakeModifier: ViewModifier, Animatable {
    var trigger: Bool
    @State private var shakes: CGFloat = 0

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakes * .pi * 2) * 8)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.05).repeatCount(5)) {
                        shakes = 1
                    }
                }
            }
    }
}
