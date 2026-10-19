{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Pins the harness convention and the delay primitive. If this spec
-- fails uniformly shifted by one, recalibrate 'Harness.resetPadCycles'
-- before touching anything else.
module DelaySpec (spec) where

import Clash.Prelude
import qualified Prelude as P
import Test.Hspec

import Harness
import Substrate.Sub3.Memory.Delay

delay3 :: HiddenClockResetEnable System
       => Signal System (Unsigned 8) -> Signal System (Unsigned 8)
delay3 = delayCycles (SNat @3) 0

spec :: Spec
spec = describe "delayCycles" $ do

  it "delays by exactly n clocks, default before the pipeline fills" $ do
    let inputs  = [7, 8, 9, 0, 0, 0, 0] :: [Unsigned 8]
        outputs = runWithInputs delay3 0 inputs
    outputs `shouldBe` [0, 0, 0, 7, 8, 9, 0]

  it "never shortens or stretches: a pulse at k lands at k + n and nowhere else" $ do
    let inputs  = P.replicate 4 0 P.++ [42] P.++ P.replicate 5 0 :: [Unsigned 8]
        outputs = runWithInputs delay3 0 inputs
    outputs `shouldBe` (P.replicate 7 0 P.++ [42] P.++ P.replicate 2 0)
