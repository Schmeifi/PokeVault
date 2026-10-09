# API-Quellen (nur kostenlos & dokumentiert)

Stand der Verifikation: Abruf gegen `https://api.tcgdex.net/v2/` und Docs `https://tcgdex.dev/` (Phase 1).

## Primär: TCGdex

| | |
|---|---|
| Docs | https://tcgdex.dev/ |
| REST-Basis | `https://api.tcgdex.net/v2/` |
| Auth | **Kein API-Schlüssel** |
| Kosten | Kostenlos / Open Source |
| Sprachen | u. a. `de`, `en`, `fr`, `es`, `it`, `pt`, … |

### Genutzte Endpunkte (GET)

| Zweck | Pfad |
|---|---|
| Kartensuche / Liste | `/v2/{locale}/cards?name=…&pagination:page=&pagination:itemsPerPage=` |
| Kartendetail | `/v2/{locale}/cards/{id}` |
| Sets | `/v2/{locale}/sets` |
| Set-Detail | `/v2/{locale}/sets/{id}` |
| Serien | `/v2/{locale}/series` |

Bilder: Asset-URLs aus dem Feld `image`, typischerweise ergänzt um `/high.webp` (TCGdex-Asset-Konvention).

### Preisdaten über TCGdex

Kartendetails können unter `pricing.cardmarket` Cardmarket-bezogene Kennzahlen liefern (`avg`, `low`, `trend`, `avg7`, …, `unit`, `idProduct`, `updated`).

PokéVault:

- übernimmt nur Werte mit `unit == EUR` als Euro-Betrag
- kennzeichnet die Quelle als **TCGdex (Cardmarket-Referenz)**
- erfindet keine Preise, wenn Felder fehlen → „Kein Marktpreis verfügbar“
- behandelt Preise **nicht** als zustandsgenau (Mint vs. Played), sofern die API das nicht liefert

## Explizit nicht verwendet

- Cardmarket kostenpflichtige API
- Scraping von Cardmarket oder anderen Shops
- Pokémon TCG API-Varianten mit Key-/Abo-Zwang für Kernfeatures
- Kostenpflichtige KI-/Bilderkennungs-APIs
- Cloud-Datenbanken mit verpflichtenden Kosten

## PriceProvider-Kette

1. TCGdex Cardmarket-Referenz (wenn vorhanden)
2. Manuelle Bewertung am Exemplar
3. Zuletzt gespeicherter `PriceSnapshot`
4. Sonst: nicht verfügbar

Beispieldaten in Phase 1 nutzen die Quelle `sample` und sind in der UI orange/mit Banner markiert.

## Caching & Fair Use

- `URLSession` mit HTTP-Cache (`URLCache`)
- begrenzte Parallelität im `TCGdexProvider` (max. 4)
- lokale SwiftData-Zwischenspeicherung von Katalog + Snapshots
- sinnvolle `User-Agent`-Kennung
