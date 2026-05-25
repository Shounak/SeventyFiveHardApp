import SwiftUI

enum Theme {
    static let primary = Color.accentColor
    static let highlight = Color("HighlightColor")
    static let themeText = Color("ThemeTextColor")
    static let green = Color("AccentGreen")
    static let background = Color("AppBackground")
    static let surface = Color("CardSurface")           

    static let cardCornerRadius: CGFloat = 18
    static let cardShadow = Color.black.opacity(0.05)
}

extension View {
    func cardSurface(fill: Color = Theme.surface) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }
}
