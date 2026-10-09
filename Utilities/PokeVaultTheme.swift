import SwiftUI
import UIKit

/// PokéVault Design-Tokens — Rare Candy / Pocket Monster Living Dex (Stitch).
/// Primär helles Canvas; kein Pokédex-Rot-Chassis, kein Grau-auf-Schwarz.
enum PV {
    // MARK: Canvas & surfaces (DESIGN.md)

    /// Primärer Backdrop `#F4F5F9` / Material `#f7f9ff`
    static let canvas = Color(hex: 0xF4F5F9)
    static let surface = Color(hex: 0xF7F9FF)
    static let surfaceDim = Color(hex: 0xD2DBE8)
    static let surfaceBright = Color(hex: 0xF7F9FF)
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(hex: 0xEDF4FF)
    static let surfaceContainer = Color(hex: 0xE6EFFC)
    static let surfaceContainerHigh = Color(hex: 0xE0E9F6)
    static let surfaceContainerHighest = Color(hex: 0xDAE3F0)
    static let surfaceVariant = Color(hex: 0xDAE3F0)
    static let sheet = surfaceContainerLowest

    // MARK: Ink

    static let ink = Color(hex: 0x131C26)
    static let inkTitle = Color(hex: 0x303943)
    static let inkSecondary = Color(hex: 0x7A8593)
    static let inkMuted = Color(hex: 0xA5AEB8)
    static let onSurfaceVariant = Color(hex: 0x3C4A45)
    static let outline = Color(hex: 0x6C7A75)
    static let outlineVariant = Color(hex: 0xBBCAC3)

    // MARK: Brand

    static let primary = Color(hex: 0x006B58)
    static let onPrimary = Color.white
    static let primaryContainer = Color(hex: 0x48D0B0)
    static let onPrimaryContainer = Color(hex: 0x005545)
    static let primaryFixed = Color(hex: 0x76F9D7)
    static let inversePrimary = Color(hex: 0x56DCBB)

    static let secondary = Color(hex: 0xAC3236)
    static let onSecondary = Color.white
    static let secondaryContainer = Color(hex: 0xFC6D6D)
    static let onSecondaryContainer = Color(hex: 0x6D0011)

    static let tertiary = Color(hex: 0x00639B)
    static let onTertiary = Color.white
    static let tertiaryContainer = Color(hex: 0x7CC1FF)
    static let onTertiaryContainer = Color(hex: 0x004E7C)
    static let tertiaryFixed = Color(hex: 0xCEE5FF)

    static let error = Color(hex: 0xBA1A1A)
    static let errorContainer = Color(hex: 0xFFDAD6)

    static let statusOK = primaryContainer
    static let statusWarn = Color(hex: 0xFFCE4B)
    static let statusBad = secondaryContainer
    static let gain = Color(hex: 0x38A88E)
    static let loss = Color(hex: 0xDE5252)

    // MARK: Compatibility aliases (ex-Pokédex chrome → Rare Candy)

    /// Früher Chassis-Rot — jetzt Primary Mint (Akzent/Tint).
    static let chassis = primary
    static let chassisDark = onPrimaryContainer
    /// Früher dunkler LCD — jetzt Sheet/White.
    static let screen = sheet
    static let screenElevated = surfaceContainerLow
    /// Früher Cyan-Readout — jetzt Primary.
    static let readout = primary
    static let onScreen = ink
    static let onScreenMuted = inkSecondary
    static let onChassis = ink
    static let onChassisMuted = inkSecondary
    static let creamPanel = sheet
    static let creamOnPanel = inkTitle
    static let listRow = sheet
    static let secondaryLabel = inkSecondary
    static let tertiaryLabel = inkMuted

    // MARK: Element / type tokens

    enum ElementTone: String, CaseIterable, Identifiable {
        case grass, fire, water, electric, psychic, defaultTone

        var id: String { rawValue }

        var hero: Color {
            switch self {
            case .grass: return Color(hex: 0x48D0B0)
            case .fire: return Color(hex: 0xFB6C6C)
            case .water: return Color(hex: 0x76BEFE)
            case .electric: return Color(hex: 0xFFCE4B)
            case .psychic: return Color(hex: 0x9F5BBA)
            case .defaultTone: return PV.primaryContainer
            }
        }

        var light: Color {
            switch self {
            case .grass: return Color(hex: 0x5CE1C6)
            case .fire: return Color(hex: 0xFD8585)
            case .water: return Color(hex: 0x8ECBFE)
            case .electric: return Color(hex: 0xFFD86E)
            case .psychic: return Color(hex: 0xB371CD)
            case .defaultTone: return PV.primaryFixed
            }
        }

