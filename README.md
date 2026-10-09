# PokéVault

Native iOS-App (Swift / SwiftUI / SwiftData) zur Verwaltung einer privaten Pokémon-Sammelkarten-Sammlung.

**Phase 1** liefert die kompilierbare Projektbasis: lokale Persistenz, deutsche UI, Dashboard, Galerie, manuelles Hinzufügen, TCGdex-Gerüst und unsigned CI-Build.

| | |
|---|---|
| Bundle-ID | `com.pokevault.collection` |
| Ziel | iOS 17+ |
| Kosten | Keine verpflichtenden Kosten (freie TCGdex-API, lokaler Speicher) |
| Sprache UI | Deutsch |

## Was Phase 1 enthält

- SwiftUI-`TabView`: Dashboard, Meine Karten, Sammlungen, Scanner, Entdecken + Einstellungen
- SwiftData-Modelle: Katalog, Besitz, Sammlungen, Preise, Wishlist, Scanner-Metadaten, Settings
- Klar markierte **Beispieldaten** (keine erfundenen historischen Marktpreise)
- `TCGdexProvider` gegen dokumentierte REST-Endpunkte (`https://api.tcgdex.net/v2/`)
- XcodeGen `project.yml`
- GitHub Actions: XcodeGen → Compile → unsigned IPA-Artifact (kostenlose `macos-14`-Runner)

## Voraussetzungen

- macOS mit Xcode 15+ **oder** GitHub Actions (dieses Repo)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Keine Apple-Developer-Mitgliedschaft für den unsigned CI-Build nötig

Windows-Nutzer ohne Mac: siehe [BUILD_WINDOWS.md](BUILD_WINDOWS.md).

## Lokal bauen (macOS)

```bash
./Scripts/generate-project.sh
open PokeVault.xcodeproj
```

Oder per CLI:

```bash
xcodegen generate
xcodebuild -project PokeVault.xcodeproj -scheme PokeVault \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## CI / IPA

Workflow: [`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml)

Nach erfolgreichem Lauf Artifact **PokeVault-unsigned-ipa** herunterladen.

## Dokumentation

| Datei | Inhalt |
|---|---|
| [BUILD_WINDOWS.md](BUILD_WINDOWS.md) | Windows + Sideloadly-Pfad |
| [API_SOURCES.md](API_SOURCES.md) | Freie Datenquellen, Endpunkte |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Schichten & Modelle |
| [ROADMAP.md](ROADMAP.md) | Phasen nach Phase 1 |
| [Documentation/](Documentation/) | Ergänzende Notizen |

## Ehrliche Einschränkungen (Phase 1)

- Kein Mac in dieser Cloud-Umgebung: kompilierbarer Quellcode + CI-Workflow; lokaler Xcode-Lauf hier nicht möglich.
- Unsigned IPA-Sideload auf einem physischen iPhone wurde hier **nicht** verifiziert.
- Scanner ist Platzhalter (Vision folgt später).
- Dashboard kann Beispieldaten zeigen – immer als solche gekennzeichnet.
- Keine Cardmarket-API, kein Scraping, keine kostenpflichtigen Dienste.

## Lizenz / Daten

Kartendaten über [TCGdex](https://tcgdex.dev/). Pokémon und zugehörige Marken gehören den jeweiligen Rechteinhabern. Diese App ist ein privates, nicht-kommerzielles Sammlungs-Werkzeug.
