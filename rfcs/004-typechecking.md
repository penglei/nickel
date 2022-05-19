---
feature: typechecking
start-date: 2022-05-16
author: Yann Hamdaoui
---

# Typechecking

The goals of this RFC are:

1. Identify the main shortcomings of the current implementation of typechecking,
   in particular with respect to the interaction between typed and untyped code.
2. Write a proper formalization of a type system and companion type inference
   algorithm which overcomes those limitations as much as possible. If this
   proves too hard, even just a proper definition and formalization of the
   current type system would already be a positive outcome.

The motivation for the first step is self-explanatory: a more expressive type
system directly translate to users being able to write more programs (or clearer
versions of the same program, without superfluous annotations).

The second step is motivated by improving the experience of extending the type
system in the future and maintaining the Nickel codebase. We already hit edge
cases that led to unsatisfying [ad-hoc
fixes](https://github.com/tweag/nickel/pull/586). The current implementation
interleaves a number of different phase, which makes it harder to get into and
to modify. Finally, a clean and well designed specification often leads to a
simpler implementation, by removing accumulations of ad-hoc treatments that
become subsumed by a more generic case.

## Background

There is a substantial literature on type systems for programming languages, as
well as implementations, some of them both cutting-edge and of industrial
strength. For the purely static part, the ML languages family (including their
remote cousins: Haskell, OCaml, Scala, Purescript, etc.) has proved over time to
be a solid and expressive foundation. The role of the static type system of
Nickel is to be able to type various generic functions operating on primitive
types, and to do so doesn't seem to require new developments or very fancy
types. The current implementation, which supports polymorphism and row
polymorphism, appears to be enough currently.

However, the co-existence of statically typed code and dynamically typed code
makes Nickel different from most of the aforementionned inspirations. While we
often brand Nickel as a gradually typed language for simplicity, it technically
isn't totally. A cornerstone of _gradual type systems_, derived from the
original work of Siek and Taha[^1], is to statically accept potentially unsafe
conversions from and to the dynamic type `Dyn`, and more complex types with
`Dyn` inside like converting `Dyn -> Num` to `Num -> Num`. Such compatible types
are said to be _consistent_ with each others. These implicit conversions may or
may not be guarded at runtime by a check (_sound_ vs _unsound_ gradual typing).

```nickel
# If Nickel was gradually typed, this would be accepted
{
  add : Num -> Num -> Num = fun x y => x + y,
  mixed : Dyn -> Num -> Num = fun x y => add x (y + 1),
}
```

In Nickel, such implicit conversions are purposely not supported. Running this
examples gives:

```text
error: incompatible types
  ┌─ repl-input-0:3:46
  │
3 │   mixed : Dyn -> Num -> Num = fun x y => add x (y + 1),
  │                                              ^ this expression
  │
  = The type of the expression was expected to be `Num`
  = The type of the expression was inferred to be `Dyn`
  = These types are not compatible
```

A second -- and directly related -- peculiarity of Nickel are contract
annotations. Gradually typed language usually uses run-time checks called
_casts_ to validate the implicit conversions at runtime, but those casts are
rarely part of the source language and rather an implementation device living in
the intermediate representations. Contract annotations are in some way a
first-class version of the implicit casts of gradual typing. Thus, it is
possible to make the previous example work in Nickel by adding a contract
annotation which indicates what type the user expects the expression to be:

```nickel
{
  add : Num -> Num -> Num = fun x y => x + y,
  mixed : Dyn -> Num -> Num = fun x y => add (x | Num) (y + 1),
}
```

### Summary

The high-level picture of typing in Nickel the following dimensions:

- Statically typed code is checked using a standard ML-like/SystemF system with
  polymorphism and row polymorphism
- Nickel is stricter than a vanilla gradual type system, in that it doesn't
  allow implicit casts from and to the dynamic type.
- Nickel has contract annotations, which can be used to write type casts
  explicitly. They incur a runtime check.

## Motivation

This sections attempts to motivate this RFC practically: what are programs that
are natural write and that we expect to be accepted by the typechecker?

### Upcasts

The dynamic type acts statically a top type (with caveats , though[^2]), like
`Any` in some languages (TypeScript, Python with mypy). Although casts from the
dynamic type are unsafe in general, cast _to_ the dynamic type are safe. But the
typechecker currently isn't smart enough and requires explicit casts:

```nickel
{
  foo : Array Str =
    let some_data = {script = "echo ${hello}", vars = ["hello"] } in
    [builtin.serialize `Json some_data, builtin.serialize `Yaml some_data]
}
```
