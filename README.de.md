# agent-template

Privates GitHub-Template für Projekte, in denen KI-Agenten Code schreiben und Menschen die Kontrolle behalten.

Leitidee: Regeln, die ein Skript prüfen kann, gehören in CI, nicht in Prompts. Die Agenten lesen eine kurze
`AGENTS.md`, die Strenge liefert CI (`make check`, Ruleset auf `main`).

- Rollen: Orchestrator, Entwickler, Reviewer (`.agents/roles/`). Agenten laufen in GitHub Actions mit
  `claude-code-action@v1` über das Claude-Abo (OAuth-Token, kein API-Key).
- Zwei GitHub-Apps: Autor pusht und öffnet PRs, Approver reviewt. Auto-Merge (rebase) nach Approve und grüner CI. Der Entwickler fasst seinen Branch vor dem Review zu einem Commit von Daniel zusammen, so ist Daniel einziger Autor auf `main`.
- Der Reviewer läuft nur bei grüner CI (`workflow_run` von `validate`) und führt nie PR-Code aus (Checkout von `main`, PR per `gh`). Fix-Runden starten automatisch bei `CHANGES_REQUESTED` oder roter CI (max. 2, dann `needs-human`). Nach dem Push stellt ein Skript-Schritt sicher, dass `validate` auf dem Head-SHA läuft. Dependabot-PRs prüft keine KI: ein Workflow ohne Modell approved Patch/Minor nach grüner CI, Majors bekommen `needs-human`; den Update-Typ liefert `dependabot/fetch-metadata` (Gruppen: höchster Typ gilt), Fallback ist der Titel. Jedes `needs-human` an einem PR fordert zusätzlich Daniels Review an (erscheint unter "Needs your review"). Nur wenn eine Änderung berührt, wer oder was vertraut wird, Token- oder App-Rechte, CODEOWNERS-Pfade oder was das Repo verlässt, beginnt die Arbeit mit einer Design-Studie `docs/design/NNNN-<slug>.md`, die ein Design-Reviewer prüft; andere grosse Arbeit startet direkt mit einem Split im Issue; nur der Abschnitt *Owner decisions* braucht Daniel, ist er leer, wird ohne ihn gemergt. Danach legt der Orchestrator die Umsetzungs-Issues an (Zeile `Design: docs/design/...`, vertrauenswürdig über `tools/trusted_issues.py`).
- `.github/CODEOWNERS`: `@Bankaifan` besitzt nur sicherheitsrelevante Dateien: `AGENTS.md`, CODEOWNERS, `.github/rulesets/`, `tools/trusted_issues.py`, `tools/agent_guard.py`, `tools/ci/risk.py`, `risk.yml`.
- Risikoklassen (`tools/ci/risk.py`, Workflow `risk`): Ein Diff an `permissions:`, `allowedTools`, `allowed_bots`, Secrets/Tokens, Vertrauenslogik, Rulesets, CODEOWNERS oder den Limits in AGENTS.md ist `security` (Label `risk:security`; der Pflicht-Check `risk` bleibt rot, bis Daniel den Head-Commit freigibt). Andere Aenderungen an der Agenten-Infrastruktur sind `infra`. Jeder `infra`/`security`-Agenten-PR braucht zusaetzlich den Security-Reviewer (`.agents/roles/security-reviewer.md`, Status `security-review`), danach Auto-Merge. Was auf Daniel wartet, endet mit einer kurzen deutschen Erklaerung (was, schlimmster Fall, Empfehlung, Ja/Nein-Frage). `risk` und `security-review` ins Ruleset als Pflicht-Checks eintragen.
- Ein Entsperrer (`.agents/roles/unblocker.md`, `.github/workflows/unblocker.yml`) prüft jedes `needs-human` vor Daniel: eine falsche Annahme bekommt eine Korrektur und einen automatischen Neustart (`unblock:1`), ein Fehler in der Agenten-Infrastruktur wird als `prio:1`-Issue gemeldet, nur eine echte Owner-Entscheidung bleibt bei Daniel. Das Modell hat kein Token und keine Shell und liest maskierte Dateien; ein Skript prüft sein Ergebnis und führt alle Aktionen aus (`docs/decisions/0010-unblocker.md`). `UNBLOCKER=off` schaltet ihn ab.
- Wöchentlicher Rule Keeper (ein PR mit Regelvorschlägen, Daniel merged) und täglicher `branch-cleanup` (löscht veraltete `agent/*`-Branches, Dry-Run bei manuellem Start).
- Token-Grenze (`docs/decisions/0016-safety-boundary.md`, Design 0017): Die Modell-Token von Entwickler- und Fix-Läufen haben kein Schreibrecht auf `workflows` oder `actions`; eine Workflow-Änderung läuft als Patch, den `workflow-apply` nach dem Security-Review anwendet. Repo-Variable `DEV_SHELL=free` gibt Entwickler- und Fix-Läufen eine freie Shell (ungesetzt: die Befehlsliste); die Deny-Regeln für `Read` bleiben in beiden Fällen. `.github/rulesets/agent-refs.json` begrenzt das App-Token auf Branches `agent/**`, sobald Daniel es importiert.
- Kontingent knapp: höchstens 4 Agenten-Jobs gleichzeitig (Repo-Variable `MAX_DEV`), Modell je Rolle (haiku Routine, sonnet Kern und Review).
- Autonomer `orchestrator` (nach Merge auf `main` per `workflow_run` von `validate`, täglich, manuell; nur mit Variable `ORCHESTRATOR_ENABLED=true`): schreibt Aufträge, hält max. 2 `agent:dev`-Issues, bearbeitet `needs-human`-PRs, aktualisiert HANDOVER.md per PR ; ein Skript (`tools/prefilter.py`) überspringt den Modelllauf, wenn nichts zu tun ist. Das Issue "Weekly summary" pflegt montags ein Skript ohne Modell; es ergänzt auch per PR eine Zeile in `docs/metrics.csv` (Stufen S/M/L: `docs/decisions/0008-tiers.md`). Actions-Minuten sind in öffentlichen Repos kostenlos; private Repos haben ein monatliches Kontingent, Zeitpläne laufen dort daher langsamer. Monatlicher `scout` (haiku, auch aus Dependabot/CodeQL-Meldungen) eröffnet höchstens `IDEAS_PER_WEEK` (Standard 3, 0 = aus) `idea`-Issues; er setzt nur `idea`. Nur vertrauenswürdige Eingaben steuern Agenten: der Orchestrator sieht nur Issues von Daniel oder mit `approved`/`auto-ok` von Daniel (Skript `tools/trusted_issues.py`). Beide Variablen steuern das Kontingent.

