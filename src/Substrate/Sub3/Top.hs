{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | A synthesizable demonstration top: the toolkit's two-client worked
-- example as hardware. Eight rows of 8-bit values in registers, two clients
-- behind one router at a declared latency of two clocks.
--
-- Purpose: run Clash on this module early (increment I1) and read the
-- generated HDL and the synthesis report. The boundaries NOINLINE keeps are
-- an inspection aid only; the netlist and the vendor report are the
-- authority on what was actually built, and the increment's acceptance is
-- written against those, never against source annotations.
module Substrate.Sub3.Top
  ( topEntity
  , demoContents
  ) where

import Clash.Prelude

import Substrate.Sub3.Memory.Backend
import Substrate.Sub3.Memory.Protocol
import Substrate.Sub3.Memory.Router

-- | Row i holds 100 + i, so every read answer names its address.
demoContents :: Vec 8 (Unsigned 8)
demoContents = iterateI (+ 1) 100

topEntity
  :: Clock System
  -> Reset System
  -> Enable System
  -> Signal System (Maybe (MemRequest 8 (Unsigned 8)))   -- ^ client A, priority 0
  -> Signal System (Maybe (MemRequest 8 (Unsigned 8)))   -- ^ client B, priority 1
  -> Signal System (Vec 2 (MemResponse (Unsigned 8)), Vec 2 Bool, Bool)
topEntity clk rst en clientA clientB =
  exposeClockResetEnable circuit clk rst en
  where
    circuit :: HiddenClockResetEnable System
            => Signal System (Vec 2 (MemResponse (Unsigned 8)), Vec 2 Bool, Bool)
    circuit = bundle (bundle routed, bundle accepted, contested)
      where
        (routed, accepted, contested) =
          sharedMemory (SNat @2) 0 (registerStorage demoContents)
            (clientA :> clientB :> Nil)
{-# ANN topEntity
  (Synthesize
    { t_name = "demo_shared_memory"
    , t_inputs =
        [ PortName "clk"
        , PortName "rst"
        , PortName "en"
        , PortName "client_a"
        , PortName "client_b"
        ]
    , t_output = PortName "out"
    }) #-}
{-# NOINLINE topEntity #-}
