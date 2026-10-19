module Main (main) where

import Test.Hspec

import qualified CaptureSpec
import qualified DelaySpec
import qualified PortSpec
import qualified RouterSpec

main :: IO ()
main = hspec $ do
  DelaySpec.spec      -- runs first: it pins the harness calibration
  PortSpec.spec
  CaptureSpec.spec
  RouterSpec.spec
