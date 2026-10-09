import SwiftUI
import UIKit

/// PokéVault Design-Tokens — Pokédex-Chassis (Rot) + dunkler Screen + Cyan/Grün-Readouts.
/// Light + Dark; Dynamic Type über TextStyle; keine Inter/Roboto-Stacks.
enum PV {
    // MARK: Chassis / Screen

    /// Tiefes Pokédex-Rot (Rahmen/Chrome)
    static let chassis = Color(light: Color(red: 0.78, green: 0.12, blue: 0.16), dark: Color(red: 0.62, green: 0.08, blue: 0.12))
    static let chassisDark = Color(light: Color(red: 0.55, green: 0.08, blue: 0.12), dark: Color(red: 0.38, green: 0.05, blue: 0.08))
    /// Dunkle „LCD“-Fläche
    static let screen = Color(light: Color(red: 0.10, green: 0.14, blue: 0.16), dark: Color(red: 0.06, green: 0.09, blue: 0.11))
    static let screenElevated = Color(light: Color(red: 0.14, green: 0.18, blue: 0.21), dark: Color(red: 0.10, green: 0.13, blue: 0.16))
    /// Readout-Cyan / Status-Grün
    static let readout = Color(light: Color(red: 0.25, green: 0.92, blue: 0.88), dark: Color(red: 0.35, green: 0.95, blue: 0.90))
    static let statusOK = Color(light: Color(red: 0.35, green: 0.90, blue: 0.45), dark: Color(red: 0.40, green: 0.95, blue: 0.50))
    static let statusWarn = Color(light: Color(red: 0.98, green: 0.82, blue: 0.25), dark: Color(red: 1.0, green: 0.88, blue: 0.35))
    static let statusBad = Color(light: Color(red: 1.0, green: 0.35, blue: 0.35), dark: Color(red: 1.0, green: 0.45, blue: 0.45))
    /// Text auf Screen vs. Chrome
    static let onScreen = Color(light: Color(red: 0.85, green: 0.98, blue: 0.95), dark: Color(red: 0.85, green: 0.98, blue: 0.95))
    static let onScreenMuted = Color(light: Color(red: 0.55, green: 0.75, blue: 0.72), dark: Color(red: 0.50, green: 0.70, blue: 0.68))
    static let onChassis = Color.white
    static let creamPanel = Color(light: Color(red: 0.96, green: 0.94, blue: 0.90), dark: Color(red: 0.16, green: 0.15, blue: 0.14))
    static let gain = statusOK
    static let loss = statusBad

    // MARK: Type

    static func brand(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded).weight(.black)
    }

    static func title(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }

    static func headline() -> Font {
        .system(.headline, design: .rounded).weight(.semibold)
    }

    static func body() -> Font {
        .system(.body, design: .rounded)
    }

    static func caption() -> Font {
        .system(.caption, design: .rounded)
    }

    /// Zahlen / IDs wie Pokédex-Readout
    static func readout(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .monospaced).weight(.semibold)
    }

    static func monoCaption() -> Font {
        .system(.caption2, design: .monospaced)
    }

    // MARK: Metrics

    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let radiusPanel: CGFloat = 18
    static let radiusScreen: CGFloat = 14
    static let radiusChip: CGFloat = 8
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Chrome

struct PVBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PV.chassis, PV.chassisDark],
                startPoint: .top,
                endPoint: .bottom
            )
            // Leichte „Gehäuse“-Ringe
            GeometryReader { geo in
                Circle()
                    .stroke(PV.onChassis.opacity(0.12), lineWidth: 40)
                    .frame(width: geo.size.width * 1.2)
                    .offset(x: -geo.size.width * 0.35, y: -80)
                Circle()
                    .fill(PV.readout.opacity(0.12))
                    .frame(width: 70, height: 70)
                    .offset(x: 28, y: 36)
            }
        }
        .ignoresSafeArea()
    }
}

struct PVScreenPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(PV.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PV.radiusScreen, style: .continuous)
                    .fill(PV.screen)
                    .overlay {
                        RoundedRectangle(cornerRadius: PV.radiusScreen, style: .continuous)
                            .strokeBorder(PV.readout.opacity(0.35), lineWidth: 1.5)
                    }
                    .shadow(color: PV.readout.opacity(0.15), radius: 10, y: 0)
            )
    }
}

struct PVCreamPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(PV.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PV.radiusPanel, style: .continuous)
                    .fill(PV.creamPanel)
            )
    }
}

struct PVBrandHeader: View {
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(PV.readout)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(PV.onChassis.opacity(0.5), lineWidth: 1))
                    .shadow(color: PV.readout.opacity(0.7), radius: 6)
                Text("PokéVault")
                    .font(PV.brand(.largeTitle))
                    .foregroundStyle(PV.onChassis)
                    .accessibilityAddTraits(.isHeader)
            }
            if let subtitle {
                Text(subtitle)
                    .font(PV.caption())
                    .foregroundStyle(PV.onChassis.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppearDexModifier: ViewModifier {
    @State private var open = false

    func body(content: Content) -> some View {
        content
            .opacity(open ? 1 : 0)
            .scaleEffect(open ? 1 : 0.97, anchor: .top)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    open = true
                }
            }
    }
}

extension View {
    func pvDexAppear() -> some View {
        modifier(AppearDexModifier())
    }

    func pvScreenBackground() -> some View {
        background { PVBackground() }
    }
}
