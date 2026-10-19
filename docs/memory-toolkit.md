# THE MEMORY-ACCESS TOOLKIT, THE CONTRACT

This document states, in prose, exactly what the code in
`src/Substrate/Sub3/Memory/` promises, and what it refuses to be. The test
suite in `test/` is the executable form of this document; each property below
names the spec file that pins it.

## 0. Notation

| glyph | spelled name | meaning |
| --- | --- | --- |
| `l` | declared latency | the number of clocks between acceptance and answer; exact, never a bound |
| `t` | a clock index | one rising edge |
| `row` | the row type | the kind of record one memory stores |
| `depth` | the row count | addresses are `Index depth`, so out of range is unrepresentable |
| `n` | client count | position 0 in the client vector is the highest priority |
| `A > B` | priority | fixed order; A wins every tie; the order never rotates |

## 1. The two promises, kept separate

A memory request involves two different questions, and this toolkit never
conflates them.

Question one: was my request accepted this clock? Acceptance is explicit. The
router reports, per client per clock, "you were accepted" or "you were not."
Nothing about the latency promise implies acceptance: a single port asked two
different things on the same clock does not grow a second port.

Question two: if accepted, when does the answer arrive? At exactly t + l.
Never earlier, never later, never data dependent. `ResponseIdle` at clock t
means precisely "nothing was accepted at clock t - l."

## 2. How contention is handled: selected, reported, never rescheduled

The planner, on the host, arranged access so that every required request is
served at its planned clock. It has two tools: put clients in different
execution phases so their requests never overlap, or schedule their requests
at different clocks within a phase.

The hardware therefore contains a fixed-priority selector and nothing more.
When several requests are present on one clock, it selects the
highest-priority one, and it raises `contested`. What it never does: queue the
loser, retry the loser, or reschedule anything. Selecting a winner does not
make a lost required request correct; if a simultaneous pattern violates the
accepted plan, that is a machine failure, and reporting it is the router's
whole duty.

Which simultaneous patterns are permitted is not the router's knowledge. It
is a per-memory declaration: each memory's owner states which client pairs
may ever collide (usually none), and wires forbidden collisions to the
machine-failure latch. The router supplies the raw `contested` observation;
the owner supplies the judgment. Increment I7 builds the latch.

## 3. Selection is stateless, routing is registered

Two different jobs, two different circuit shapes, and the distinction is the
design:

Selection: a combinational priority encoder over the current requests.
Stateless on purpose. A rotating or history-dependent grant would reorder
accesses in a way the plan never priced.

Response routing: the winner's identity travels down a register chain beside
the memory operation, so that the answer emerging l clocks later is delivered
to the client that asked. The worked example, with l = 2:

| clock | request selected | answer returned |
| --- | --- | --- |
| 10 | client A reads row 7 | nothing |
| 11 | client B reads row 3 | nothing |
| 12 | nothing | row 7's value goes to A |
| 13 | nothing | row 3's value goes to B |

At clock 12 the router must remember that the clock 10 request belonged to A.
That memory is registers, and it is bookkeeping the fixed latency makes
exact; it is not arbitration state. RouterSpec encodes this table literally.

## 4. The components and their responsibilities

| component | file | responsibility |
| --- | --- | --- |
| `MemRequest`, `MemResponse`, `Accepted` | Protocol.hs | the vocabulary; no behavior |
| `delayCycles` | Delay.hs | the one delay primitive every fixed latency is made of |
| `registerStorage` | Backend.hs | store rows in registers; combinational read lane; write visible to reads from the next clock |
| `memoryPort` | Port.hs | serve accepted requests with the declared response latency |
| `responseCapture` | Capture.hs | capture an answer on exactly the clock it is due |
| `heldCapture` | Capture.hs | hold a captured answer until the next issue |
| `sharedPortRouter` | Router.hs | select a request, remember its owner, return the answer to that owner, report contention |
| `sharedMemory` | Router.hs | the composition a memory owner instantiates: backend behind port behind router |

Backends specified but not yet built (see docs/increments.md): a block RAM
backend, a replicated-read backend for hot configuration tables, and a banked
backend for wide state. They will expose the same request and response
interface, and that shared interface does NOT make them interchangeable: each
backend documents its own timing and consistency behavior, and the memory's
declared latency must account for it. Replication in particular is
straightforward only for contents written during activation and read-only
afterwards; replicated writable storage needs a consistency rule it does not
yet have.

## 5. The boundary the toolkit will not cross

The toolkit owns ACCESS to storage: ports, latency, selection, routing,
reporting. The surrounding modules own the MEANING of the stored
information: what a proposal row is, how a fold law applies, when a predicate
runs. The moment this toolkit grows a parameter that encodes what kind of
table it is serving, it has become a framework, and that is the failure mode
this whole rebuild exists to avoid. Concretely: no handler execution, no
proposal merging, no candidate validation, no row semantics, ever, in this
directory.

A memory's implementation is therefore a declaration plus meaning:

- its row type and capacity
- its storage backend
- its named client ports
- its priority order
- which simultaneous requests are permitted
- its declared latency

and the toolkit supplies selection, routing and timing, while the memory's
own module explains what its rows mean and who writes them when.

## 6. The properties, and where each is pinned

| property | spec |
| --- | --- |
| a delayed value emerges after exactly n clocks, never fewer or more | DelaySpec |
| an accepted read answers at exactly t + l with the right row | PortSpec |
| an accepted write acknowledges at exactly t + l | PortSpec |
| a write is visible to reads accepted from t + 1 onward | PortSpec |
| idle clocks produce `ResponseIdle` l clocks later, nothing else | PortSpec |
| a capture fires on exactly the due clock, with the read value | CaptureSpec |
| a held capture is available from the next clock until the next issue | CaptureSpec |
| selection follows the declared priority order | RouterSpec |
| an answer returns to the client that asked, under interleaving | RouterSpec |
| simultaneous requests raise `contested` on that clock | RouterSpec |
| a quiet port is quiet for every client | RouterSpec |

## 7. What testing once buys, and what it does not

Every memory built from these components inherits the properties above by
construction. It does NOT inherit correctness: each concrete memory still
needs its own integration checks (correct wiring, correct backend choice,
correct declared latency against the plan, correct permitted-collision
declaration). Reusing a verified component moves the bug surface; it does not
remove it.

Likewise, the `NOINLINE` pragmas in the sources keep component boundaries
recognizable for inspection, and that is all they do. Physical RAM counts,
register counts and hierarchy are verified in the generated HDL and the
vendor synthesis reports, never inferred from source annotations. Increment
I1 is that verification, done once, early, on the demonstration top.
