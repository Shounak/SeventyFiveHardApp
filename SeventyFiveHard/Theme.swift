import SwiftUI

enum Theme {
    static let primary = Color.accentColor              // saffron #F08241
    static let maroon = Color("AccentMaroon")           // #5E0000
    static let green = Color("AccentGreen")             // #006E5E
    static let background = Color("AppBackground")      // #DFE0DF
    static let surface = Color("CardSurface")           // near-white card

    static let cardCornerRadius: CGFloat = 18
    static let cardShadow = Color.black.opacity(0.05)
}

extension View {
    func cardSurface() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }
}
