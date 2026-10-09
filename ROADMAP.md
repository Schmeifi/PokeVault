# Roadmap

## Phase 1 – Basis ✅

- Projektstruktur, XcodeGen, SwiftData-Modelle
- Tabs, Dashboard, Galerie, manuelles Hinzufügen
- TCGdexProvider (dokumentierte Endpunkte)
- GitHub Actions unsigned IPA
- Docs (README, Windows-Build, API, Architektur)

## Phase 2 – Katalog, Bilder & Portfolio ✅ (dieses Release)

- TCGdex-Suche DE+EN: Name, Set-ID, Kartennummer
- Set-Browser inkl. Release/Serie/Legal/Kartenliste
- Kartenbilder mit HTTP- + lokalem Disk-Cache
- Metadaten: Seltenheit, Typen, Illustrator, Varianten
- Katalogsuche im „Karte hinzufügen“-Flow (Vorschau, Druckvarianten)
- PriceProvider-Stubs bereit; nur vorhandene TCGdex-EUR-Felder
- **Portfolio / GuV (früh aus Phase-3-Ideen):** Kaufpreis, aktueller Wert, Differenz €/%, Dashboard-Totals, optionales Swift-Chart ohne Fake-Historie

## Phase 3 – Preise vertiefen & Scanner

- Robuster Preis-Refresh / Quellen-UI-Feinschliff
- Wishlist-Verwaltung
- Export (CSV/JSON) lokal
- AVFoundation-Kamera + Vision Text/Layout
- Vorschläge gegen lokalen/TCGdex-Katalog
- Keine kostenpflichtige Cloud-KI

## Phase 4 – Sammlungen & Statistik

- Smarte Regeln auswerten
- Swift Charts mit echten Snapshots (weitere Zeitreihen nur aus gespeicherten Ständen)
- Themen-Tags

## Phase 5 – Feinheiten

- Bild-Anhänge (PhotosUI) für Vorder-/Rückseite
- Offline-First-Polituren
- Mehr Tests / UI-Tests auf Simulator in CI

## Nicht geplant (Kosten-/Policy-Grenzen)

- Bezahlte Cardmarket-API oder Scraping
- Pflicht-Cloud-Backend / Login
- Bezahlte Mac-Build-Dienste als Anforderung
- Features, die nur mit Apple-Developer-Abo möglich sind (z. B. TestFlight-Verteilung als Muss) – optional später, nie Pflicht für Eigengebrauch
