module FRP.Yampa (module X, SF, FutureSF) where

import           FRP.BearRiver         as X hiding (andThen, SF)
import           Data.Functor.Identity
import qualified FRP.BearRiver         as BR
import LiveCoding (Cell(..))

type SF       = Cell (ClockInfoT Identity)
type FutureSF = Cell (ClockInfoT Identity)
