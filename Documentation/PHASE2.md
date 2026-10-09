# Phase 2 – Katalog, Bilder & Portfolio

## Geliefert

- Erweiterter `TCGdexProvider`: Suche nach Name / `set.id` / `localId`, bilinguale Suche, Set-Detail, Serien
- `TCGdexImageURL` + `CardImageCache` + `CachedCardImageView`
- Entdecken: Suche + Set-Browser
- Add-Flow: Katalog-Picker mit Bildvorschau und Varianten
- Portfolio/GuV: Kaufpreis first-class, Dashboard-Totals, per-card Δ, Swift Chart (Kauf vs. Aktuell) nur bei echten Daten
- `ManualPriceProvider` Stub + `PriceProviderChain`
- CI-Constraints unverändert: macos-15, Xcode 16, Info.plist excluded, `#Predicate` lokale Captures

## Nicht in Phase 2

- Wishlist / CSV-Export (Phase 3)
- Scanner (Phase 3)
- Historische Preischarts aus erfundenen Punkten
