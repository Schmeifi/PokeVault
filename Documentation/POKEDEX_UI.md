# Pokédex UI — Design Tokens

Zentrale Tokens: `Utilities/PokeVaultTheme.swift` (`PV`).

## Sprache

- **Chassis:** tiefes Pokédex-Rot (`PV.chassis`)
- **Screen:** dunkle LCD-Fläche (`PV.screen`) mit Cyan-Glow (`PV.readout`)
- **Status:** Grün / Gelb / Rot Readouts
- **Typo:** SF Rounded (Display/UI) + Monospaced (Zahlen/IDs) — kein Inter/Roboto
- **Motion:** `pvDexAppear()`, `contentTransition(.numericText())` auf Werten, Tab-Tint Cyan

## Anwendung

Dashboard, Meine Karten, Sammlungen, Scanner, Entdecken, Settings nutzen `PVBackground` / `PVScreenPanel` / `PVBrandHeader`.
