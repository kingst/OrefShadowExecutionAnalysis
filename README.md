# Shadow execution results reproduction

This repo contains code and instructions for reproducing the results
from shadow execution in our paper AID bugs.

## Data and preliminaries

To run the analysis, you need to have the logs. These logs are:

  - **trio-oref-logs/downloaded_files/** the raw device logs
    downloaded directly from GCP. Contains information about the
    execution of a function.

  - **trio-oref-logs/fixed_bug_inputs/** individual inputs pulled out
    of the raw logs. These inputs may or may not lead to an
    inconsistency (they did at some point in the past, which is how
    they got logged).

For now, compressed archives of these two logs are stored in Google
Drive at: https://drive.google.com/drive/folders/1BGV-vf6dgXLTBfF8ccfqosErUc7iM_KS
which is restricted to only being available to Thomas, Joe, and Sam.

And you need to set up a python virtual environment for the driver
that lives in `trio-oref-logs`:

```bash
$ cd trio-oref-logs
$ python3.10 -m venv venv
$ source venv/bin/activate
$ pip install --upgrade pip
$ pip install -r requirements.txt
```

And make sure we have all of the submodules:

```bash
$ git submodule update --init
$ cd Trio-dev
$ git submodule update --init
```

## Total comparisons

This stage calculates the total number of function invocations that we
recorded. It simply looks at all of the inputs from `fixed_bug_inputs`
to find the most recent date captured for inputs and then finds all of
the raw files from `downloaded_files` to count function invocations
overall.

```bash
$ python count_comparisons.py

... A bunch of outputs ...

Function                  Total
--------------------------------
meal                    194,042
autosens                 29,527
determineBasal          184,765
iob                     328,146
other                   667,681
--------------------------------
TOTAL                 1,404,161
```

Note: the `other` category is from the `Profile` function where we
didn't have any inconsistencies or fixed JS bugs. You can ignore
`other` and count the rest to reproduce the total number of function
invocations from the paper.

## Mismatches

To calculate mismatches we need to run all of the inputs against the
JS and Swift implementations using a unit test from the TrioTests
target in the Trio iOS app.

Running this will take a while...

```bash
$ cd trio-oref-logs
$ python run_tests_on_existing_errors.py \
   -t iob-compare \
   -d fixed_bug_inputs/iobInput \
   --derived-data ./DerivedData \
   --output-dir ./output_compare
$ python run_tests_on_existing_errors.py \
   -t meal-compare \
   -d fixed_bug_inputs/mealInput \
   --derived-data ./DerivedData \
   --output-dir ./output_compare
$ python run_tests_on_existing_errors.py \
   -t autosens-compare \
   -d fixed_bug_inputs/autosensInput \
   --derived-data ./DerivedData \
   --output-dir ./output_compare
$ python run_tests_on_existing_errors.py \
   -t determineBasal-compare \
   -d fixed_bug_inputs/determineBasalInput \
   --derived-data ./DerivedData \
   --output-dir ./output_compare
```

These jobs will output data in the `output_compare` directory that you
can analyze to reproduce the shadow execution mismatch table in the
paper:

```bash
$ python analyze_compare.py output_compare/output_compare_autosens.json
$ python analyze_compare.py output_compare/output_compare_meal.json
$ python analyze_compare.py output_compare/output_compare_iob.json
$ python analyze_compare.py output_compare/output_compare_determineBasal.json
```

You can use this same data to count semantically meaningful changes as well:

```bash
$ python analyze_semantic.py --autosens output_compare/output_compare_autosens.json
$ python analyze_semantic.py --iob output_compare/output_compare_iob.json
```
## Attributing differences to IoB bug fixes

The stage above tells us *how many* Swift/JS differences exceed the fuzzy-match
thresholds. This stage tells us *which* JavaScript bug caused each one, by
replaying the offending inputs against one bug fix at a time.

In `trio-oref`, each `iob-fix-N-*` branch is exactly one commit on a shared
parent that still has the buggy IoB code, and `dev-fixes-for-swift-comparison`
has all eight applied. Replaying under node is faithful because
`dev-replay-support` — the branch whose bundle is built into the TrioTests
target — is what produced the recorded `js*` values, so replaying it must
reproduce them exactly. That check is the gate on everything else here.

`determineBasal` is deliberately excluded: its logged input carries a
pre-computed `iob` array and `determine-basal.js` never calls `get_iob`, so both
implementations receive identical IoB and none of its differences can be caused
by these bugs.

You need node modules for trio-oref, and the fix branches fetched:

```bash
$ cd trio-oref
$ npm install
$ git fetch origin
```

Then, from `trio-oref-logs` with the virtual environment active:

```bash
# Convert the above-threshold inputs into the JSON shape Trio hands to
# JavaScriptCore (the logs store dates as epoch seconds; the JS wants ISO)
$ python iob_attribution/prepare_inputs.py

# Replay all of them against app-js, the baseline, each of the 8 fixes, and all-fixes.
# Creates git worktrees under iob_attribution/worktrees/ (~15 MB, a few minutes)
$ python iob_attribution/run_sweep.py

# Fidelity gate: replaying the app's own JS must reproduce the recorded js values
$ python iob_attribution/check_gate.py

$ python iob_attribution/analyze_attribution.py
```

`check_gate.py` must report PASS for all three functions:

```
iob: PASS -- 1420 replayed, 0 errors, 0 field mismatches vs recorded JS
autosens: PASS -- 360 replayed, 0 errors, 0 field mismatches vs recorded JS
meal: PASS -- 17 replayed, 0 errors, 0 field mismatches vs recorded JS
```

`analyze_attribution.py` then reproduces the attribution reported in the paper.
A difference counts as *resolved* by a variant when every field that originally
exceeded its threshold agrees with Swift within that threshold — the same
threshold `analyze_compare.py` uses to call something a mismatch:

| function | differences | resolved by fix 1 (`splitTimespan`) | resolved by all 8 |
|----------|------------:|------------------------------------:|------------------:|
| iob      | 1420        | 1416 (99.7%)                        | 1420 (100%)       |
| meal     | 17          | 17 (100%)                           | 17 (100%)         |
| autosens | 360         | 265 (73.6%)                         | 355 (98.6%)       |

For autosens the remaining differences spread across the other fixes, and fix 6
(the hard-coded 8-hour suspend duration) accounts for the largest individual
deltas — max 0.5000, the largest of any single fix:

| fix | autosens differences resolved | largest delta resolved |
|-----|------------------------------:|-----------------------:|
| fix1 `splitTimespan` flag              | 265 | 0.1400 |
| fix6 hard-coded 8h suspend duration    |  49 | 0.5000 |
| fix7 wrong timestamp for basal lookup  |  43 | 0.0800 |
| fix8 float imprecision                 |  17 | 0.0800 |

The leftovers are reported rather than hidden. For iob, 4 of 1420 are resolved
by fix 7 instead of fix 1. For autosens, 11 are not resolved by any single fix:
6 need two or more fixes together, and 5 stay above threshold even with all
eight — those are genuine Swift/JS differences that the IoB bugs do not explain.

