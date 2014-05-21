module ProbList
( ProbList(..)
, equalProbs
, normalize
, getProb
, sumProbs
, nRepeats
) where

import Control.Applicative
import Control.Arrow
import Control.Monad
import Data.Ratio
import Data.List

newtype ProbList a = ProbList { getList :: [(a, Rational)] } deriving (Eq, Show)

instance Functor ProbList where
  fmap f (ProbList xs) = ProbList $ map (first f) xs

instance Monad ProbList where
  return x = ProbList [(x, 1)]
  m >>= f = ProbList $ let (ProbList xss) = fmap f m in concatMap mapper xss
    where mapper (ProbList xs, p) = map (second (*p)) xs
  fail _ = ProbList []

instance Applicative ProbList where
  pure = return
  (<*>) = ap

equalProbs :: [a] -> ProbList a
equalProbs xs = ProbList $ map (\x -> (x, 1 % genericLength xs)) xs

normalize :: ProbList a -> ProbList a
normalize pl = ProbList . map (second (/sumProbs pl)) . getList $ pl

getProb :: (a -> Bool) -> ProbList a -> Rational
getProb p = sum . map snd . filter (p . fst) . getList

sumProbs :: ProbList a -> Rational
sumProbs = getProb $ const True

nRepeats :: ProbList a -> Int -> ProbList [a]
nRepeats = flip replicateM
