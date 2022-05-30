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

The important dimensions of typing in Nickel are:

- Statically typed code is checked using a standard ML-like/SystemF system with
  polymorphism and row polymorphism
- Nickel is stricter than a vanilla gradual type system, in that it doesn't
  allow implicit casts from and to the dynamic type.
- Nickel has contract annotations, which can be used to write type casts
  explicitly. They incur a runtime check.

## Motivation

This sections attempts to motivate this RFC practically: what are programs that
are natural write and that we expect to be accepted by the typechecker?

### Dynamic

The dynamic type acts as a top type statically (with caveats though[^2]), like
`Any` or `Object` in some languages. Although casts from the dynamic type are
unsafe in general, cast _to_ the dynamic type are safe. But the typechecker
currently isn't smart enough and requires explicit annotations:

```nickel
# rejected because some_data has type `{script: Str, vars: Array Str}`, which is
# not compatible with `Dyn`
{
  serialized : Array Str =
    let data = {script = "echo ${hello}", vars = ["hello"] } in
    let other_data = ["one", "two", "three"] in
    [
      builtin.serialize `Json data,
      builtin.serialize `Yaml other_data
    ]
}
```

To make it work, the user needs to explicitly add missing `Dyn`:

```nickel
{
  serialized : Arry Str =
    let data = {script = "echo ${hello}", vars = ["hello"] } in
    let other_data = ["one", "two", "three"] in
    [
      builtin.serialize `Json (data | Dyn),
      builtin.serialize `Yaml (other_data | Dyn)
    ]
}
```

### Dyn versus forall

Why do we need `Dyn` inside typed code at all? Untyped values are given the type
`Dyn`, but this is a different matter. This RFC is concerned with functions
_consuming_ values of type `Dyn`. In statically typed code, we can already
express operating over generic values using polymorphism, as in the definition
of `head`:

```nickel
head : forall a. Array a -> a
```

