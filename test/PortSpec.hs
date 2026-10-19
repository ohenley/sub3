{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The port contract: an accepted request is answered at exactly
-- acceptance + l; idle clocks answer 'ResponseIdle' l clocks later; a write
-- is visible to reads accepted from the next clock onward.
module PortSpec (spec) where

import Clash.Prelude
import qualified Prelude as P
import Test.Hspec

import Harness
import Substrate.Sub3.Memory.Backend
import Substrate.Sub3.Memory.Port
import Substrate.Sub3.Memory.Protocol

type Row = Unsigned 8
type Req = MemRequest 8 Row

contents :: Vec 8 Row
contents = iterateI (+ 1) 100   -- row i holds 100 + i

portL2 :: HiddenClockResetEnable System
       => Signal System (Maybe Req) -> Signal System (MemResponse Row)
portL2 = memoryPort (SNat @2) 0 (registerStorage contents)

run :: [Maybe Req] -> [MemResponse Row]
run = runWithInputs portL2 Nothing

idle :: Int -> [Maybe Req]
idle n = P.replicate n Nothing

spec :: Spec
spec = describe "memoryPort over registerStorage, latency 2" $ do

  it "answers a read at exactly acceptance + 2, idle everywhere else" $ do
    let inputs = idle 2 P.++ [Just (ReadRow 3)] P.++ idle 4
    run inputs `shouldBe`
      [ ResponseIdle, ResponseIdle          -- idle inputs 0, 1
      , ResponseIdle, ResponseIdle          -- the read is in flight
      , ReadValue 103                       -- acceptance index 2, answer index 4
      , ResponseIdle, ResponseIdle ]

  it "acknowledges a write at exactly acceptance + 2" $ do
    let inputs = [Just (WriteRow 5 77)] P.++ idle 3
    run inputs `shouldBe`
      [ ResponseIdle, ResponseIdle
      , WriteDone
      , ResponseIdle ]

  it "makes a write visible to a read accepted on the very next clock" $ do
    let inputs =
          [ Just (WriteRow 3 55)     -- index 0: write
          , Just (ReadRow 3)         -- index 1: read the same row
          ] P.++ idle 3
    run inputs `shouldBe`
      [ ResponseIdle, ResponseIdle
      , WriteDone                    -- the write's answer, index 2
      , ReadValue 55                 -- the read's answer, index 3: new value
      , ResponseIdle ]

  it "keeps back-to-back requests independent: one answer per acceptance, in order" $ do
    let inputs =
          [ Just (ReadRow 0)
          , Just (ReadRow 1)
          , Just (ReadRow 2)
          ] P.++ idle 3
    run inputs `shouldBe`
      [ ResponseIdle, ResponseIdle
      , ReadValue 100
      , ReadValue 101
      , ReadValue 102
      , ResponseIdle ]
