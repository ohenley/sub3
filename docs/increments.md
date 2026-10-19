# THE INCREMENT LADDER

One increment at a time, each with an acceptance you can hold in your hand.
No increment starts before the previous one's acceptance is green. Commits
are the schedule; this ladder is the shape, not a calendar.

Rule carried over from the September lessons: the human owns structure (this
ladder, the module boundaries, the contracts in docs/); an agent may be
handed one leaf at a time, against the written contract, and may not touch
structure. Nothing in src/ is ever a stub: a thing either exists and is
tested, or it exists only here as a specification.

## I0. The compile

Do: install GHC and cabal (ghcup), then build and test.

```
cabal update
cabal build
cabal test
```

Acceptance: `cabal test` green. One known calibration point exists: if the
whole suite fails uniformly shifted by exactly one sample, adjust
`resetPadCycles` in `test/Harness.hs` until DelaySpec passes (it exists to
pin that constant), and touch nothing else. Any other failure is a defect in
the seed; fix the seed, not the tests.

## I1. The synthesis smoke, and the counting discipline

Do: generate HDL for the demonstration top.

```
cabal run clash -- --vhdl src/Substrate/Sub3/Top.hs
```

If the clash runner is set up differently on your machine, invoke clash by
whatever route you normally use; the module is `Substrate.Sub3.Top`.

Then open the generated HDL, and run it through the vendor flow far enough to
get a utilization report.

Acceptance, read off the report and the netlist, never off the source:
- the register count is explainable by hand: 8 rows x 8 bits of contents,
  the l = 2 tag and data delay chains, the l = 2 owner routing chain, and
  nothing unexplained
- no RAM primitive was inferred (this backend is registers by declaration)
- no latch was inferred anywhere
- the component boundaries you expected are findable in the netlist

Write the expected-counts arithmetic as a comment block in Top.hs once it
checks out, so the next change to the toolkit has a baseline to diff against.

## I2. blockRamStorage

The design question to answer in writing BEFORE coding: a block RAM has an
intrinsic read latency of one clock, while `memoryPort` was built for
combinational-read backends and supplies the whole declared latency itself.
The decided direction: a memory's declared latency l splits into backend
cycles plus padding cycles, and the SPLIT IS A LITERAL IN THE MEMORY'S
DECLARATION (for a block RAM at l = 2: one backend cycle plus one padding
cycle, written as such). No type-level subtraction anywhere; the author
states both numbers and a comment equates their sum to the declared l. This
needs either a zero-capable delay or a port variant for registered backends;
choose, document the choice in memory-toolkit.md section 4, and extend
`delayCycles` or add alongside it, never by weakening its 1 <= n contract.

Acceptance: PortSpec properties replicated against blockRamStorage at l = 2,
plus one new property: the backend's documented write-read visibility
(block RAM read-during-write behavior is whatever you configure; document it
and test exactly that). Synthesis smoke shows exactly one RAM primitive.

## I3. replicatedReadStorage

Read replicas of one contents, for the hot configuration tables that several
units read in the same phase. Decide and document the write story first: in
the machine, these tables are written only during activation, so the simple
rule is "all replicas are written by the one installer port, reads are
replica-local, and no write is legal while RUNNING." The declaration states
the replica count; the synthesis report must show exactly that many storage
instances.

Acceptance: simultaneous reads on all replicas answer independently at l;
the report's instance count equals the declared replica count.

## I4. bankedStorage

Wide contents striped across independently accessed banks, one router per
bank. The declaration states the bank count and the stripe rule.

Acceptance: requests to distinct banks on the same clock are both served
(no contested); requests to the same bank contend exactly like a single
port; report shows exactly the declared number of RAM primitives.

## I5. The first real memory: PersistentState

The scalar region file in miniature (the machine map's PocketState, ledger
coordinate M23). Its declaration, per the toolkit contract section 5:

- row: one scalar region's stored form (start with `Unsigned 8`, widen later)
- capacity: the region count, a type parameter
- backend: registerStorage
- clients, priority order: CommitWalk > ReceiptRead > OperandRead
- permitted simultaneity: none; any contested clock is forbidden
- declared latency: 1

Build it as its own module (`Substrate.Sub3.World.PersistentState`) that
INSTANTIATES the toolkit and adds only meaning: who these clients are and
when the plan lets them speak. Wire `contested` out as a failure request
(the latch arrives in I7; until then it is an exported witness signal).

Acceptance: an integration spec driving the three clients through a
plausible phase pattern: operand reads during execution, a commit write, a
receipt read after; the commit is visible to the receipt read; a
deliberately forbidden collision raises the witness on exactly that clock.

## I6. The second real memory: WriteProposals

The proposal log in miniature (the machine map's SuggestionBox, ledger
coordinate M31). This one adds the first owner-level mechanism on top of
the toolkit: an append cursor. The toolkit stays ignorant of it; the owner
module turns "append this proposal" into `WriteRow cursor row` and advances
the cursor, exposes "proposal count this round", and provides the in-order
read-back walk that a future merge unit will drive. Clearing at round open
is a cursor reset, not a contents wipe.

Acceptance: appends from two producer clients under their declared priority
land in configured order; the read-back walk returns exactly the appended
rows in order; overflow (append past capacity) raises a witness rather than
wrapping.

## I7. The failure latch

A one-way latch (`Substrate.Sub3.Failure`) with named witness inputs:
each memory's forbidden-collision wire, I6's overflow wire. Once set, it
stays set until reset.

Acceptance: any witness pulse latches; nothing unlatches it but reset; the
latch state is visible as an output of the demonstration top.

## I8. The activation walk

A walker that writes initial contents into PersistentState through its own
(highest-priority, HALTED-only) client port, one row per clock, then hands
the memory over. This is the SeedVault copy in miniature, and the first
piece of the lifecycle machine.

Acceptance: after the walk, reads return the initial image; the walk's
client port never requests once the walk reports done.

## Beyond I8

From here the ladder leaves the toolkit and starts the machine proper: the
Inbox ring with its arrival-before-pop priority law, the Sequencer as the
boundary order machine, and the first stutter boundary with a receipt. Each
of those gets its ladder entry written BEFORE its code, in this file, with
an acceptance in hand, same as above. The reference for what each piece must
become is the machine map and the memory atlas from the September sessions;
the reference for how to stage it is this file and nothing else.
