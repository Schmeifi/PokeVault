# PokéVault

Native iOS-App (Swift / SwiftUI / SwiftData) zur Verwaltung einer privaten Pokémon-Sammelkarten-Sammlung.

**Phase 2** baut auf der lauffähigen Phase-1-Basis auf: volle TCGdex-Katalogsuche (DE/EN), Set-Browser, Bild-Caching, und ein Portfolio/GuV-Überblick (Kaufpreis vs. aktueller Wert) – ohne erfundene Preise.

| | |
|---|---|
| Bundle-ID | `com.pokevault.collection` |
| Ziel | iOS 17+ |
| Version | 0.2.0 |
| Kosten | Keine verpflichtenden Kosten (freie TCGdex-API, lokaler Speicher) |
| Sprache UI | Deutsch |

## Features (Phase 1 + 2)

- SwiftUI-Tabs: Dashboard, Meine Karten, Sammlungen, Scanner, Entdecken
- SwiftData: Katalog, Besitz, Sets, Preise, Sammlungen, Wishlist-Modelle
- TCGdex-Suche: Name, Set-ID, Kartennummer; Set-Katalog mit Metadaten
- Kartenbilder mit HTTP- und lokalem Disk-Cache (offline-lesbar)
- Katalog-Picker im Add-Flow inkl. Vorschau und Druckvarianten
- Portfolio: Kaufpreis, aktueller Wert, Differenz (€/%), Dashboard-GuV, optionales Chart
- Klar markierte Beispieldaten; keine erfundenen Marktpreise
- GitHub Actions: unsigned IPA (`macos-15` + Xcode 16)

## Voraussetzungen

- macOS mit Xcode 16 **oder** GitHub Actions (dieses Repo)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Keine Apple-Developer-Mitgliedschaft für den unsigned CI-Build nötig

Windows-Nutzer ohne Mac: siehe [BUILD_WINDOWS.md](BUILD_WINDOWS.md).

## Lokal bauen (macOS)

```bash
./Scripts/generate-project.sh
open PokeVault.xcodeproj
```

## CI / IPA

Workflow: [`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml)

Nach erfolgreichem Lauf Artifact **PokeVault-unsigned-ipa** herunterladen → Sideloadly.

## Dokumentation

| Datei | Inhalt |
|---|---|
| [BUILD_WINDOWS.md](BUILD_WINDOWS.md) | Windows + Sideloadly-Pfad |
| [API_SOURCES.md](API_SOURCES.md) | Freie Datenquellen, Endpunkte |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Schichten & Modelle |
| [ROADMAP.md](ROADMAP.md) | Phasen |
| [Documentation/PHASE2.md](Documentation/PHASE2.md) | Phase-2-Details |

## Einschränkungen

- Scanner bleibt Platzhalter (Vision in Phase 3).
- Preise nur aus TCGdex-Cardmarket-Feldern (EUR) oder manueller Bewertung – nie erfunden.
- GuV nur für Exemplare mit Kaufpreis **und** aktuellem Wert.
- Keine Cardmarket-API, kein Scraping, kein Firebase/Supabase.

## Lizenz / Daten

Kartendaten über [TCGdex](https://tcgdex.dev/). Pokémon und zugehörige Marken gehören den jeweiligen Rechteinhabern. Diese App ist ein privates, nicht-kommerzielles Sammlungs-Werkzeug.
