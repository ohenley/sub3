# sub3

The incremental, from-scratch rebuild of the Substrate tile, started
2026-10-19. One verified memory-access toolkit first; every concrete memory
as a declaration over it; the machine grown one increment at a time, each
with an acceptance in hand.

The package and namespace are `sub3` / `Substrate.Sub3`. Renaming later is
one search-and-replace; do not spend a minute on it now.

## What is in the seed

```
src/Substrate/Sub3/Memory/
  Protocol.hs    the request and response vocabulary (no behavior)
  Delay.hs       delayCycles, the one delay primitive
  Backend.hs     registerStorage (the only backend so far, on purpose)
  Port.hs        memoryPort, the latency discipline
  Capture.hs     responseCapture and heldCapture, the client discipline
  Router.hs      sharedPortRouter and sharedMemory, shared access
src/Substrate/Sub3/Top.hs
                 a synthesizable two-client demonstration
test/            the executable form of the toolkit contract
docs/memory-toolkit.md
                 the contract in prose; the tests pin it property by property
docs/increments.md
                 the ladder: what gets built next, and what "done" means
```

The vocabulary, fixed:

| name | responsibility |
| --- | --- |
| `memoryPort` | serve accepted requests with the declared response latency |
| `responseCapture` | capture an answer on exactly the clock it is due |
| `heldCapture` | hold a captured answer until the next issue |
| `sharedPortRouter` | select a request, remember its owner, return the answer to that owner, report contention |
| `sharedMemory` | the composition a memory owner instantiates |
| `registerStorage` | rows in registers |
| `blockRamStorage` | rows in block RAM (increment I2, specified, not built) |
| `replicatedReadStorage` | extra read access via copies (increment I3, specified, not built) |
| `bankedStorage` | rows striped across banks (increment I4, specified, not built) |

## The rules of this repository

1. Nothing in `src/` is a stub. A component either exists with its tests, or
   it exists only in `docs/increments.md` as a specification.
2. The toolkit owns access to storage; the surrounding modules own the
   meaning of the stored information. The keep-out list is in
   docs/memory-toolkit.md, section 5.
3. Names in code, coordinates in ledgers. Modules and signals carry meaning
   names (`PersistentState`, `WriteProposals`); the September memory atlas's
   names and ledger coordinates (PocketState, M23; SuggestionBox, M31)
   appear once, in the module's haddock header, as cross-references.
4. The human owns structure: this README, the docs, module boundaries, the
   ladder. An agent may be handed one leaf increment, against the written
   contract, and may not touch structure.
5. Source annotations are inspection aids. Register counts, RAM counts and
   hierarchy are verified in generated HDL and vendor synthesis reports,
   never inferred from pragmas.
6. Every fixed latency in the design goes through `delayCycles`. If a delay
   exists that is not this component, that is a review finding.

## Quick start

Install the toolchain if you do not have it (GHC 9.6 or newer and cabal,
via ghcup). Then:

```
cabal update
cabal build
cabal test
```

Expected: all specs green. There is exactly one sanctioned calibration: if
every test fails uniformly shifted by one sample, adjust `resetPadCycles` in
`test/Harness.hs` until `DelaySpec` passes (that spec exists to pin the
constant), and change nothing else. Any other failure is a seed defect.

To generate HDL from the demonstration top (increment I1):

```
cabal run clash -- --vhdl src/Substrate/Sub3/Top.hs
```

## Honesty block

This seed was written against the clash-prelude 1.8 API, mirroring the
pragma and deriving conventions of the existing sub2 sources, and it has NOT
been compiled by its author's tooling (the authoring environment could not
reach the Haskell toolchain). That is why increment I0 of the ladder is the
compile itself, and why the test suite is the first thing to run: the
contract document and the specs are the ground truth, and any compile error
is mechanical to fix against them. The one anticipated environmental
difference, the simulator's reset convention, has a single named calibration
point and a spec dedicated to catching it.

## Where the architecture lives

This repository deliberately contains no architecture prose beyond its own
contracts. The machine map, the 46-memory atlas, the quantum walk, the
artifact formats and the fixture coverage analysis live in the September
session documents (machine-map.md, adr1-memory-atlas.md,
substrate-tutorial.md). This repo's docs reference them by memory name and
ledger coordinate, and otherwise stand alone.
