# Balance tolerances M1-4 (part 2)

Owner decision (issue #35): the measured values in [report.md](report.md) are accepted as they are, Config values are unchanged.
The status in the report and the check in `tests/test_balance_report.py` (run by `make check`) compare the median of each figure with the "New" range.

- Seven rows were out of the Bauplan tolerance (Z1, Z2, Z3, Z5, Z6, Z7, Z10). All their figures get the new range.
- New range = lowest run minus 1, rounded down; highest run plus 1, rounded up (counts of stages: not below 1).
- Rows in target keep the Bauplan tolerance (Z4, Z8, Z9). Z11 is not measured.
- Z5 occasional bot: not reached within the 6 h cap, so no figure is checked for it.

| Nr | Figure | Bauplan (old) | New (check) | Reason |
| --- | --- | --- | --- | --- |
| Z1 | first expansion, optimal bot | median 22-27, all runs 18-34 | 15 to 22 | runs 16.1-20.4 min, outside Bauplan |
| Z2 | first expansion, occasional bot | median 26-32 | 39 to 50 | runs 40.5-48.5 min, outside Bauplan |
| Z3 | stage 2 | median 12-25 | 12 to 19 | runs 13.2-17.5 min; row out of target |
| Z3 | stage 3 | median 12-25 | 9 to 16 | runs 10.2-14.5 min; row out of target |
| Z3 | stage 4 | median 12-25 | 9 to 17 | runs 10.1-15.1 min; median 11.6 below 12 |
| Z3 | stage 5 | median 12-25 | 10 to 18 | runs 11.0-16.1 min; row out of target |
| Z3 | stage 6 | median 12-25 | 15 to 23 | runs 16.4-22.0 min; row out of target |
| Z4 | stage 7 | median at most 60 | 0 to 60 | in target, Bauplan kept |
| Z4 | stage 8 | median at most 150 | 0 to 150 | in target, Bauplan kept |
| Z5 | play time until stage 6, optimal bot | 100-130 | 82 to 98 | runs 83.4-96.1 min, outside Bauplan |
| Z6 | storage gain stage 1 | +8-12 % | 10 to 20 | runs 11.0-18.7 %, outside Bauplan |
| Z6 | storage gain stage 4 | +40-50 % | 34 to 43 | runs 35.5-41.2 %, outside Bauplan |
| Z7 | storage gain, solar only | +60-70 % | 77 to 80 | all runs 78.3 %, outside Bauplan |
| Z7 | storage gain, wind and water | +15-25 % | 27 to 30 | all runs 28.6 %, outside Bauplan |
| Z8 | night start against morning | at most +25 % | -100 to 25 | in target, Bauplan kept (no lower limit) |
| Z9 | longest pause, first 10 min | at most 45 s | 0 to 45 | in target, Bauplan kept |
| Z10 | stage after day 1, optimal bot | stage 4-5 | 4 to 7 | runs 5.0-6.0; median 5.0 was in target, widened with the row |
| Z10 | stage after day 1, occasional bot | stage 4-5 | 1 to 2 | stage 1 in all 9 runs, outside Bauplan |
