{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NoImplicitPrelude #-}

-- | The one request and response vocabulary every memory in the machine
-- speaks. Nothing here has behavior; these are the words of the contract
-- that "docs/memory-toolkit.md" states in prose.
--
-- The contract, in one line each:
--
--   * A request offered on a clock is either accepted that clock or it is
--     not. Acceptance is explicit (the router reports it); it is never
--     implied by the latency promise.
--   * A request accepted at clock t is answered at exactly clock t + l,
--     where l is the port's declared latency. Never earlier, never later.
--   * 'ResponseIdle' at clock t means: nothing was accepted at clock t - l.
module Substrate.Sub3.Memory.Protocol
  ( MemRequest (..)
  , MemResponse (..)
  , Accepted (..)
  ) where

import Clash.Prelude

-- | One request to one memory of @depth@ rows of type @row@. The address is
-- an 'Index', so an out-of-range address is unrepresentable by construction;
-- range checking happened when the artifact was decoded, not here.
data MemRequest depth row
  = ReadRow (Index depth)
  | WriteRow (Index depth) row
  deriving (Generic, NFDataX, Eq, Show)

-- | The answer, exactly l clocks after acceptance.
data MemResponse row
  = ResponseIdle          -- ^ nothing was accepted l clocks ago
  | ReadValue row         -- ^ the row a 'ReadRow' asked for
  | WriteDone             -- ^ a 'WriteRow' landed
  deriving (Generic, NFDataX, Eq, Show)

-- | What the port accepted on a given clock. Internal to 'memoryPort', but
-- exported so tests and probes can speak about acceptance directly.
data Accepted
  = AcceptedNone
  | AcceptedRead
  | AcceptedWrite
  deriving (Generic, NFDataX, Eq, Show)