        var accent: Color {
            switch self {
            case .grass: return Color(hex: 0x38A88E)
            case .fire: return Color(hex: 0xDE5252)
            case .water: return Color(hex: 0x509CE6)
            case .electric: return Color(hex: 0xF2B824)
            case .psychic: return Color(hex: 0x823F9D)
            case .defaultTone: return PV.primary
            }
        }

        var onHero: Color {
            switch self {
            case .electric: return PV.inkTitle
            default: return .white
            }
        }

        var shadow: Color {
            hero.opacity(0.40)
        }

        var titleDE: String {
            switch self {
            case .grass: return "Pflanze"
            case .fire: return "Feuer"
            case .water: return "Wasser"
            case .electric: return "Elektro"
            case .psychic: return "Psycho"
            case .defaultTone: return "Alle"
            }
        }

        static func from(types: [String]) -> ElementTone {
            let lowered = types.map { $0.lowercased() }
            if lowered.contains(where: { $0.contains("grass") || $0.contains("pflanze") || $0.contains("poison") || $0.contains("gift") }) {
                return .grass
            }
            if lowered.contains(where: { $0.contains("fire") || $0.contains("feuer") || $0.contains("dragon") || $0.contains("drache") }) {
                return .fire
            }
            if lowered.contains(where: { $0.contains("water") || $0.contains("wasser") || $0.contains("ice") || $0.contains("eis") }) {
                return .water
            }
            if lowered.contains(where: { $0.contains("electric") || $0.contains("elektro") || $0.contains("lightning") }) {
                return .electric
            }
            if lowered.contains(where: {
                $0.contains("psychic") || $0.contains("psycho") || $0.contains("ghost") || $0.contains("geist")
                    || $0.contains("fairy") || $0.contains("fee") || $0.contains("dark") || $0.contains("unlicht")
            }) {
                return .psychic
            }
            return .defaultTone
        }

        /// Stabile Farbe wenn Typen fehlen (Name/ID-Hash).
        static func from(seed: String) -> ElementTone {
            let tones: [ElementTone] = [.grass, .fire, .water, .electric, .psychic]
            let hash = seed.unicodeScalars.reduce(0) { ($0 &+ Int($1.value) &* 31) }
            return tones[abs(hash) % tones.count]
        }
    }

    // MARK: Typography — Plus Jakarta Sans (gebündelt) oder SF Rounded

    private static let jakartaCandidates = [
        "Plus Jakarta Sans",
        "PlusJakartaSans",
        "PlusJakartaSansRoman-Regular",
        "PlusJakartaSans-Regular"
    ]

    private static var resolvedJakartaName: String? {
        for name in jakartaCandidates {
            if UIFont(name: name, size: 12) != nil { return name }
        }
        return UIFont.familyNames.first { $0.localizedCaseInsensitiveContains("Jakarta") }
    }

    private static func jakarta(_ style: Font.TextStyle, weight: Font.Weight) -> Font {
        let size = UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize
        if let name = resolvedJakartaName {
            return .custom(name, size: size).weight(weight)
        }
        return .system(style, design: .rounded).weight(weight)
    }

    static func brand(_ style: Font.TextStyle = .largeTitle) -> Font {
        jakarta(style, weight: .heavy)
    }

    static func title(_ style: Font.TextStyle = .title2) -> Font {
        jakarta(style, weight: .bold)
    }

    static func headline() -> Font {
        jakarta(.headline, weight: .bold)
    }

    static func body() -> Font {
        jakarta(.body, weight: .medium)
    }

    static func bodyStrong() -> Font {
        jakarta(.body, weight: .semibold)
    }

    static func caption() -> Font {
        jakarta(.caption, weight: .regular)
    }

    static func labelBadge() -> Font {
        jakarta(.caption2, weight: .bold)
    }

    static func labelID() -> Font {
        jakarta(.subheadline, weight: .heavy)
    }

    static func readout(_ style: Font.TextStyle = .title3) -> Font {
        jakarta(style, weight: .bold)
    }

    static func monoCaption() -> Font {
        .system(.caption2, design: .monospaced).weight(.semibold)
    }

    static func statNumber() -> Font {
        jakarta(.caption, weight: .bold)
    }

    // MARK: Metrics (8pt rhythm)

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let space2XL: CGFloat = 32
    static let margin: CGFloat = 20
    static let gutter: CGFloat = 12

