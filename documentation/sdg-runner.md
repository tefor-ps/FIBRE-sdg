# SDG planner and runner

The secondary-data generator separates discovery, decision-making, scheduling,
and execution. The split is intentional: a long-running plan can be controlled
without rediscovering inputs or reinterpreting a changed configuration.

## Components

| File | Responsibility |
| --- | --- |
| `sdg.sh` | Operator and cron entry point; obtains the run lock before planning. |
| `sdg-plan.sh` | Discovers images and series, evaluates configuration, and writes an immutable plan. |
| `sdg-run.sh` | Schedules plan jobs, limits concurrency, consumes controls, and records state/results. |
| `makeSecData.sh` | Executes exactly one planned image/series job under a per-job lock. |
| `makeCaller.sh` | Renders one unique Fiji caller from the job's recorded steps. |
| `fijiOnServer.sh` | Selects a graphical backend and isolates each job's Java temporary directory. |
| `writeMetadata.sh` | Extracts the metadata used for series and channel planning. |
| `sdg-common.sh` | Discovers `getVar.sh` and provides shared validation and parsing helpers. |

All runtime scripts load FSDB through `sdg-common.sh`. `getVar.sh` remains the
authoritative source for the compiled FSDB configuration and the shared
`fun_colMsg.sh` message functions. Set
`SDG_GETVAR=/absolute/path/getVar.sh` when automatic discovery would otherwise
find zero or multiple candidates.

## Common commands

```bash
sdg.sh run                         # discover, plan, and execute configured roots
sdg.sh run --jobs 4                # four image/series jobs at a time
sdg.sh process /data/image.czi     # plan and run one image
sdg.sh plan --directory /data/run  # create a plan without executing it
sdg.sh execute /path/plan.tsv      # execute an existing plan
sdg.sh status
```

`SDG_JOBS` defaults to `1`, preserving sequential operation on weak machines.
Increasing it is intended for hosts with enough CPU, memory, and I/O capacity.
Each image/series job has its own caller, lock, ownership record, and temporary
directory.

`sdg.sh run` is the intended cron command. The run-level `flock` is acquired
before image discovery and remains held through execution. Consequently, an
overlapping cron invocation exits without creating a redundant plan.

## Controls

| Command | Effect |
| --- | --- |
| `pause` | Stops launching jobs, lets active jobs finish, and retains unfinished work for `resume`. |
| `resume [--jobs N]` | Continues the paused plan. |
| `stop` | Lets active jobs finish and marks the remaining work discarded. |
| `cancel-current` | Sends `TERM` to active job process groups, then leaves the plan paused. |
| `priority IMAGE` | Creates a priority plan; the active runner takes it before ordinary queued jobs. |

A stopped plan remains on disk as an audit record but is not resumable through
`sdg.sh resume`. A canceled job is not marked complete and is therefore eligible
to run again after `resume`.

## Plan records

Plans are tab-separated and begin with `SDG_PLAN<TAB>1`. Tabs and newlines are
rejected inside fields so records remain unambiguous.

| Record | Fields after record name |
| --- | --- |
| `SDG_PLAN` | Format version. |
| `META` | Key, value. Includes plan ID, creation time, host, priority, configuration path, and final job count. |
| `JOB` | Job ID, source image, selected series, series count, channel count, group, caller path, output directory, output basename. |
| `STEP` | Job ID, sequence number, operation, macro path, macro argument. |
| `OUTPUT` | Job ID, one concrete expected-output path. |

Supported step operations are `APPLY`, `DIRECT`, `DERIVE`, `ANNOTATE`, and
`SAVE`. `makeCaller.sh` is the only component that translates these operations
into ImageJ macro statements.

The runner never edits a plan. It writes job outcomes to a neighboring
`.results.tsv` file and publishes current run information atomically through
`SDG_STATE_FILE`.

## Configuration

The existing toggle families remain authoritative. The planner reads variable
names from the human-readable module config and obtains their compiled values
from `getVar.sh`.

| Family | Meaning |
| --- | --- |
| `*_PPTOG`, `*_PPSUFF` | Pre-processing operations and suffixes. |
| `*_IMTOG` | Image manipulation operations. The final configured manipulation result is retained, matching legacy behavior. |
| `*_EXTOG`, `*_SUFF`, `*_FT` | Direct image exports and their expected output names. |
| `*_IPTOG`, `*_IPSUFF` | Processing variants applied before derived-data generation. |
| `*_SDTOG`, `*_SUFF`, `*_FT` | Derived secondary-data products. |
| `*_IATOG`, `*_IASUFF` | Annotation operations applied before saving. |
| `*_MAC` | Fiji macro used for the corresponding operation. |

New runner settings are `SDG_JOBS`, `SDG_INPUT_ROOTS`, the `SDG_GROUP_*`
variables, and the `SDG_*_DIR`/state/lock paths. `sdg.config.default` documents
each of them directly.

## Series groups

Filename substrings select group-specific series. Group order matters; place a
catch-all group last.

```text
SDG_GROUPS HCS DEFAULT
SDG_GROUP_HCS_MATCH _HCS_
SDG_GROUP_HCS_SERIES 1-3
SDG_GROUP_DEFAULT_MATCH ALL
SDG_GROUP_DEFAULT_SERIES all
```

Series specifications accept `all`, comma-separated numbers, and inclusive
ranges. Output and macro choices continue to come from `sdg.config` toggles,
suffixes, file types, and macro paths.

Each selected series becomes an independent job. For a multi-series source,
`.SeriesNN` is added to the output basename. A channel count is read for the
selected series, with the image-wide count used only as a fallback.

## Completion and retries

Before running Fiji, `makeSecData.sh` checks all `OUTPUT` records for its job.
If every output already exists, Fiji is skipped. After Fiji exits successfully,
the same list is checked again; missing files make the job fail. Multi-channel
NRRD exports list the actual `-C1`, `-C2`, … files, not an unsuffixed placeholder.

Only `DONE` results suppress a job on a later execution of the same plan.
Failed or gracefully canceled jobs can therefore be retried without modifying
the plan.

## ImageJ stub cleanup

Before workers start, the runner takes a dedicated cleanup lock, refuses cleanup
if any Fiji/ImageJ process is active, and removes stale `/tmp/ImageJ-*stub`
files. Each worker then uses its own Java temporary directory and removes only
its own stubs before and after Fiji. This makes concurrent SDG workers safe while
preserving the required global stale-stub cleanup at run startup.

Runtime scripts no longer install packages or run broad recursive `sudo chmod`.
Installation should provision dependencies and permissions. A future installer
change should optionally create a dedicated FSDB service account; that remains
deliberately bookmarked rather than implemented here.

## Verification

Run the regression test from the repository root:

```bash
bash tests/test-sdg-runner.sh
```

It uses fake external tools while exercising the real planner, caller renderer,
per-job executor, and runner. The test verifies two-series planning, two-worker
execution, unique callers, expected outputs, completed state, and that the plan
checksum does not change during execution.
