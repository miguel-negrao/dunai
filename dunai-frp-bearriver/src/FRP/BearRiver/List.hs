{-# LANGUAGE ScopedTypeVariables #-}
-- | A ListSF is a signal function that produces additional information about
-- spawning and discarding SFs.
--
-- Each ListSF produces, apart from the normal output signal, two additional
-- outputs:
-- - A boolean signal indicating if it's still alive or not.
-- - A list of new SFs that have spawned at that point.
module FRP.BearRiver.List
    ( ListSF (..)
    , dlSwitch
    )
  where

-- External imports
import LiveCoding.InternalCore (Cell (Cell, unMSF))

-- Internal imports
import FRP.BearRiver (SF)

-- | Signal function that produces additional information about spawning and
-- discarding SFs.
newtype ListCell (ClockInfoT m) a b = ListSF { listSF :: Cell (ClockInfoT m) a (b, Bool, [ ListCell (ClockInfoT m) a b ]) }

-- | Turn a list of ListSFs into a signal function that concatenates all the
-- outputs produced by each inner ListSF, at each point, and spawns and
-- discards ListSFs as indicated by themselves.
dlSwitch :: Monad m
         => [ ListCell (ClockInfoT m) a b ] -> Cell (ClockInfoT m) a [b]
dlSwitch = dlSwitch' . map listSF

-- | Turn a list of SFs that produce ListSFs into a signal function that
-- concatenates all the outputs produced by each inner ListSF, at each point,
-- and spawns and discards ListSFs as indicated by the SFs themselves.
dlSwitch' :: forall m a b
          .  Monad m
          => [ Cell (ClockInfoT m) a (b, Bool, [ ListCell (ClockInfoT m) a b ]) ] -> Cell (ClockInfoT m) a [b]
dlSwitch' sfs = Cell $ \a -> do

  -- Results of applying the initial input to all the SFs inside the ListSF
  --
  -- The outputs contain the output values (bs) and the continuations (sfs),
  -- and are labeled 0 for the initial time step.
  bsfs0 <- mapM (\sf -> unMSF sf a) sfs

  -- Gather outputs produced by the SFs
  let bs = fmap (\((b, _dead, _newSFs), _) -> b) bsfs0

  -- Gather old continuations produced by the SF, filtering those that
  -- have not died.
  let notDead = filter (\((_b, dead, _newSFs), _contSF) -> not dead) bsfs0

      oldSFs :: [ Cell (ClockInfoT m) a (b, Bool, [ListCell (ClockInfoT m) a b]) ]
      oldSFs = map (\((_b, _dead, _newSFs), contSF) -> contSF) notDead

  -- Gather new SFs produced in this step. According to the Yampa
  -- implementation, the new SFs are initialized (i.e., they are ran with the
  -- current input to obtain the continuations. This is not strictly necessary
  -- in bearriver, but the semantics will differ if we do not do it.
  let contListSFs = concatMap (\((_b, _dead, newSFs), _contSF) -> newSFs) bsfs0
      contSFs     = map listSF contListSFs

  -- Run the new SFs (listSFs) with the current input to "initialize" them).
  -- We use snd to keep only the continuation and discard the output.
  newSFs <- fmap snd <$> mapM (\sf -> (unMSF sf a)) contSFs

  -- Only here to indicate the type of nsfs.
  let constraintNSFs :: [ Cell (ClockInfoT m) a (b, Bool, [ListCell (ClockInfoT m) a b]) ]
      constraintNSFs = newSFs

  -- Put old and new continuation together for future steps
  let cts :: [ Cell (ClockInfoT m) a (b, Bool, [ListCell (ClockInfoT m) a b]) ]
      cts = oldSFs ++ newSFs

  return (bs, dlSwitch' cts)
