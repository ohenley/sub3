{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The latency discipline, built once. 'memoryPort' turns a backend's
-- combinational read lane into the machine's timing contract:
--
--   a request accepted at clock t is answered at exactly clock t + l.
--
-- Both the acceptance tag and the data lane travel through the same
-- 'delayCycles' chain, so they cannot drift apart; the response is their
-- recombination l clocks later. Because @1 <= l@, there is never a
-- combinational path from a request to a response.
--
-- Scope note, stated here because it is a contract fact: this port serves
-- backends whose read lane is combinational ('registerStorage'). A backend
-- with intrinsic read latency of its own (block RAM, increment I2) splits
-- the total declared latency into backend cycles plus padding cycles; that
-- split is a per-memory declaration, decided by the memory's author with a
-- literal, never recovered by type arithmetic. docs/increments.md, I2,
-- carries the design note.
module Substrate.Sub3.Memory.Port
  ( memoryPort
  ) where

import Clash.Prelude

import Substrate.Sub3.Memory.Delay
import Substrate.Sub3.Memory.Protocol

-- | Serve one request stream against one backend at a declared latency.
memoryPort
  :: forall l depth row dom
   . (HiddenClockResetEnable dom, KnownNat l, 1 <= l, NFDataX row)
  => SNat l                 -- ^ the declared latency of this memory
  -> row                    -- ^ the data lane's reset and fill value (never
                            --   interpreted: 'ResponseIdle' gates it)
  -> (Signal dom (Maybe (MemRequest depth row)) -> Signal dom row)
                            -- ^ the backend's combinational read lane
  -> Signal dom (Maybe (MemRequest depth row))
  -> Signal dom (MemResponse row)
memoryPort l idleRow backend request = respond <$> acceptedAtL <*> dataAtL
  where
    accepted    = acceptanceOf <$> request
    acceptedAtL = delayCycles l AcceptedNone accepted
    dataAtL     = delayCycles l idleRow (backend request)

    acceptanceOf Nothing               = AcceptedNone
    acceptanceOf (Just (ReadRow _))    = AcceptedRead
    acceptanceOf (Just (WriteRow _ _)) = AcceptedWrite

    respond AcceptedNone  _ = ResponseIdle
    respond AcceptedRead  v = ReadValue v
    respond AcceptedWrite _ = WriteDone
{-# NOINLINE memoryPort #-}
