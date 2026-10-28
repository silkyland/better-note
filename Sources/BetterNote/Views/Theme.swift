import SwiftUI
import AppKit

enum Theme {
    static let accent = adaptiveColor(light: 0x963F1D, dark: 0xE7A36E)
    static let canvas = adaptiveColor(light: 0xFCF7F0, dark: 0x1C1917)
    static let sidebar = adaptiveColor(light: 0xF2EAE0, dark: 0x24201D)
    static let subtle = Color.primary.opacity(0.045)
    static let line = Color.primary.opacity(0.09)
    private static let notebookColors: [Color] = [
        accent,
        adaptiveColor(light: 0x526C85, dark: 0xA0B6CA),
        adaptiveColor(light: 0x936A25, dark: 0xD9B46D),
        adaptiveColor(light: 0x865A6C, dark: 0xCCA3B4),
        adaptiveColor(light: 0x786354, dark: 0xBEAB9A)
    ]

    static func notebookColor(_ index: Int) -> Color {
        notebookColors[abs(index % notebookColors.count)]
    }

    private static func adaptiveColor(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct ToolButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 14)).frame(width: 30, height: 28) }
            .buttonStyle(.borderless).help(title).accessibilityLabel(title)
    }
}
