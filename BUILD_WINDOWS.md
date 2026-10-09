# PokéVault unter Windows 11 bauen und installieren

Ziel: Ohne eigenen Mac und ohne kostenpflichtige Apple-Developer-Mitgliedschaft eine native iOS-App auf dem eigenen iPhone sideloaden.

## Überblick

```
Windows (Cursor) → GitHub push → Actions (kostenloser macos-Runner)
  → XcodeGen + xcodebuild (unsigned) → IPA Artifact
  → Download auf Windows → Sideloadly → iPhone
```

## 1. Code mit Cursor bearbeiten

- Repo klonen und in Cursor öffnen.
- Swift-Dateien und `project.yml` ändern.
- Committen und nach GitHub pushen (Branch oder PR).

Es wird **kein** lokaler iOS-Simulator unter Windows benötigt.

## 2. GitHub Actions Build

1. Push auf `main` / `cursor/**` oder Pull Request / manueller `workflow_dispatch`.
2. Workflow **iOS Unsigned Build** (`.github/workflows/ios-build.yml`) abwarten.
3. Artifact **PokeVault-unsigned-ipa** herunterladen (`PokeVault-unsigned.ipa`).

Der Runner ist `macos-15` + Xcode 16 (GitHub-hosted, kostenloses Kontingent). Es werden **keine** bezahlten Runner verwendet.

## 3. Sideloadly (Windows → iPhone)

1. [Sideloadly](https://sideloadly.io/) für Windows installieren.
2. iPhone per USB verbinden, dem Computer vertrauen.
3. Apple-ID in Sideloadly eintragen (kostenlose ID möglich).
4. `PokeVault-unsigned.ipa` auswählen und installieren.
5. Auf dem iPhone: **Einstellungen → Allgemein → VPN & Geräteverwaltung** → Entwickler-App vertrauen.

### Hinweise zur kostenlosen Apple-ID / App-ID-Kontingent

- Apps von einer kostenlosen ID müssen in der Regel alle **7 Tage** neu signiert/installiert werden.
- Sideloadly kann je nach Version die IPA selbst neu signieren; der CI-Build bleibt unsigned.
- Gerät muss für Sideloadly erreichbar sein (Kabel / ggf. WLAN laut Sideloadly-Doku).

**App-IDs sparen:** Free-Accounts haben oft nur ~10 App-IDs/Woche. PokéVault nutzt **fest** `com.pokevault.collection`.

- Installation einer neuen IPA **mit derselben Bundle-ID** aktualisiert die bestehende App und erzeugt typischerweise **keine neue** App-ID.
- **Nicht** nach jedem kleinen Commit neu sideloaden — Meilenstein-IPAs (z. B. 0.3.0) bündeln.
- Keine zusätzlichen Xcode-Targets (Watch, Widgets, App Clips).

## 4. Status: Sideload-Verifikation

Phase 1 am iPhone bestätigt. **Nächstes empfohlenes Sideload: Meilenstein 0.3.0** — nicht jeden Zwischen-Commit.

## 4b. Meilenstein auf `Schmeifi/PokeVault` (WSL)

```bash
cd ~/genesis
git fetch origin
git checkout main
git pull origin main
git push github main
```

Danach GitHub → Actions → **iOS Unsigned Build** → Artifact **PokeVault-unsigned-ipa** → Sideloadly (gleiche Bundle-ID überschreibt die App).

## 5. Alternativen (ebenfalls ohne bezahlte Dev-Membership)

| Weg | Bemerkung |
|---|---|
| Sideloadly | Üblich unter Windows |
| AltStore / SideStore | Andere Sideload-Ökosysteme; eigene Setup-Schritte |
| TrollStore | Nur auf bestimmten iOS-/Gerätekonstellationen |

Keine dieser Alternativen erfordert eine bezahlte Apple-Developer-Mitgliedschaft für privaten Eigengebrauch; alle unterliegen Apples und Tool-Limitierungen.

## 6. Was Windows-User nicht brauchen

- Keinen gemieteten Mac-Cloud-Dienst (verpflichtend)
- Keine Cardmarket-/KI-Abos
- Keine Firebase-/Backend-Kosten

## Troubleshooting

| Problem | Idee |
|---|---|
| Actions rot | Logs: Xcode-Version, XcodeGen, Signatur-Flags (`CODE_SIGNING_ALLOWED=NO`) |
| IPA fehlt | Artifact-Schritt, `package-unsigned-ipa.sh`, ob `.app` gefunden wurde |
| Sideloadly Fehler | Apple-ID, Gerätevertrauen, IPA erneut bauen |
| App startet nicht | iOS 17+ nötig; Vertrauensstellung der Entwickler-App |
