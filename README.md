# PokéVault

Native iOS-App (Swift / SwiftUI / SwiftData) für private Pokémon-Sammelkarten — **Pokédex-UI**, lokale Daten, kostenloses TCGdex.

| | |
|---|---|
| Bundle-ID | **`com.pokevault.collection`** (nie ändern — Sideloadly App-ID wiederverwenden) |
| Ziel | iOS 17+ |
| Version | **0.3.0** (Meilenstein: Suche/Bilder + Phases 3–7 + Pokédex-UI) |
| UI | Deutsch |

## Features (0.3.0)

- TCGdex-Suche DE/EN inkl. Nummern (`TG22`, `TG22/TG30`), Set-Browser, Bild-Cache mit Fallbacks
- Portfolio/GuV, Preis-Snapshots & Verlauf nur aus echten Daten
- Set-Fortschritt / fehlende Karten, Wunschliste → Sammlung
- Scanner: Vision-OCR (Foto), Kandidaten-Bestätigung
- Themen, JSON-Backup Import/Export
- GitHub Actions unsigned IPA (`macos-15` + Xcode 16)

## Sideloadly / App-IDs (wichtig)

Free Apple-IDs haben ein **knappes App-ID-Kontingent**. Diese App behält fest `com.pokevault.collection`.

- Neuinstallation **derselben** IPA/Bundle-ID **überschreibt** die App und verbraucht typischerweise **keine neue** App-ID.
- **Nicht** nach jedem kleinen Push neu sideloaden — warte auf Meilenstein-Builds (wie 0.3.0).
- Keine zusätzlichen Targets (Watch/Widgets/App Clips) in diesem Repo.
- Details: [BUILD_WINDOWS.md](BUILD_WINDOWS.md)

## Lokal / CI

```bash
./Scripts/generate-project.sh
```

CI: `.github/workflows/ios-build.yml` → Artifact **PokeVault-unsigned-ipa**.

## Docs

| Datei | Inhalt |
|---|---|
| [BUILD_WINDOWS.md](BUILD_WINDOWS.md) | Windows + Sideloadly + App-IDs |
| [API_SOURCES.md](API_SOURCES.md) | TCGdex only |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Schichten + UI-Tokens |
| [Documentation/POKEDEX_UI.md](Documentation/POKEDEX_UI.md) | Design-System |
| [ROADMAP.md](ROADMAP.md) | Phasen |

## Einschränkungen

- Keine erfundenen Preise; fehlende TCGdex-Bilder → Platzhalter (TG: dokumentierter CDN-Fallback nach erfolgreichem Download)
- Scanner speichert nie automatisch bei niedriger OCR-Konfidenz
- Kein Login, keine kostenpflichtigen Dienste
