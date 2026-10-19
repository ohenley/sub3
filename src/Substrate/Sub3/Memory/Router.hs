{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Shared access to one memory port, built once.
--
-- Two separate jobs live here, and keeping them separate is the design:
--
--   * SELECTION is combinational and stateless: a fixed priority order over
--     the client vector (position 0 wins every tie). No rotation, no
--     history, because a history-dependent grant would be a reordering the
--     plan never priced.
--   * RESPONSE ROUTING is registered: the winner's identity travels down a
--     delay chain beside the memory operation, so the answer arriving l
--     clocks later is returned to the client that asked. Remembering the
--     owner is bookkeeping the fixed latency makes exact; it is not
--     arbitration state.
--
-- Contention. The hardware selects a winner; it never queues, retries or
-- reschedules a loser. The planner made required requests collision-free
-- (phase disjointness, or distinct clocks inside a phase), so the router
-- only REPORTS simultaneity through 'contested'. Each memory's owner
-- declares which simultaneous patterns are permitted; a forbidden pattern
-- is a plan violation and the owner wires it to the machine-failure latch
-- (increment I7). Selecting a winner does not make a lost required request
-- correct; reporting is the router's whole duty there.
module Substrate.Sub3.Memory.Router
  ( sharedPortRouter
  , sharedMemory
  ) where

import Clash.Prelude

import Substrate.Sub3.Memory.Delay
import Substrate.Sub3.Memory.Port
import Substrate.Sub3.Memory.Protocol

-- | Route up to @n@ clients (priority = vector position, 0 highest) onto one
-- request stream, and route each answer back to its owner.
--
-- Returns, in order: the granted request stream (to 'memoryPort'), the
-- per-client response streams, the per-client accepted-this-clock flags,
-- and the contested flag (more than one client requested this clock).
--
-- Capacity note: the contested counter is 8 bits wide; the tile never has
-- more than a handful of clients on one port.
sharedPortRouter
  :: forall n l depth row dom
   . ( HiddenClockResetEnable dom
     , KnownNat n, 1 <= n
     , KnownNat l, 1 <= l
     , NFDataX row
     )
  => SNat l                 -- ^ the port's declared latency (owner routing depth)
  -> Vec n (Signal dom (Maybe (MemRequest depth row)))
                            -- ^ clients, priority order, position 0 wins
  -> Signal dom (MemResponse row)
                            -- ^ the one response stream from 'memoryPort'
  -> ( Signal dom (Maybe (MemRequest depth row))
     , Vec n (Signal dom (MemResponse row))
     , Vec n (Signal dom Bool)
     , Signal dom Bool
     )
sharedPortRouter l clients response = (granted, routed, acceptedFlags, contested)
  where
    requests :: Signal dom (Vec n (Maybe (MemRequest depth row)))
    requests = bundle clients

    -- SELECTION: combinational, fixed priority by position.
    winner :: Signal dom (Maybe (Index n))
    winner = findIndex isJust <$> requests

    granted = pick <$> requests <*> winner
    pick held (Just i) = held !! i
    pick _    Nothing  = Nothing

    -- RESPONSE ROUTING: the owner tag delayed beside the operation.
    ownerAtL :: Signal dom (Maybe (Index n))
    ownerAtL = delayCycles l Nothing winner

    routed = map
      (\i -> mux ((== Just i) <$> ownerAtL) response (pure ResponseIdle))
      indicesI

    acceptedFlags = map (\i -> (== Just i) <$> winner) indicesI

    -- REPORTING: simultaneity is the plan's business; we only observe it.
    contested = ((> (1 :: Unsigned 8)) . countRequests) <$> requests
    countRequests = foldl (\c m -> if isJust m then c + 1 else c) 0
{-# NOINLINE sharedPortRouter #-}

-- | The composition a memory owner instantiates: backend behind port behind
-- router. One declaration per memory: latency, idle row, backend, clients.
sharedMemory
  :: forall n l depth row dom
   . ( HiddenClockResetEnable dom
     , KnownNat n, 1 <= n
     , KnownNat l, 1 <= l
     , NFDataX row
     )
  => SNat l
  -> row
  -> (Signal dom (Maybe (MemRequest depth row)) -> Signal dom row)
  -> Vec n (Signal dom (Maybe (MemRequest depth row)))
  -> ( Vec n (Signal dom (MemResponse row))
     , Vec n (Signal dom Bool)
     , Signal dom Bool
     )
sharedMemory l idleRow backend clients = (routed, acceptedFlags, contested)
  where
    (granted, routed, acceptedFlags, contested) =
      sharedPortRouter l clients response
    response = memoryPort l idleRow backend granted