## Einrichtung

1. Template nutzen (privat), Auto-Merge aktivieren, nur Rebase-Merge erlauben.
2. Zwei GitHub-Apps anlegen und installieren (Autor: Contents, Pull requests, Issues, Actions und Workflows schreiben; Approver: Pull requests schreiben).
3. Drei Secrets, in jedem Repo neu zu setzen (werden nicht vom Template geerbt): `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`), `AUTHOR_APP_KEY`, `APPROVER_APP_KEY`. Dazu vier Variablen: `AUTHOR_CLIENT_ID` und `APPROVER_CLIENT_ID` (Client-IDs der Apps, nicht geheim), `AUTHOR_BOT` und `APPROVER_BOT` (Bot-Logins der Apps, z. B. `my-author[bot]`); `setup` prüft sie.
4. Ruleset `.github/rulesets/main.json` importieren (nach jeder Änderung der Datei erneut importieren). Das optionale `agent-refs.json` (nur Agenten-Branches) wird genauso importiert, sobald Daniel es entscheidet.
5. Workflow `setup` manuell starten: legt die Labels an und listet fehlende Secrets (nur Namen).
6. Ersten Auftrag als Issue mit Label `agent:dev` anlegen (oder Kommentar `/dev`; `model:sonnet` für Kernarbeit).

## Grün heißt: die Agenten funktionieren auch

Bei PRs, die `.github/workflows/`, `.github/actions/` oder `tools/ci/` ändern, erzeugt der Pflicht-Check `agent-smoke`
mit den Workflow-Versionen des PRs beide App-Tokens, ruft damit `gh api /installation/repositories` auf und prüft, ob das
Claude-OAuth-Secret existiert (kein Modellaufruf). Ohne solche Pfade wird er übersprungen (= Erfolg). Dependabot-PRs
bekommen keine Actions-Secrets: die fünf Secrets (und die Variablen `AUTHOR_BOT`, `APPROVER_BOT`) auch als
**Dependabot-Secrets** anlegen, sonst schlägt `agent-smoke` dort mit klarer Meldung fehl. `setup` meldet, ob sie existieren
(best effort). Ruleset danach neu importieren.

## Projektdateien (keine Overrides)

Ein Projekt legt eigene Inhalte in vier Dateien ab, die das Template nie verwaltet. Ein Projekt mit diesen Dateien und ohne
Overrides übernimmt jeden Template-Sync als saubere Kopie (`docs/decisions/0008-extension-points.md`,
`docs/design/0016-extension-points.md`).

