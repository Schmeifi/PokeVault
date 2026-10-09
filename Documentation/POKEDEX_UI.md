# Pokédex UI — Design Tokens

Zentrale Tokens: `Utilities/PokeVaultTheme.swift` (`PV`).

## Sprache

- **Chassis:** tiefes Pokédex-Rot (`PV.chassis`)
- **Screen:** dunkle LCD-Fläche (`PV.screen`) mit Cyan-Glow (`PV.readout`)
- **Status:** Grün / Gelb / Rot Readouts
- **Typo:** SF Rounded (Display/UI) + Monospaced (Zahlen/IDs) — kein Inter/Roboto
- **Motion:** `pvDexAppear()`, `contentTransition(.numericText())` auf Werten, Tab-Tint Cyan

## Kontrast

- `PV.onScreen` / `PV.onScreenMuted` statt System-`.secondary`/`.tertiary` auf dunklen Screens (Grau-auf-Schwarz vermeiden).
- Listen: `.scrollContentBackground(.hidden)` + `pvListRowStyle()` / `PV.listRow`.
- Chrome: `PVChrome.applyGlobalAppearance()` für TabBar/Navigation (helle Labels auf Rot).

## Anwendung

Dashboard, Meine Karten, Sammlungen, Scanner, Entdecken, Settings und Sheets nutzen `PVBackground` / `PVScreenPanel` / `PVBrandHeader` / `pvThemedSheet()`.
