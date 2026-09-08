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
