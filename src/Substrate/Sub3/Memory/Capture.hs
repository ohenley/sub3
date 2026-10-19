{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The client's half of the timing contract. A client that had a read
-- accepted at clock t must take the answer at exactly clock t + l, because
-- the port will not hold it. 'responseCapture' is that discipline, built
-- once: the client asserts "my request was accepted this clock" and gets the
-- answer back exactly when it is due.
module Substrate.Sub3.Memory.Capture
  ( responseCapture
  , heldCapture
  ) where

import Clash.Prelude

import Substrate.Sub3.Memory.Delay
import Substrate.Sub3.Memory.Protocol

-- | The exact-clock pulse. @Just row@ on precisely the clock the client's
-- read answer lands; @Nothing@ on every other clock, including the clocks
-- where the same port is answering some other client.
responseCapture
  :: forall l row dom
   . (HiddenClockResetEnable dom, KnownNat l, 1 <= l)
  => SNat l                          -- ^ the port's declared latency
  -> Signal dom Bool                 -- ^ my request was accepted this clock
  -> Signal dom (MemResponse row)    -- ^ my response stream from the router
  -> Signal dom (Maybe row)
responseCapture l issued response = capture <$> due <*> response
  where
    due = delayCycles l False issued

    capture True (ReadValue v) = Just v
    capture _    _             = Nothing
{-# NOINLINE responseCapture #-}

-- | The holding station. The captured value becomes available on the clock
-- AFTER it lands and stays available until the client issues again (a new
-- issue clears the station that same clock, from the next clock onward).
-- If an issue and an arriving answer coincide, the new transaction wins and
-- the old answer is dropped; a client that still needed it should not have
-- issued yet, and the plan never schedules that collision.
heldCapture
  :: forall l row dom
   . (HiddenClockResetEnable dom, KnownNat l, 1 <= l, NFDataX row)
  => SNat l
  -> Signal dom Bool
  -> Signal dom (MemResponse row)
  -> Signal dom (Maybe row)
heldCapture l issued response = held
  where
    pulse = responseCapture l issued response
    held  = register Nothing (next <$> issued <*> pulse <*> held)

    next True  _        _ = Nothing
    next _     (Just v) _ = Just v
    next _     Nothing  h = h
{-# NOINLINE heldCapture #-}
