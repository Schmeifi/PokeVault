# Rare Candy UI — Design Tokens

Zentrale Tokens: `Utilities/PokeVaultTheme.swift` (`PV`).

Stitch-Quelle: `docs/ux-rarecandy/` (DESIGN.md + HTML-Mocks). Mapping: `docs/ux-rarecandy/IMPLEMENTATION.md`.

## Sprache

- **Canvas:** helles `#F4F5F9` / `#f7f9ff` (`PV.canvas` / `PV.surface`) — kein Pokédex-Rot-Chassis
- **Sheet:** Weiß (`PV.sheet`) mit weichen Schatten
- **Primary:** Mint `#006b58` / Container `#48d0b0`
- **Secondary:** Coral `#ac3236` / `#fc6d6d`
- **Typen:** Grass / Fire / Water / Electric / Psychic (`PV.ElementTone`)
- **Typo:** Plus Jakarta Sans (gebündelt) mit SF-Rounded-Fallback — kein Inter/Roboto
- **Motion:** `pvDexAppear()`, Scan-Pulse, `contentTransition(.numericText())`

## Kontrast

- Primär Light Theme — kein Grau-auf-Schwarz
- `PV.ink` / `PV.inkSecondary` / `PV.inkMuted` für Text
- Listen: `.scrollContentBackground(.hidden)` + `pvListRowStyle()` / `PV.listRow`
- Chrome: `PVChrome.applyGlobalAppearance()` (helle TabBar, Mint-Tint)

## Anwendung

Dashboard (Mint-Hero), Meine Karten (2-Spalten Typ-Karten), Sammlungen, Scanner (Viewfinder + Match-Sheet), Entdecken, Settings und Sheets.