- `project.mk`: Rezepte für `project-check::`, die `make check` zuletzt ausführt. Das Makefile lädt die Datei, wenn sie existiert.
- `AGENTS.project.md`: Projektregeln, von `CLAUDE.md` nach `AGENTS.md` importiert. Die Limits in `AGENTS.md` haben Vorrang.
- `.agents/checks.json`: `{"required": ["name", ...]}`, zusätzliche Pflicht-Checks. `tools/ruleset.py build` fügt sie dem
  Template-Ruleset hinzu; ein Name, der einen Template-Check wiederholt, oder ein fehlerhafter Name wird abgelehnt. Nach einer
  Änderung das gebaute Ruleset in *Settings > Rules* neu importieren; ein Name gilt erst als Pflicht, wenn GitHub ihn erzwingt.
  Die Datei ist per CODEOWNERS geschützt.
- `.agents/tool-pins.env`: Pins für `RUFF`, `ZIZMOR` oder `ACTIONLINT` als `NAME=version`-Zeilen. Jede andere Zeile oder
  jeder andere Name lässt `tools/ci/install_tools.sh` scheitern.

Template-Tests liegen in `tests/agent/`, daher bleibt `tests/` für die eigenen Tests des Projekts frei.

## Projekte synchron halten

Projekte aus diesem Template bekommen spätere Template-Änderungen als ein Sync-Issue, nicht über blindes Kopieren. Das
Template hat eine Version `x.y` in `VERSION`: eine Änderung an `x` ist ein Muss-Update, eine Änderung an `y` ist ein kleiner
Fix oder Doku und startet allein keinen Sync (`docs/decisions/0007-template-sync.md`, `docs/design/0011-automatic-template-sync.md`).
`template-sync.yml` prüft täglich (ohne Modell) und startet `tools/template_sync.py`. Ist das `x` des Templates höher als
`synced_version` in `.agents/template.json`, kopiert ein Skript die geänderten Dateien, die zu `managed` passen (`clean`-Dateien
unverändert, `overridden`-Dateien per `git merge-file` zusammengeführt), und öffnet einen PR `Template sync <version>`, der
auch `synced_sha` und `synced_version` setzt. Ein sauberer Sync braucht kein Modell. Eine Datei, deren Zusammenführung
Konflikte hat, bleibt aus diesem PR heraus: der PR heißt `Template sync <kurze sha> part 1`, und das Issue
`Template sync <kurze sha>` (Label `agent:dev`) listet nur die Konflikt-Dateien und endet mit `Template-Sync: <40 hex>`. Der
Orchestrator vertraut dem Issue nur, wenn die Autor-App (`AUTHOR_BOT`) es geschrieben hat. Der Entwickler führt jede
Konflikt-Datei von Hand zusammen und behält dabei die Absicht bei (agent-dev legt die drei Fassungen vorher in das nicht
versionierte `.template/`), setzt `synced_sha` und `synced_version` und öffnet einen PR mit `Closes #<Sync-Issue>`.
Ein PR, der `.github/` berührt, braucht Daniels Freigabe als Code-Owner.

Einrichtung eines Projekts (sechs Schritte):

1. **Autor-App.** Die Autor-App (Einrichtung, Schritt 2) auf dem Projekt installieren und, falls das Template privat ist, auch auf dem Template-Repo.
   Der geskriptete Sync braucht Schreibrechte für `contents` und `pull-requests` auf dem Projekt, für Syncs, die
   `.github/workflows/` ändern, zusätzlich `workflows` (Rechteänderung, Entscheidung von Daniel). Ohne sie fällt der Sync auf das Issue zurück.
2. **Sync-Dateien.** Projekte, die mit *Use this template* entstehen, haben `.github/workflows/template-sync.yml`,
   `tools/template_sync.py` und `tools/template_apply.py` schon. Ältere Projekte kopieren alle drei einmal aus dem Template; spätere Änderungen kommen über den Sync.
3. **`.agents/template.json` anlegen** (Beispiel unten): `template`, `synced_sha` (die 40-stellige Template-SHA, mit der du zuletzt
   übereinstimmst; leer heißt, der Lauf tut nichts), `synced_version` (das `x.y` des Templates, mit dem du zuletzt
   übereinstimmst; fehlt es, gilt `x = 0`, der erste Lauf öffnet also ein Issue), `managed` und `overrides`.
4. **Optionale Variablen.** `TEMPLATE_SYNC=off` schaltet die Prüfung ab. `TEMPLATE_SYNC_MODE` ist standardmäßig `all`
   (jede Template-Version erzeugt einen Sync-PR, kein Gate); `version` synchronisiert nur, wenn sich `x` geändert hat.
   `TEMPLATE_SYNC_APPLY=off` schaltet zurück auf das reine Issue (das Skript öffnet dann keinen PR).
