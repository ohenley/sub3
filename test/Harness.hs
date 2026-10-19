{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The one simulation harness every spec uses, so every spec shares one
-- timing convention.
--
-- CONVENTION. @runWithInputs circuit idle inputs@ returns one output sample
-- per payload input, aligned so that:
--
--   a request placed at payload index k is accepted at payload index k, and
--   its answer appears at payload index k + l.
--
-- CALIBRATION POINT, the one in this repository. Clash's 'resetGen' for the
-- System domain asserts reset for the first cycle, so the harness prepends
-- 'resetPadCycles' idle inputs and drops the same number of output samples.
-- If the whole suite ever fails uniformly shifted by exactly one sample,
-- the local clash-prelude's reset convention differs from the one assumed
-- here: adjust 'resetPadCycles' (0, 1 or 2) until DelaySpec passes, and
-- touch nothing else. DelaySpec exists to pin this constant; every other
-- spec inherits it.
module Harness
  ( runWithInputs
  , resetPadCycles
  ) where

import Clash.Prelude
import qualified Prelude as P

resetPadCycles :: Int
resetPadCycles = 1

runWithInputs
  :: forall i o
   . (NFDataX i, NFDataX o)
  => (HiddenClockResetEnable System => Signal System i -> Signal System o)
  -> i                 -- ^ the idle input, used for reset padding and tail
  -> [i]               -- ^ the payload inputs, one per clock
  -> [o]               -- ^ one output per payload input, aligned (see above)
runWithInputs circuit idle inputs =
  P.drop resetPadCycles
    (sampleN
       (resetPadCycles P.+ P.length inputs)
       (circuit (fromList (P.replicate resetPadCycles idle
                           P.++ inputs
                           P.++ P.repeat idle))))
