# API-Quellen (nur kostenlos & dokumentiert)

Stand der Verifikation: Abruf gegen `https://api.tcgdex.net/v2/` und Docs `https://tcgdex.dev/` (0.3.1 UX/Scanner).

Nummernsuche: `localId` (z. B. `TG22`), zusätzlich `id=like:…` **nur** bei spezifischen Tokens (volle Card-ID oder alphanumerische Nummern ≥3 mit Buchstaben) — kurze Ziffern erzeugen sonst hunderte Treffer. Slash-Formen `TG22/TG30` → Primär + Alternaten. DE+EN Merge; EN-`image` angereichert wenn DE fehlt.

Bilder: dokumentiertes `{image}/{quality}.{extension}`; Fallbacks webp→png, de↔en im Asset-Pfad; Trainer-Gallery ohne `image`: CDN unter Haupt-Set (`…/swsh9/TG22/…`) nur nach erfolgreichem HTTP-Download, sonst Platzhalter.

Suche (App): Debounce ~300 ms, In-Memory-Cache (~120 s), `itemsPerPage` gedeckelt, begrenzte Parallelität, Scanner rankt max. 12 Kandidaten nach Name/Nummer/Set.

## Primär: TCGdex

| | |
|---|---|
| Docs | https://tcgdex.dev/ |
| REST-Basis | `https://api.tcgdex.net/v2/` |
| Assets | https://tcgdex.dev/assets |
| Auth | **Kein API-Schlüssel** |
| Kosten | Kostenlos / Open Source (MIT-Datensatz) |
| Kreditkarte | Nicht erforderlich |
| Sprachen | u. a. `de`, `en`, `fr`, `es`, `it`, `pt`, … |

### Genutzte Endpunkte (GET)

| Zweck | Pfad | Query (dokumentiert) |
|---|---|---|
| Kartensuche / Liste | `/v2/{locale}/cards` | `name`, `set.id` (z. B. `eq:swsh3`), `localId`, `rarity` (`like:`/`eq:`), `category`, `pagination:page`, `pagination:itemsPerPage` |
| Kartendetail | `/v2/{locale}/cards/{id}` | — |
| Sets | `/v2/{locale}/sets` | `name`, `pagination:…`, `sort:field`, `sort:order` |
| Set-Detail | `/v2/{locale}/sets/{id}` | liefert u. a. `releaseDate`, `serie`, `legal`, `cardCount`, `cards[]` |
| Seltenheiten | `/v2/{locale}/rarities` | Liste für Filter-UI |
| Serien | `/v2/{locale}/series` | — |

Kategorie-Chips (TG/GG/SV): `localId`-Präfix + clientseitiger Prefix-Check. Illustration/Secret/Ultra/Holo: `rarity=like:…` (Locale-Tokens DE/EN). Set-Marktwert: Summe bekannter `pricing.cardmarket` EUR aus Kartendetails — fehlende Preise → „—“ / teilweise, nie geschätzt.

Filter-Präfixe laut Docs: `like:`, `eq:`, `not:`, … (https://tcgdex.dev/rest/filtering-sorting-pagination).

**Hinweis:** Für `localId` wird absichtlich der laxistische Filter ohne `eq:` genutzt – striktes `eq:` liefert in der Praxis oft leere Treffer.

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
- zeigt in Entdecken/Vorschau vorhandene EUR-Kennzahlen; sonst klar „Kein Marktpreis verfügbar“

TCGPlayer-USD-Felder werden dekodiert, aber nicht als EUR-Marktpreis ausgewiesen.

**API-Limits (ehrlich):** TCGdex nennt öffentlich keinen harten Key-Rate-Limit; Fair Use + HTTP-Cache + max. 4 parallele Requests in der App. CDN/API können bei Last 5xx/Timeouts liefern — die App zeigt Fehler, erfindet keine Daten. Preisabdeckung ist unvollständig (nicht jede Karte hat `pricing.cardmarket`).

## Alternativen-Check (0.3.1) — Wechsel?

| Quelle | Auth | Kosten / Falle | DE-Locale | Cardmarket-EUR | Fazit |
|---|---|---|---|---|---|
| **TCGdex** | Kein Key | Dauerhaft frei, OSS | Ja | Ja (wenn Feld vorhanden) | **Bleibt Primär** |
| Pokémon TCG API (pokemontcg.io) | Ohne Key stark limitiert; Key für sinnvolle Limits | „Free“-Key üblich; kommerzielle Pläne existieren; Key-Zwang für brauchbare Nutzung | EN-fokussiert | Keine TCGdex-gleiche Cardmarket-EUR-Kette | **Nicht wechseln** — schlechtere Free-ohne-Key-Erfahrung, kein klarer DE+EUR-Gewinn |
| Cardmarket API | Vendor-API | Kostenpflichtig | — | Ja, aber verboten hier | Verboten |
| Scraping | — | Rechtlich/ToS riskant | — | — | Verboten |

**Entscheidung:** Kein Wechsel. Keine andere geprüfte Quelle ist klar besser **und** dauerhaft frei ohne Kreditkarte/Key-Falle bei gleichwertigem DE-Katalog + optionalen Cardmarket-EUR-Feldern.

## Explizit nicht verwendet

- Cardmarket kostenpflichtige API
- Scraping von Cardmarket oder anderen Shops
- Pokémon TCG API als Primärquelle (Key-/Limit-Falle für Kernfeatures)
- Kostenpflichtige KI-/Bilderkennungs-APIs
- Cloud-Datenbanken mit verpflichtenden Kosten
- Firebase / Supabase

## PriceProvider-Kette

1. TCGdex Cardmarket-Referenz (wenn vorhanden)
2. Manuelle Bewertung am Exemplar (`ManualPriceProvider`-Stub / `OwnedCard.manualValue`)
3. Zuletzt gespeicherter `PriceSnapshot`
4. Sonst: nicht verfügbar

Aktuelle Wert-Priorität in der UI: **Markt-Snapshot → manuell → fehlend**.

Beispieldaten nutzen die Quelle `sample` und sind in der UI orange/mit Banner markiert — **kein Auto-Seed** beim App-Start (nur Settings „Beispieldaten laden“ / Previews / Tests).

## Caching & Fair Use

- `URLSession` mit HTTP-Cache (`URLCache`) für JSON und Bilder
- In-Memory `SearchResponseCache` (~120 s) für Suchtreffer
- Debounce der Entdecken-Suche (~300 ms)
- begrenzte Parallelität (`TCGdexProvider` max. 4, `CardImageCache` max. 3)
- lokale SwiftData-Zwischenspeicherung von Katalog, Sets und Snapshots
- Disk-Cache für Kartenbilder (offline-lesbar)
- sinnvolle `User-Agent`-Kennung (`PokeVault/0.2`)
