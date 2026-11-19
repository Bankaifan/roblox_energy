# 0017 HPO-FLOW: the owner approves releases, nothing else

Decided by Daniel on 2026-11-19. Name of the work: `HPO-FLOW` (commits `V1.101-HPO-FLOW: ...`).

## Goal
The owner's only task is the release PR. Failures, stalls, ideas and outside issues are handled by the system
without talking and without waiting for him.

## Rules
1. **Names.** Every piece of work has one NAME (upper case, hyphens, at most 3 words). Issues and PRs are titled
   `V<major>-<NAME>: <summary>`, every commit `V<VERSION>-<NAME>: <what this commit does>` (`VERSION` = the file on
   main, the last released version). Many small commits, about one file each; no squash; no comments along the way,
   the PR body is the summary (at most 5 lines).
2. **Version.** `VERSION` is the single source. It changes only when the owner merges the release PR, by exactly one
   step per release (`tools/release_fragments.py`). There are no tags and no GitHub releases.
3. **Release PR.** Exactly one open PR `Release <version>` from `release/next` (`tools/train.py`). Body: the
   user-facing changelog lines in `OWNER_LANG`, plus one line naming what is not solved yet. It carries the only
   review request the owner gets.
4. **Never wait.** `needs-human` is gone. After the fix rounds, the restart and the unblocker failed, an item gets
   `parked`: no note, no mention, no review request. `tools/status.py` un-parks it after a cool-down (24 h, doubled
   per park, at most 7 days) with all counters reset, so the next try starts with fresh context. Parked items are
   one line in the release PR. The answer receiver and the decision markers are removed.
5. **Outside issues and ideas.** An issue by anyone else (and a scout idea) is read by the intake step as masked
   data: a model with no token and no shell writes a verdict, a script validates it and answers, declines or opens a
   slip issue (`Intake: #N`) written by the author app. Only that slip is trusted. A PR for an intake slip must be
   risk `none`: it can never change workflows, tools, trust logic or CODEOWNERS paths. The labels `approved` and
   `auto-ok` are gone.
6. **Labels.** A person never sets a label. Kept, all script-set: `agent:dev` (start a developer), `parked`,
   `risk:*`, `prio:*`, `idea`, `model:sonnet` and the round counters. Removed: `needs-human`, `approved`, `auto-ok`,
   `owner-answer`, `agent:review`, `unblock:1` (derived from author and comments instead).
7. **Cleaner.** A weekly role removes code, workflows, rules and text nobody needs, one small commit per removal,
   each with proof (references, `make check`) that nothing is lost.
8. **Quiet.** Agents and scripts comment only when a later step or a person needs the text.

## Still needs a person
- The release PR (by design).
- A PR that changes a CODEOWNERS path (the trust boundary itself): GitHub requires the code owner's review. Agents
  cannot grant themselves more trust; such PRs are rare and the agents never start one for an intake slip.
- Secrets, app installation and the ruleset when a project is set up (once).
