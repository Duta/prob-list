prob-list
=========

I did this one day when I was on a long coach ride with a laptop and no internet.

I've since found out that something **very** similar is covered in
[LYAH](http://learnyouahaskell.com/), which is a strange coincidence given that
I hadn't read that section at the time.

Because I think that it's cool regardless, it's now here on GitHub.

* * *

Motivation
----------

Haskell's monad instance for the list type provides a very easy way to introduce
non-determinism to our programs. However, it considers each possible result to
have an equal likelihood. This is adequate for some problems, however others
have inherent associated probabilities. To simplify these programs, I made a
monad to handle the probabilities' processing.

Type
----

Before going over the monad instance, let's look at the type introduced:

```haskell
newtype ProbList a = ProbList { getList :: [(a, rational)] }
```

A `newtype` wrapper is used for efficiency, and we simply represent
probabilistic lists as lists of tuples, where the first elements are the
possible values and the second elements the probabilities.

Functor Instance
----------------

First we make `ProbList` an instance of `Functor`, like so:

```haskell
instance Functor ProbList where
  fmap f (ProbList xs) = ProbList $ map (first f) xs
```

This gives us the ability to map over the values just like a normal list.

Monad Instance
--------------

Now, the special sauce. Here, we make `ProbList` an instance of `Monad`:

```haskell
instance Monad ProbList where
  return x = ProbList [(x, 1)]
  m >>= f = ProbList $ let (ProbList xss) = fmap f m in concatMap mapper xss
    where mapper (ProbList xs, p) = map (second (*p)) xs
  fail _ = ProbList []
```

Both `return` and `fail` are trivial and self-explanatory, though bind (`>>=`)
may need a little more explanation.

Bind `fmap`s the function over the list and then joins the resulting list.
Probabilities are joined through multiplication, as is usual in statistics.

Applicative Instance
--------------------

For the sake of completeness, we also provide it in the form of an applicative
functor, simply via the usual remapping from Monad to Applicative:

```haskell
instance Applicative ProbList where
  pure = return
  (<*>) = ap
```

Additional Functions
--------------------

A few helpful functions are provided:

```haskell
equalProbs :: [a] -> ProbList a 
normalize  :: ProbList a -> ProbList a 
getProb    :: (a -> Bool) -> ProbList a -> Rational 
sumProbs   :: ProbList a -> Rational 
nRepeats   :: ProbList a -> Int -> ProbList [a] 
```

`equalProbs` provides a simple way to model flat distributions, for example
a coin toss or the roll of a die.

`normalize` is used to ensure that the sum of the probabilities is equal to `.

`getProb` finds the sum of the probabilities for all elements that satisfy
the given predicate.

`sumProbs` returns the sum of the probabilities. The list should be normalized
if this doesn't equal 1.

`nRepeats` takes an event and repeats it `n` times, storing the results in
lists of length `n`.

* * *

Example - The Flip of a Coin
----------------------------

For the first example, we'll take a very simple situation - flipping an unbiased
coin. This doesn't require our monad, however we simulate it anyway to show
how simple we can make these situations (omitting type signatures for brevity):

```haskell
data CoinToss = Heads | Tails deriving (Show, Eq)

toss = equalProbs [Heads, Tails]
nTosses = nRepeats toss
```

Let's start querying the simulation. Very simply, what is the probability
of showing heads?:

```haskell
ghci> getProb (==Heads) toss
1 % 2
```

As we expected. We can also do a quick sanity check, making sure the sum of
the probabilities equals 1. Since we used equalProbs, this is guaranteed,
however it is worth checking if you supply custom probabilities:

```haskell
ghci> sumProbs toss
1 % 1
```

What's the probability of the third of five tosses being tails?: 

```haskell
ghci> getProb ((==Tails) . (!!2)) $ nTosses 5 
1 % 2 
```

The probability of at least 5 out of 7 tosses being heads?:

```haskell
ghci> getProb ((>=5) . length . filter (==Heads)) $ nTosses 7
29 % 128
```
What about all of them being heads?:

```haskell
ghci> getProbs (all (==Heads)) $ nTosses 7
1 % 128
```

What about all of them except the first?:

```haskell
ghci> getProbs (all (==Heads) . drop 1) $ nTosses 7
1 % 64
```

Although this is working with an unbiased coin (i.e. equal probabilities),
nothing needs to be changed except the toss function for everything to work
with unequal probabilities.

Example 2 - Unfair Dice
-----------------------

In this second example, we model dice with non-uniform probability distributions: 

```haskell
data DiceRoll = One | Two | Three | Four | Five | Six deriving (Show, Eq)

roll :: ProbList DiceRoll
roll = ProbList [(One, 1 % 20), (Two, 1 % 5), (Three, 1 % 10),
  (Four, 1 % 5), (Five, 1 % 10), (Six, 1 % 2)]

threeRolls :: ProbList (DiceRoll, DiceRoll, DiceRoll)
threeRolls = do
  firstRoll <- roll
  secondRoll <- roll
  thirdRoll <- roll
  return (firstRoll, secondRoll, thirdRoll)

nRolls :: Int -> ProbList [DiceRoll]
nRolls = nRepeats roll
```

We can now very simply find out, for example, the probability of rolling 6-1-6: 

```haskell
ghci> getProb (==(Six, One, Six)) threeRolls
1 % 80
```

Note that this could also have been achieved like so:

```haskell
ghci> getProb (==[Six, One, Six]) $ nRolls 3
1 % 80
```

Or even:

```haskell
ghci> getProb (==[Six, One, Six]) $ nRepeats roll 3
1 % 80
```

Alternatively, find the probability of all rolled numbers being less than
three over 5 rolls:

```haskell
ghci> getProb (all (<Three)) $ nRolls 5
243 % 100000
```

Rolling at least one six over 4 rolls:

```haskell
ghci> getProb (not . null . filter (==Six)) $ nRolls 4 
15 % 16
```

* * *

Invariants
----------

```haskell
equalProbs [] == ProbList []
equalProbs [x] == return x
(sumProbs pl == 1 % 1) -> (normalize xs == xs)
getProb (const True) == const 1 % 1
getProb (const False) == const 0 % 1 nRepeats pl 0 == return []
nRepeats pl 1 == ProbList . map (first (:[])) . getList $ pl
```
