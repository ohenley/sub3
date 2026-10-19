{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | The router contract: fixed priority selection, registered ownership
-- routing, honest reporting of simultaneity. The first test is the worked
-- example from the toolkit contract document, encoded literally.
module RouterSpec (spec) where

import Clash.Prelude
import qualified Prelude as P
import Test.Hspec

import Harness
import Substrate.Sub3.Memory.Backend
import Substrate.Sub3.Memory.Protocol
import Substrate.Sub3.Memory.Router

type Row = Unsigned 8
type Req = MemRequest 8 Row
type Out = (MemResponse Row, MemResponse Row, Bool, Bool, Bool)
         -- (to client A, to client B, A accepted, B accepted, contested)

contents :: Vec 8 Row
contents = iterateI (+ 1) 100   -- row i holds 100 + i

routerCircuit :: HiddenClockResetEnable System
              => Signal System (Maybe Req, Maybe Req) -> Signal System Out
routerCircuit input = bundle (respA, respB, accA, accB, contested)
  where
    (reqA, reqB) = unbundle input
    (responses, accepted, contested) =
      sharedMemory (SNat @2) 0 (registerStorage contents)
        (reqA :> reqB :> Nil)
    respA = head responses
    respB = last responses
    accA  = head accepted
    accB  = last accepted

run :: [(Maybe Req, Maybe Req)] -> [Out]
run = runWithInputs routerCircuit (Nothing, Nothing)

quiet :: Int -> [(Maybe Req, Maybe Req)]
quiet n = P.replicate n (Nothing, Nothing)

spec :: Spec
spec = describe "sharedPortRouter over one port, two clients, latency 2" $ do

  it "routes interleaved answers to their owners (the contract document's table)" $ do
    -- Clock 0: A reads row 7. Clock 1: B reads row 3.
    -- Clock 2: row 7's value goes to A. Clock 3: row 3's value goes to B.
    let inputs =
          [ (Just (ReadRow 7), Nothing)
          , (Nothing, Just (ReadRow 3))
          ] P.++ quiet 3
    run inputs `shouldBe`
      [ (ResponseIdle, ResponseIdle, True,  False, False)
      , (ResponseIdle, ResponseIdle, False, True,  False)
      , (ReadValue 107, ResponseIdle, False, False, False)
      , (ResponseIdle, ReadValue 103, False, False, False)
      , (ResponseIdle, ResponseIdle, False, False, False) ]

  it "selects by fixed priority and reports the contested clock" $ do
    -- Both request on the same clock: A (position 0) wins, B is not served,
    -- contested is raised that clock. Whether that pattern was permitted is
    -- the owner's declaration, not the router's business.
    let inputs = [ (Just (ReadRow 1), Just (ReadRow 2)) ] P.++ quiet 3
    run inputs `shouldBe`
      [ (ResponseIdle, ResponseIdle, True, False, True)
      , (ResponseIdle, ResponseIdle, False, False, False)
      , (ReadValue 101, ResponseIdle, False, False, False)
      , (ResponseIdle, ResponseIdle, False, False, False) ]

  it "applies the same priority to writes, and the loser's request vanishes" $ do
    let inputs =
          [ (Just (WriteRow 2 9), Just (ReadRow 2))   -- A's write wins
          , (Nothing, Just (ReadRow 2))               -- B retries by plan, next clock
          ] P.++ quiet 3
    run inputs `shouldBe`
      [ (ResponseIdle, ResponseIdle, True,  False, True)
      , (ResponseIdle, ResponseIdle, False, True,  False)
      , (WriteDone,    ResponseIdle, False, False, False)
      , (ResponseIdle, ReadValue 9,  False, False, False)  -- B sees the new value
      , (ResponseIdle, ResponseIdle, False, False, False) ]

  it "stays idle for everyone when nobody asks" $ do
    let outputs = run (quiet 4)
    outputs `shouldBe` P.replicate 4
      (ResponseIdle, ResponseIdle, False, False, False)
