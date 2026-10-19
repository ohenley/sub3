{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The client's half: a capture fires on exactly the clock the answer is
-- due, and the holding station keeps it from the next clock until the next
-- issue.
module CaptureSpec (spec) where

import Clash.Prelude
import qualified Prelude as P
import Test.Hspec

import Harness
import Substrate.Sub3.Memory.Backend
import Substrate.Sub3.Memory.Capture
import Substrate.Sub3.Memory.Port
import Substrate.Sub3.Memory.Protocol

type Row = Unsigned 8
type Req = MemRequest 8 Row

contents :: Vec 8 Row
contents = iterateI (+ 1) 100

-- One client wired straight to its own port: the input is the request, the
-- issued flag is its presence, and both capture flavors are observed.
captureCircuit :: HiddenClockResetEnable System
               => Signal System (Maybe Req)
               -> Signal System (Maybe Row, Maybe Row)
captureCircuit request = bundle (pulse, held)
  where
    response = memoryPort (SNat @2) 0 (registerStorage contents) request
    issued   = isJust <$> request
    pulse    = responseCapture (SNat @2) issued response
    held     = heldCapture (SNat @2) issued response

run :: [Maybe Req] -> [(Maybe Row, Maybe Row)]
run = runWithInputs captureCircuit Nothing

idle :: Int -> [Maybe Req]
idle n = P.replicate n Nothing

spec :: Spec
spec = describe "responseCapture and heldCapture, latency 2" $ do

  it "pulses Just on exactly issue + 2 and on no other clock" $ do
    let inputs = idle 1 P.++ [Just (ReadRow 4)] P.++ idle 4
        pulses = P.map fst (run inputs)
    pulses `shouldBe`
      [ Nothing, Nothing, Nothing
      , Just 104                      -- issue index 1, capture index 3
      , Nothing, Nothing ]

  it "holds the value from the clock after capture until the next issue" $ do
    let inputs = [Just (ReadRow 4)] P.++ idle 3 P.++ [Just (ReadRow 6)] P.++ idle 3
        holds  = P.map snd (run inputs)
    holds `shouldBe`
      [ Nothing, Nothing              -- in flight
      , Nothing                       -- capture clock itself (pulse, not yet held)
      , Just 104                      -- held from the next clock
      , Just 104                      -- still held on the re-issue clock itself
      , Nothing                       -- the index 4 issue clears from index 5
      , Nothing                       -- second capture lands here as a pulse
      , Just 106 ]                    -- and is held from index 7
