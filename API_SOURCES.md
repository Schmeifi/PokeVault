# API-Quellen (nur kostenlos & dokumentiert)

Stand der Verifikation: Abruf gegen `https://api.tcgdex.net/v2/` und Docs `https://tcgdex.dev/` (Phase 2, 2026-10-09).

## Primär: TCGdex

| | |
|---|---|
| Docs | https://tcgdex.dev/ |
| REST-Basis | `https://api.tcgdex.net/v2/` |
| Assets | https://tcgdex.dev/assets |
| Auth | **Kein API-Schlüssel** |
| Kosten | Kostenlos / Open Source |
| Sprachen | u. a. `de`, `en`, `fr`, `es`, `it`, `pt`, … |

### Genutzte Endpunkte (GET)

| Zweck | Pfad | Query (dokumentiert) |
|---|---|---|
| Kartensuche / Liste | `/v2/{locale}/cards` | `name`, `set.id` (z. B. `eq:swsh3`), `localId`, `pagination:page`, `pagination:itemsPerPage` |
| Kartendetail | `/v2/{locale}/cards/{id}` | — |
| Sets | `/v2/{locale}/sets` | `name`, `pagination:…`, `sort:field`, `sort:order` |
| Set-Detail | `/v2/{locale}/sets/{id}` | liefert u. a. `releaseDate`, `serie`, `legal`, `cardCount`, `cards[]` |
| Serien | `/v2/{locale}/series` | — |

Filter-Präfixe laut Docs: `like:`, `eq:`, `not:`, … (https://tcgdex.dev/rest/filtering-sorting-pagination).

**Hinweis Phase 2:** Für `localId` wird absichtlich der laxistische Filter ohne `eq:` genutzt – striktes `eq:` liefert in der Praxis oft leere Treffer.

### Bilder (Assets)

Karten-`image` und Set-`logo`/`symbol` sind Basis-URLs ohne Extension:

- Karte: `{image}/{quality}.{extension}` mit `quality` = `high`\|`low`, Extension = `webp`\|`png`\|`jpg`
- Logo/Symbol: `{logo\|symbol}.{extension}` (**kein** quality-Segment)

Empfohlen: `webp`. Implementierung: `TCGdexImageURL` + `CardImageCache` (HTTP-`URLCache` + Disk-Cache, begrenzte Parallelität).

### Preisdaten über TCGdex

Kartendetails können unter `pricing.cardmarket` Cardmarket-bezogene Kennzahlen liefern (`avg`, `low`, `trend`, `avg7`, …, `unit`, `idProduct`, `updated`). Optional `variants_detailed[].thirdParty.cardmarket`.

PokéVault:

- übernimmt nur Werte mit `unit == EUR` als Euro-Betrag
- kennzeichnet die Quelle als **TCGdex (Cardmarket-Referenz)**
- erfindet keine Preise, wenn Felder fehlen → „Kein Marktpreis verfügbar“
- behandelt Preise **nicht** als zustandsgenau
- speichert Cardmarket-**IDs**, erfindet aber **keine** Produkt-URLs

TCGPlayer-USD-Felder werden dekodiert, aber nicht als EUR-Marktpreis ausgewiesen.

## Explizit nicht verwendet

- Cardmarket kostenpflichtige API
- Scraping von Cardmarket oder anderen Shops
- Pokémon TCG API-Varianten mit Key-/Abo-Zwang für Kernfeatures
- Kostenpflichtige KI-/Bilderkennungs-APIs
- Cloud-Datenbanken mit verpflichtenden Kosten
- Firebase / Supabase

## PriceProvider-Kette

1. TCGdex Cardmarket-Referenz (wenn vorhanden)
2. Manuelle Bewertung am Exemplar (`ManualPriceProvider`-Stub / `OwnedCard.manualValue`)
3. Zuletzt gespeicherter `PriceSnapshot`
4. Sonst: nicht verfügbar

Aktuelle Wert-Priorität in der UI: **Markt-Snapshot → manuell → fehlend**.

Beispieldaten nutzen die Quelle `sample` und sind in der UI orange/mit Banner markiert.

## Caching & Fair Use

- `URLSession` mit HTTP-Cache (`URLCache`) für JSON und Bilder
- begrenzte Parallelität (`TCGdexProvider` max. 4, `CardImageCache` max. 3)
- lokale SwiftData-Zwischenspeicherung von Katalog, Sets und Snapshots
- Disk-Cache für Kartenbilder (offline-lesbar)
- sinnvolle `User-Agent`-Kennung (`PokeVault/0.2`)
