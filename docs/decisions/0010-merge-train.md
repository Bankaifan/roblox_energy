# 0010 Merge train: strict status checks

Status: accepted by the owner decision of design 0003 section 9 (issue #154, Refs #124); live only once Daniel imports the file.

Context: with `strict_required_status_checks_policy: false` a PR merged while behind `main`, so a semantic break between two green PRs reached `main` unchecked. The train (`tools/train.py`, `train.yml`) and the re-approval (`tools/reapprove.py`) are live (#150-#153) and ran without the flag.

Decision:
- `.github/rulesets/main.json` sets `strict_required_status_checks_policy: true`. Nothing else in the ruleset changes. A PR can merge only when tested on the current `main`; the train rebases the ready PR.
- `tests/test_ruleset.py` asserts the flag (proof that the flip happened).
- The file does not apply itself: no workflow writes rulesets. Daniel re-imports it (Settings > Rules > Rulesets > `main` > Import) or sets the same flag in the UI. Until then the live ruleset stays `false`.

Consequences:
- A bug in the train or the re-approval stops merges until the flag is `false` again (one line in `main.json` plus a re-import; Daniel also has the admin bypass).
- Projects from the template get the change by template sync (`.github/rulesets/` is managed); each repo adopts it by importing.

Open: the scratch-repo measurements of design 0003 section 6 (does `update-branch` dismiss the approval, do all four checks start) are not recorded here.
