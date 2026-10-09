# Architektur – PokéVault (Phase 1–2)

## Schichten

```
Views / ViewModels     SwiftUI, Observation, Charts (Portfolio)
        ↓
Services               Import, Set-Sync, Sammlungswert/GuV, Image-Cache
        ↓
Providers              TCGdexProvider, ManualPriceProvider, PriceProviderChain
        ↓
Models + Persistence   SwiftData @Model, ModelContainer
```

Keine Cloud, kein Login, kein Backend.

## Ordner

| Ordner | Rolle |
|---|---|
| `App/` | `@main`, Tab-Navigation |
| `Models/` | SwiftData-Modelle & Enums |
| `Views/` | UI nach Feature |
| `ViewModels/` | `@Observable`-Zustand |
| `Services/` | Orchestrierung |
| `Providers/` | Netz/API |
| `Persistence/` | Container, Seeder |
| `Scanner/` | Lokale Scan-Persistenz (Stub) |
| `Collections/` | Sammlungs-Helfer |
| `Statistics/` | Stats-DTOs |
| `Utilities/` | Formatierung |
| `Resources/` | Assets, Info.plist |
| `Tests/` | XCTest |
| `Scripts/` | XcodeGen, IPA-Packaging |
| `Documentation/` | Zusatzdocs |

## Datenmodell (Kern)

- **CardCatalogEntry** – Kartensorte (TCGdex-ID, Namen, Set, Bild, optionale Cardmarket-ID)
- **OwnedCard** – Exemplar (Zustand, Sprache, Variante, Menge, **Kaufpreis/Kaufdatum**, manueller Wert) – **keine** ungewollte Zusammenführung
- **PokemonSet** – lokal gespiegelte TCGdex-Sets (Release, Serie, Zähler)
- **UserCollection**, **CollectionMembership**, **CollectionRule**
- **PriceSnapshot** – Betrag + Quelle + Zeitpunkt (+ Sample-Flag)
- Portfolio/GuV: `OwnedCard.portfolioLine()` + `CollectionValueService` (unbewertete Karten zählen nicht zum aktuellen Gesamtwert)
- **WishlistEntry**, **ThemeTag**, **CardScanResult**, **AppSettings**

Beziehungen über SwiftData `@Relationship`. Strings für Dictionaries/Arrays als JSON-Felder, wo SwiftData keine nativen Maps braucht.

## Navigation

`TabView`:

1. Dashboard  
2. Meine Karten  
3. Sammlungen  
4. Scanner  
5. Entdecken  

Einstellungen als Sheet (Zahnrad in den Tab-Toolbars).

## Build

- `project.yml` → XcodeGen → `PokeVault.xcodeproj`
- Bundle-ID: `com.pokevault.collection`
- Deployment: iOS 17.0
- CI: unsigned Device-Build + IPA unter `Artifacts/`

## Erweiterbarkeit

Neue Preisquellen: weiteres `PriceProvider`.  
Scanner: Vision/AVFoundation in `Scanner/` ohne Cloud-Zwang.  
Smart Collections: `CollectionRule` auswerten (Phase 2+).
