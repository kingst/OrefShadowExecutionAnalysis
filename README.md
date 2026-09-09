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