However, well-typed polymorphic functions enjoy
[_parametric_](https://en.wikipedia.org/wiki/Parametricity). Concretely, they
can't inspect their polymorphic arguments. In consequence, the contract system
also enforces this property dynamically. For example, the follwing function is
rejected by the contract system:

```nickel
let fake_id
  | forall a. a -> a
  = fun x => if builtin.is_num x then x + 1 else x in
fake_id 10
```

**TODO**: actually it is not, the behavior is more subtle, but that's an issue
with the current implementation, not with the model.

Any typed function that needs to inspect its argument needs to use `Dyn`, or at
least a less general type than `a`. A typical example is `array.elem`, which is
of type `Dyn -> Array Dyn -> Bool`, because it compares elements. This is a
source of `Dyn` inside typed functions:

```text
nickel>
let has_one : Bool = 
  let l = [1, 2, 4, 5] in
  array.elem 1 l 

error: incompatible types
  ┌─ repl-input-7:3:14
  │
3 │   array.elem 1 l
  │              ^ this expression
  │
  = The type of the expression was expected to be `Dyn`
  = The type of the expression was inferred to be `Num`
  = These types are not compatible
```

Indeed, we need to insert explicit casts:

```text
nickel>
let has_one : Bool = 
  let l = [1, 2, 4, 5] in
  array.elem (1 | Dyn) (l | Array Dyn)
nickel> has_one
true
```

Another possible future use-case would be the implementation of [flow-sensitive
typing](https://en.wikipedia.org/wiki/Flow-sensitive_typing), as in e.g.
TypeScript. Then, taking an argument of type `Dyn` and typecasing it (using
`builtin.typeof` or `builtin.is_xxx`) would make sense inside statically typed
code, naturally producing functions that consume values of type `Dyn`.

### Dictionaries

In essence, an upcast can be seen as _forgetting_ part of the type information.
The most drastic lost of information is casting to `Dyn`: we pretty much forget
everything about the original type of the value.

There are other useful loss of information. One concerns dictionary types `{_:
T}`. In practice, records serve several purposes in Nickel:

- A key-value mapping with a statically known structure. This is usually
  the case for configurations: one knows in advance what key will appear in the
  final value and for each key, the type of values allowed.
- A key-value mapping with a dynamic structure. Keys are added
  dynamically and depend on runtime values.

The first case is best modeled using record types. For example:

```nickel
{
  name = "virtal",
  version = "1.0.1",
  enabled = true,
} : {
  name : Str,
  version : Str,
  enabled : Bool,
}
```

But for records which fields are not statically known, record types are too
rigid. We use dictionary types instead:

```nickel
(let data = {ten = 10} in
data
|> record.insert "one" 1
|> record.insert "two" 2
|> record.insert "three" 3) : {_: Num}
```

Unfortunately, this example doesn't work as it is:

```text
error: incompatible types
  ┌─ repl-input-6:2:1
  │
2 │ data
  │ ^^^^ this expression
  │
  = The type of the expression was expected to be `{_: Num}`
  = The type of the expression was inferred to be `{}`
  = These types are not compatible
```

Record literals are always inferred to have a precise record type (here,
`{ten : Num}`) which is thus different from the expected dictionary type. A
special casing in the typechecker can still make this example work with an
additional annotation:

```nickel
(let data : {_ : Num} = {ten = 10} in
data
|> record.insert "one" 1
|> record.insert "two" 2
|> record.insert "three" 3) : {_: Num}
```

Alas, this special case is fragile: it only works if we annotate directly the
record literal. If we use a variable as a proxy, inference is broken and there
is no way to make the following example typecheck by fiddling with type
annotations:

```nickel
nickel> (let x = {ten = 10} in
let data : {_ : Num} = x in
data
|> record.insert "one" 1
|> record.insert "two" 2
|> record.insert "three" 3) : {_: Num}

error: incompatible types
  ┌─ repl-input-8:2:24
  │
2 │ let data : {_ : Num} = x in
  │                        ^ this expression
  │
  = The type of the expression was expected to be `{_: Num}`
  = The type of the expression was inferred to be `{ten: Num}`
  = These types are not compatible
```

## Proposal

Given the precedent sections, we propose to add a simple subtyping relation
generated by `T <: Dyn` for all type `T` that is not a type variable, and `{ l1
: T, .., ln : T} <: {_: T}` for the dictionaries use-case.

### `Dyn` inference

The guiding principle could be phrased as:

_Never infer a `Dyn` type implicitly. `Dyn`, and subtyping in general, must
always come from an explicit an annotation._

For example, the following example is expected to **fail**:

```nickel
let uni_pair : forall a. a -> a -> {fst: a, snd: a} = fun x y =>
  { fst = x, snd = y } in

uni_pair 1 "a" : _
```

We could infer the type `Dyn` for the instantiation of `a`. But this is
currently an error, and should arguably stay this way. Indeed, `Dyn` can make a
lot of such cases pass, only to manifest as a later type error – and probably a
disconcerting one involving a `Dyn` coming from nowhere – when one tries to
actually use the result of the function. However, if one of the argument is
explicitly of type `Dyn`, then it is reasonable to allow the other one to be
silently upcasted:

```nickel
let foo : Dyn = 1 in
uni_pair foo 1 : _
```

Unfortunately, we don't currently have a good characterization of this as a
property of the declarative type system or of type inference . It is an informal
guideline, which is reflected in the algorithmic type inference.

### Polymorphism and subtyping

The previous example shows an interesting point when combining subtyping and
polymorphism: if we instantiate type variables at the first type we see, as we
do currently, typechecking is sensitive to the order of arguments:

```nickel
# ok, a is instantiated to Dyn, and then 1 : Dyn
uni_pair foo 1 : _ 
# would fail, a is instantiated to Num, but foo is not of type Num
uni_pair 1 foo : _
```

This problem is dubbed the Tabby-first problem in [this comprehensive review of
bidirectional typing of Dunfield and
Krishnaswami](https://arxiv.org/abs/1908.05839), but surprisingly, it doesn't
seem to have been deeply studied (outside of the subtyping relation induced by
polymorphism). For subtyping induced by polymorphism, there are solutions: the
same authors (Dunfield and Krishnaswam) restricts their system to impredicative
polymorphism, which is then order-independent [^3]. On the other side, Haskell deemed
impredicative polymorphism to be more important and rather abandons the variance
of arrow and more generally all type constructors, coupled with a so-called
QuickLook phase that tries to guess impredicative instantiation.

However, we can't apply the Haskell approach naively, because in the presence of
`Dyn`, an impredicative instantiation is not the only possiblity anymore.

- **TODO**: add example
- **TODO**: we don't want to have deep instantiation, because it's easier to add
    than to remove (see Haskell example).
- **TODO**: present the system: predicative polymorphism, higher-rank, without
    deep instantiation/skolemization.

## Alternatives

- **TODO**: drop subtyping, and have either QuickLook, deep instantiation, or
  none (to start)
- **TODO**: drop Dyn subtyping, keep only dictionaries, implement QuickLook
    eventually.