    static let radiusSm: CGFloat = 8
    static let radiusDefault: CGFloat = 16
    static let radiusCard: CGFloat = 24
    static let radiusSheet: CGFloat = 32
    static let radiusPill: CGFloat = 999
    static let radiusPanel: CGFloat = radiusCard
    static let radiusScreen: CGFloat = radiusDefault
    static let radiusChip: CGFloat = radiusPill
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(light: Color, dark: Color) {
        // Rare Candy ist primär Light — Dark fällt auf dieselben hellen Flächen zurück,
        // damit nie Grau-auf-Schwarz entsteht.
        self = Color(uiColor: UIColor { traits in
            let chosen = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(chosen)
        })
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

// MARK: - Chrome & components

struct PVPokeballWatermark: View {
    var opacity: Double = 0.15
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
            var path = Path()
            // Outer ring
            path.addEllipse(in: CGRect(x: origin.x + s * 0.04, y: origin.y + s * 0.04, width: s * 0.92, height: s * 0.92))
            // Center band
            path.move(to: CGPoint(x: origin.x + s * 0.04, y: origin.y + s * 0.5))
            path.addLine(to: CGPoint(x: origin.x + s * 0.36, y: origin.y + s * 0.5))
            path.move(to: CGPoint(x: origin.x + s * 0.64, y: origin.y + s * 0.5))
            path.addLine(to: CGPoint(x: origin.x + s * 0.96, y: origin.y + s * 0.5))
            // Button
            path.addEllipse(in: CGRect(x: origin.x + s * 0.36, y: origin.y + s * 0.36, width: s * 0.28, height: s * 0.28))
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: max(2, s * 0.06))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PVBackground: View {
    var body: some View {
        ZStack {
            PV.canvas
            GeometryReader { geo in
                PVPokeballWatermark(opacity: 0.06, color: PV.ink)
                    .frame(width: 180, height: 180)
                    .offset(x: geo.size.width - 100, y: -40)
                Circle()
                    .fill(PV.primaryContainer.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                    .offset(x: -40, y: geo.size.height * 0.55)
                Circle()
                    .fill(PV.tertiaryContainer.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .blur(radius: 36)
                    .offset(x: geo.size.width - 80, y: geo.size.height * 0.25)
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
                RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous)
                    .fill(PV.sheet)
                    .shadow(color: PV.ink.opacity(0.06), radius: 16, y: 6)
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
                RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous)
                    .fill(PV.surfaceContainer)
            )
    }
}

struct PVBrandHeader: View {
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PV.primaryContainer)
                        .frame(width: 28, height: 28)
                    Circle()
                        .stroke(PV.primary, lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
                Text("PokéVault")
                    .font(PV.brand(.title))
                    .foregroundStyle(PV.ink)
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
            }
            if let subtitle {
                Text(subtitle)
                    .font(PV.caption())
                    .foregroundStyle(PV.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PVTypePill: View {
    let title: String
    var onTintedHero: Bool = true

    var body: some View {
        Text(title)
            .font(PV.labelBadge())
            .foregroundStyle(onTintedHero ? Color.white : PV.inkTitle)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(onTintedHero ? Color.white.opacity(0.28) : PV.surfaceContainer)
            )
    }
}

struct PVTypeColoredCard<Content: View>: View {
    let tone: PV.ElementTone
    var minHeight: CGFloat = 200
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content()
                .padding(PV.spaceM)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            PVPokeballWatermark(opacity: 0.18, color: .white)
                .frame(width: 110, height: 110)
                .offset(x: 18, y: 18)
        }
        .background(
            RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous)
                .fill(tone.hero)
                .shadow(color: tone.shadow, radius: 14, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous))
    }
}

struct AppearDexModifier: ViewModifier {
    @State private var open = false

    func body(content: Content) -> some View {
        content
            .opacity(open ? 1 : 0)
            .offset(y: open ? 0 : 8)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
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

    func pvThemedSheet() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PV.canvas.ignoresSafeArea())
            .tint(PV.primary)
    }

    func pvListRowStyle() -> some View {
        listRowBackground(PV.sheet)
            .foregroundStyle(PV.ink)
    }
}

/// Tab-Bar / Navigation: Rare Candy light chrome.
enum PVChrome {
    static func applyGlobalAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(PV.sheet)
        let normal = UIColor(PV.inkMuted)
        let selected = UIColor(PV.primary)
        tab.stackedLayoutAppearance.normal.iconColor = normal
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]
        tab.stackedLayoutAppearance.selected.iconColor = selected
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selected,
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = UIColor(PV.primary)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(PV.canvas.opacity(0.92))
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(PV.inkTitle),
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(PV.inkTitle),
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(PV.primary)

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }
}
