{-# LANGUAGE NoImplicitPrelude #-}

-- | The one delay primitive the toolkit is allowed to use. Every fixed
-- latency in the machine is this register chain and nothing else, so the
-- claim "a response arrives exactly l clocks after acceptance" reduces to
-- one proven component.
module Substrate.Sub3.Memory.Delay
  ( delayCycles
  ) where

import Clash.Prelude

-- | Delay a signal by exactly @n@ clocks (@1 <= n@). Before the pipeline
-- fills, the output is the supplied default.
--
-- Implementation: a @Vec n@ shift register. The output reads position 0;
-- each clock the vector shifts toward position 0 and the input enters at the
-- tail, so position 0 at clock t holds the input from clock t - n. There is
-- no bypass and no enable: the chain always shifts, so the delay cannot be
-- data dependent.
delayCycles
  :: forall n a dom
   . (HiddenClockResetEnable dom, KnownNat n, 1 <= n, NFDataX a)
  => SNat n
  -> a                     -- ^ value presented while the pipeline fills, and at reset
  -> Signal dom a
  -> Signal dom a
delayCycles SNat dflt input = (!! (0 :: Index n)) <$> buffer
  where
    buffer :: Signal dom (Vec n a)
    buffer = register (repeat dflt) ((<<+) <$> buffer <*> input)
{-# NOINLINE delayCycles #-}
