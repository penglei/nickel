# Call w/ Richard #2

Maybe we want to keep actually the minimum and maximum for the declarative type
system.

Quick-Look: we need to know polytypes right away, otherwise we can't know what
to do when we have an application with head `?a` that can be of type `forall a.
_ -> _`.

Instantiation constraint: this type can instantiate to `Num -> Num`.

```math
forall a. a -> a   >>:  Num -> Num

2:40

forall a b. a -> b   >>:  Num -> Num

2:40

f : ?a
... f 3 4 ...

2:40

?a  >>:  Num -> Num -> ?b
```

Guarded impredicativity.

Communicate clearly to users what can change. Point to make on which aspect to
make stable or not.

Do not instantiate unification variable to a polytype, ever. Start with no
exception, and then wait for people to complain.

```haskell
($) :: (a -> b) -> a -> b

2:58

f :: (forall a. ...) -> ...
... f $ blah ...
```
