# Hello Haskell

Haskell is a purely functional, statically typed programming language known for its expressive type system
and lazy evaluation. This guide assumes you have experience with other programming languages like Python,
Julia, and Lua, and will introduce you to the fundamentals of Haskell.

## Basic Syntax and REPL

Haskell provides an interactive REPL called `ghci`:

```sh
ghci
```

You can evaluate expressions:

```haskell
Prelude> 2 + 3 * 4
14
Prelude> even 42
True
```

## Variables and Functions

Haskell uses `let` to define variables:

```haskell
let x = 5
let y = x * 2
```

Functions are defined using `=`:

```haskell
square x = x * x
```

### Function Application

Function calls do **not** require parentheses or commas:

```haskell
square 4 -- 16
```

## Types and Type Inference

Haskell uses strong static typing:

```haskell
x :: Int
x = 42

y :: Double
y = 3.14

name :: String
name = "Haskell"
```

### Function Type Signatures

```haskell
square :: Int -> Int
square x = x * x
```

Functions can take multiple arguments:

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

## Conditionals

Haskell uses `if` expressions:

```haskell
isEven :: Int -> Bool
isEven x = if x `mod` 2 == 0 then True else False
```

Or pattern matching:

```haskell
isEven :: Int -> Bool
isEven x
  | x `mod` 2 == 0 = True
  | otherwise = False
```

## Lists

Lists are fundamental in Haskell:

```haskell
numbers = [1, 2, 3, 4, 5]
```

Access elements:

```haskell
head numbers -- 1
tail numbers -- [2,3,4,5]
last numbers -- 5
```

List comprehension:

```haskell
squares = [x * x | x <- [1..10]]
```

## Tuples

Tuples store fixed-size collections of mixed types:

```haskell
pair = (42, "Haskell")
```

Access elements:

```haskell
fst pair -- 42
snd pair -- "Haskell"
```

## Pattern Matching

Functions can be defined using pattern matching:

```haskell
factorial :: Int -> Int
factorial 0 = 1
factorial n = n * factorial (n - 1)
```

## Higher-Order Functions

Functions are first-class citizens:

```haskell
applyTwice :: (a -> a) -> a -> a
applyTwice f x = f (f x)

inc x = x + 1
applyTwice inc 5 -- 7
```

### Map, Filter, and Fold

```haskell
map (*2) [1,2,3] -- [2,4,6]
filter even [1..10] -- [2,4,6,8,10]
foldl (+) 0 [1,2,3,4] -- 10
```

## Lambdas

Anonymous functions use `\`:

```haskell
map (\x -> x * 2) [1,2,3]
```

## Lazy Evaluation

Haskell evaluates expressions only when needed:

```haskell
lazyList = [1..]
take 5 lazyList -- [1,2,3,4,5]
```

## Recursion

Recursion is common in Haskell:

```haskell
sumList :: [Int] -> Int
sumList [] = 0
sumList (x:xs) = x + sumList xs
```

## Modules

Import modules using `import`:

```haskell
import Data.List
sort [3,1,2] -- [1,2,3]
```

## Conclusion

This guide covered the basics of Haskell, including functions, types, lists, recursion, and higher-order
functions. Continue learning by exploring monads, typeclasses, and advanced functional programming concepts!
