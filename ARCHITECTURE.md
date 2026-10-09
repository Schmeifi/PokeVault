# Architektur – PokéVault (Phases 1–7 / 0.3.0)

## Schichten

```
Views / ViewModels     SwiftUI, Charts, Pokédex-Theme (PV)
        ↓
Services               Import, GuV, Set-Progress, Backup, OCR, Image-Cache, PriceHistory
        ↓
Providers              TCGdexProvider, ManualPriceProvider, PriceProviderChain, Mock
        ↓
Models + Persistence   SwiftData @Model, ModelContainer
```

Keine Cloud, kein Login, kein Backend. Bundle-ID unveränderlich: `com.pokevault.collection`.

## UI

Tokens: `Utilities/PokeVaultTheme.swift` — siehe [Documentation/POKEDEX_UI.md](Documentation/POKEDEX_UI.md).

## CI-Invarianten

- `macos-15` + Xcode 16
- `Info.plist` excluded from Copy Bundle Resources
- `#Predicate` nur mit lokalen Captures
- Ein App-Target (+ Tests) — keine Extra-App-IDs
