{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Storage backends. A backend stores rows and exposes a read-value lane;
-- it knows nothing about latency contracts, clients or arbitration. Those
-- belong to 'Substrate.Sub3.Memory.Port.memoryPort' and
-- 'Substrate.Sub3.Memory.Router.sharedPortRouter'.
--
-- This increment ships only 'registerStorage'. The other backends are
-- specified in docs/increments.md and do not exist yet, on purpose: nothing
-- in this repository is a stub.
--
--   * blockRamStorage        (increment I2)
--   * replicatedReadStorage  (increment I3)
--   * bankedStorage          (increment I4)
module Substrate.Sub3.Memory.Backend
  ( registerStorage
  ) where

import Clash.Prelude

import Substrate.Sub3.Memory.Protocol

-- | Rows held in registers (flip-flops). Intended for the small, hot
-- memories: the depth-limited configuration blocks and the scalar region
-- file. In the old vocabulary this was the flop-file license.
--
-- Documented behavior (the backend's half of the contract; the port adds
-- the latency on top):
--
--   * The read lane is combinational over the CURRENT registered contents.
--     'memoryPort' registers it before anything outside sees it, so no
--     combinational path ever leaves the memory.
--   * A write accepted at clock t is visible to reads accepted at clock
--     t + 1 or later. A read accepted at the same clock as a write (which
--     the single request stream makes impossible anyway) would see the old
--     value.
--   * When the current request is not a read, the read lane carries row 0
--     as a deterministic don't-care. The port's acceptance tag decides
--     meaning; the lane value is never interpreted on those clocks. A
--     deterministic don't-care, not an undefined one, so simulation and
--     hardware can never disagree on bits that leak into a trace.
registerStorage
  :: forall depth row dom
   . (HiddenClockResetEnable dom, KnownNat depth, 1 <= depth, NFDataX row)
  => Vec depth row          -- ^ contents at reset (the activation walk will
                            --   later own re-initialization; see increments)
  -> Signal dom (Maybe (MemRequest depth row))
  -> Signal dom row         -- ^ combinational read lane
registerStorage initial request = readLane
  where
    contents :: Signal dom (Vec depth row)
    contents = register initial (applyWrite <$> contents <*> request)

    applyWrite held (Just (WriteRow i v)) = replace i v held
    applyWrite held _ = held

    readLane = lookupRow <$> contents <*> request

    lookupRow held (Just (ReadRow i)) = held !! i
    lookupRow held _ = held !! (0 :: Index depth)
{-# NOINLINE registerStorage #-}
