import SwiftUI
import UIKit

extension Color {

    // MARK: - Brand palette (matches webapp CSS variables exactly)

    /// Primary blue  — --accent-primary: #3b82f6
    static let brandBlue  = Color(red: 0.231, green: 0.510, blue: 0.965)

    /// Primary teal  — used on buttons, badges, interactive elements (#20c997)
    static let brand      = Color(red: 0.125, green: 0.788, blue: 0.592)

    /// Emerald green — --accent-secondary: #10b981
    static let brandGreen = Color(red: 0.063, green: 0.725, blue: 0.506)

    // MARK: - Backgrounds

    /// Page background — --bg-primary light: #f3f4f6 / dark: #111827
    static let appBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1) // #111827
            : UIColor(red: 0.953, green: 0.957, blue: 0.965, alpha: 1) // #f3f4f6
    })

    /// Card background — --card-bg: #ffffff / dark #1f2937
    static let cardBackground  = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.161, blue: 0.216, alpha: 1) // #1f2937
            : .white
    })

    /// Secondary background — --bg-secondary light: #e5e7eb / dark: #1f2937
    static let inputBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.161, blue: 0.216, alpha: 1) // #1f2937
            : UIColor(red: 0.898, green: 0.914, blue: 0.929, alpha: 1) // #e5e7eb
    })

    // MARK: - Semantic
    static let success = Color.brandGreen
    static let warning = Color.orange
    static let danger  = Color.red

    // MARK: - Gradients

    /// Hero gradient: blue #3b82f6 → teal #20c997  (matches webapp landing hero)
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brand],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Trial / CTA gradient: green #28a745 → teal #20c997 → cyan #17a2b8
    static var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.157, green: 0.655, blue: 0.271), // #28a745
                brand,                                          // #20c997
                Color(red: 0.090, green: 0.635, blue: 0.722)  // #17a2b8
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Subtle page section background gradient
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appBackground, brand.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
