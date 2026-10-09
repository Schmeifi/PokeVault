# PokéVault

Native iOS-App (Swift / SwiftUI / SwiftData) für private Pokémon-Sammelkarten — **Pokédex-UI**, lokale Daten, kostenloses TCGdex.

| | |
|---|---|
| Bundle-ID | **`com.pokevault.collection`** (nie ändern — Sideloadly App-ID wiederverwenden) |
| Ziel | iOS 17+ |
| Version | **0.3.6** (Mehrfach-Wunschlisten, Entdecken-Filter, Set-Marktwert) |
| UI | Deutsch |

## Features (0.3.6)

- Mehrere Wunschlisten (anlegen/umbenennen/löschen) · aus Entdecken hinzufügen
- Entdecken: Kategorie-Chips (TG/GG/SV/IR/…) · Filter Set / Seltenheit / Pokémon-Name
- Set-Detail: Sortierung nach Seltenheit · Summen-Marktwert aus bekannten TCGdex/Cardmarket-EUR (teilweise → Kennzeichnung)
- TCGdex-Suche DE/EN inkl. Nummern (`TG22`), Debounce/Cache, Bild-Cache
- Scanner: Close-up Wide-Kamera + Nummer-OCR · Sammlungen · Portfolio/GuV
- Leerer Store beim Start (Beispieldaten nur explizit in Einstellungen)
- GitHub Actions unsigned IPA (`macos-15` + Xcode 16)

## Sideloadly / App-IDs (wichtig)

Free Apple-IDs haben ein **knappes App-ID-Kontingent**. Diese App behält fest `com.pokevault.collection`.

- Neuinstallation **derselben** IPA/Bundle-ID **überschreibt** die App und verbraucht typischerweise **keine neue** App-ID.
- **Nicht** nach jedem kleinen Push neu sideloaden — **ein** Sideload-Overwrite für 0.3.6.
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
- Scanner speichert nie automatisch; Konfidenz spiegelt Match-Qualität (nicht OCR-Textmenge)
- TCGdex-Preise sind Referenzen, nicht zustandsgenau; Abdeckung unvollständig
- Kein Login, keine kostenpflichtigen Dienste
