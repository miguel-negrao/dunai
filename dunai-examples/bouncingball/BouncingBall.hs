{-# LANGUAGE Arrows #-}
{-# LANGUAGE CPP    #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TupleSections #-}

-- #ifdef BEARRIVER
-- import FRP.BearRiver as Yampa
-- #else
-- import FRP.Yampa     as Yampa
-- #endif

import FRP.BearRiver as Yampa

import Control.Concurrent
import Graphics.UI.SDL            as SDL hiding (NoEvent, Event)
import Graphics.UI.SDL.Primitives as SDL
import Data.Functor.Identity (Identity)
import Debug.Trace (trace)
import Control.Monad.Trans.Reader

import Data.IORef
import FRP.Yampa

main :: IO ()
main = do
   SDL.init [InitEverything]
   SDL.setVideoMode 800 600 32 [SWSurface]
   reactimate (return ())
              (\_ -> return (0.01, Just ()))
              (\_ e -> render e >> return False)
              bouncingBall

throwEvent :: Monad m => Cell (ExceptT e m) (Event e) ()
throwEvent = proc e ->
  case e of
    Event e' -> throwC -< e'
    NoEvent -> returnA -< ()

bouncingBall :: Cell (ClockInfoT Identity) () (Double, Double)
bouncingBall = foreverE (100, 0) $ proc () -> do
  (p0, v0) <- arrM (const ask) -< ()
  (p,v)  <- liftCell $ liftCell $ fallingBall -< (p0, v0)
  bounce <- edge               -< (p <= 0 && v < 0)
  liftCell throwEvent -< bounce `tag` (p, -v) 
  returnA -< (p,v)

fallingBall :: Monad m => Cell
  (ClockInfoT m)
  (Double, Double)
  (Double, Double)
fallingBall = proc (p0, v0) -> do
  v <- integral -< (-99.8::Double)
  let v' = v + v0
  p <- integral -< v'
  returnA -< (p+p0, v')

render (p,_) = do
  screen <- SDL.getVideoSurface

  white <- SDL.mapRGB (SDL.surfaceGetPixelFormat screen) 0xFF 0xFF 0xFF
  SDL.fillRect screen Nothing white

  SDL.filledCircle screen 100 (600 - 100 - round p) 30 (Pixel 0xFF0000FF)

  SDL.flip screen

  threadDelay 1000