5. **Prüfen.** *Actions > template-sync > Run workflow* mit gesetztem `force` starten: das Gate wird übersprungen. Ein sauberes
   Template ergibt einen PR `Template sync`; ein Konflikt ergibt den PR Teil 1 und das Issue. Ein zweiter Lauf aktualisiert den
   offenen PR oder das Issue, statt ein weiteres anzulegen.
6. **Wenn der letzte Sync-PR gemergt ist** (der Skript-PR oder bei Konflikt der PR des Entwicklers), rücken `synced_sha` und
   `synced_version` auf den Template-Commit und die Version vor, mit der er übereinstimmt; der nächste Sync wartet auf das nächste `x`.

Ein anderes Projekt nutzt dieses Template genauso: mit *Use this template* anlegen, dann Schritte 1 bis 6. Sein Feld
`template` nennt dieses Repo (`Bankaifan/agent-template`); das Template verweist nirgends zurück auf das Projekt.

Beispiel `.agents/template.json` für ein Projekt (einmal von Hand anlegen; die Datei gehört nicht zum Template, damit neue
Projekte nicht darauf zurückzeigen):

```json
{
  "template": "Bankaifan/agent-template",
  "synced_sha": "<40 hex: der Template-Commit, mit dem du zuletzt übereinstimmst>",
  "synced_version": "1.1",
  "managed": [".github/workflows/", ".github/claude-judge-settings.json", ".github/dependabot.yml", ".github/CODEOWNERS", ".github/rulesets/",
              ".agents/roles/", "tools/", "tests/agent/", "AGENTS.md", "CLAUDE.md", "Makefile", "docs/design/README.md"],
  "overrides": [
    {"path": ".github/workflows/agent-fix.yml", "why": "workflow_run.workflows braucht den CI-Namen 'Validate'"},
    {"path": "AGENTS.md", "why": "Projektsatz und Projektregeln"}
  ]
}
```

- `synced_version`: das `x.y` des Templates, mit dem du zuletzt übereinstimmst (setzt der Sync-PR). Die Prüfung liest nur sein `x`.
- `managed`: Pfadpräfixe, die dem Template gehören (`/` am Ende = Verzeichnis). Andere Pfade werden nie gemeldet.
- `overrides`: exakter `path` plus Freitext `why` für den Entwickler. Projektinhalte zuerst in die vier Projektdateien
  legen (siehe *Projektdateien*); ein Override ist eine Ganzdatei-Kopie, die ein Sync nicht aktualisieren kann.
- Eine zu alte `synced_sha` macht nur das erste Issue größer. Ohne Datei oder bei leerer `synced_sha` meldet der Lauf
  `template-sync: no .agents/template.json, skipped` und endet erfolgreich. Im Template-Repo selbst wird ebenfalls übersprungen.
- Listet der Vergleich 300 oder mehr Dateien, kann er abgeschnitten sein. Der Lauf schlägt dann mit Meldung fehl, legt
  kein Issue an und ändert keines.
- Ein privates Template lesen kann nur, wenn die Autor-App auf dem Template-Repo installiert ist.

**Projektwerte.** Lieber Repo-Variablen als geänderte Dateien: `PYTHON_VERSION` (Standard `3.x`), `EXTRA_INSTALL` (Shell-Befehl,
den `tools/ci/install_tools.sh` nach den üblichen Tools ausführt; nur aus der Repo-Variable, nie aus einer Datei im PR-Branch)
und `RUNNER`. `TEMPLATE_SYNC=off` schaltet den Sync ab. `NIGHTLY_HEAVY_TESTS` (Standard `false`): bei `true` verlassen Tests mit `@pytest.mark.slow` PRs und `main` und laufen im nächtlichen Lauf `nightly.yml`, der bei Fehlschlag ein `prio:1`-Issue öffnet. Ein Test wird `slow` markiert, wenn er etwa 5 s braucht oder ein Netzwerk bzw. einen Dienst benötigt (eine Zeile `@pytest.mark.slow` über dem Test; der Marker ist in `tests/conftest.py` registriert, Design in `docs/design/0009-test-scoping.md`). Nur der CI-Name in `workflow_run.workflows` kann keine Variable sein
(GitHub erlaubt dort keine Ausdrücke). Er steht als `[validate]` in `agent-fix.yml`, `agent-review.yml`,
`dependabot-automerge.yml` und `orchestrator.yml`. Heißt die CI eines Projekts anders (z. B. `Validate`), passt es diese
Zeilen an und trägt die Dateien unter `overrides` ein.

Begründung: [docs/decisions/0007-template-sync.md](docs/decisions/0007-template-sync.md).

Alle Repo-Variablen mit Standardwert, Lesern, Wirkung und erlaubten Werten: [docs/variables.md](docs/variables.md).

Details und Grenzen: [README.md](README.md).
