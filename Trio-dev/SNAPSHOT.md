# Trio-dev snapshot

This directory is a **flattened snapshot**, not a git submodule. It was vendored
into this repository so that the shadow-execution artifact is self-contained and
clonable without credentials.

## Provenance

Snapshot of `kingst/Trio-dev` at commit `a2abe07b00e08af1c665a443cb25d6d6684be50a`
(branch `oref-swift-output-compare`).

That branch is upstream `nightscout/Trio-dev` branch `oref-swift` at commit
`57c5c5572` (2026-02-12) plus three commits specific to this paper:

| commit | change |
| --- | --- |
| `a6ded5dd0` | Replace the JS test bundles with the buggy JS + replay support |
| `03228c386` | Add the Swift-vs-JS output comparison test suites |
| `a2abe07b0` | Rebuild the bundles from `trio-oref` branch `dev-replay-support` |

The added files are:

- `TrioTests/OpenAPSSwiftTests/{Iob,Meal,Autosens,DetermineBasal}OutputCompareTests.swift`
- `TrioTests/OpenAPSSwiftTests/utils/OutputCompareUtils.swift`
- rebuilt bundles under `TrioTests/OpenAPSSwiftTests/javascript/bundle/`

Note that the bundles deliberately **revert** the numeric-precision fixes made
upstream in PRs #619 and #623: reproducing the recorded field inconsistencies
requires the original buggy JS.

Upstream `nightscout/Trio-dev` later removed the whole replay harness in commit
`1644e6a98` ("Delete replay tests and code", 2026-04-19), so this snapshot is the
only place it survives.

## Nested dependencies

The Swift package dependencies were themselves submodules and are also flattened
here, pinned at these commits:

| directory | commit | upstream |
| --- | --- | --- |
| `LoopKit` | `edd4e6037` | https://github.com/loopandlearn/LoopKit |
| `CGMBLEKit` | `a442ea0a2` | https://github.com/loopandlearn/CGMBLEKit |
| `dexcom-share-client-swift` | `82a9179d4` | https://github.com/loopandlearn/dexcom-share-client-swift |
| `RileyLinkKit` | `83b211a44` | https://github.com/loopandlearn/RileyLinkKit |
| `OmniBLE` | `ffec85de2` | https://github.com/loopandlearn/OmniBLE |
| `G7SensorKit` | `ee064ddcc` | https://github.com/loopandlearn/G7SensorKit |
| `OmniKit` | `64731f0b3` | https://github.com/loopandlearn/OmniKit |
| `MinimedKit` | `d52c0f8f1` | https://github.com/loopandlearn/MinimedKit |
| `LibreTransmitter` | `38cc483f3` | https://github.com/loopandlearn/LibreTransmitter |
| `TidepoolService` | `b4fb9a067` | https://github.com/loopandlearn/TidepoolService |
| `DanaKit` | `bad8fad9c` | https://github.com/loopandlearn/DanaKit |

All were tracked on their `trio` branches.

## Licensing

Trio is MIT licensed (see `LICENSE.txt`, Copyright (c) 2021 Ivan Valkou). Each
vendored dependency retains its own `LICENSE` file in its directory.
