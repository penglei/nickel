let Assert = contracts.fromPred functions.id in

[
  {foo | default = 1} & {foo = 2} == {foo = 2},
  {foo = 1 + 1, bar = foo + 1} == {foo = 2, bar = 3},

  let r = {foo | default = 1 + 1, bar = foo + 1} in
  builtins.deepSeq (r & {foo = 3}) r == {foo = 2, bar = 3},

  let r = {foo | default = 1 + 1, bar = foo + 1} in
  (r & {foo = 3}) == {foo = 3, bar = 4},

  let r = {foo | default = 1 + 1, bar = foo + 1} in
  builtins.deepSeq r (r & {foo = 3}) == {foo = 3, bar = 4},

  let ext = 0 + 1 in
  let r = {
    foo | default = 1 + 1,
    a = let inner = 0 in foo + ext + inner,
    b = let inner = 1 in a + ext + inner,
    c = let inner = 2 in b + ext + inner,
  } in
  builtins.deepSeq (r & {foo = 1 - 1}) r
    == {foo = 2, a = 3, b = 5, c = 8},

  let ext = 0 + 1 in
  let r = {
    foo | default = 1 + 1,
    a = let inner = 0 in foo + ext + inner,
    b = let inner = 1 in a + ext + inner,
    c = let inner = 2 in b + ext + inner,
  } in
  builtins.deepSeq r (r & {foo = 1 - 1})
    == {foo = 0, a = 1, b = 3, c = 6},

  let nested = {
    foo.bar.baz | default = 0,
    some.nested = {
      stuff = foo.bar.baz + 1,
      other = stuff + 1,
    },
  } in
  builtins.deepSeq (nested & {foo.bar.baz = 1}) nested
    == {foo.bar.baz = 0, some.nested.stuff = 1, some.nested.other = 2},

  let nested = {
    foo.bar.baz | default = 0,
    some.nested = {
      stuff = foo.bar.baz + 1,
      other = stuff + 1,
    },
  } in
  builtins.deepSeq nested (nested & {foo.bar.baz = 1})
    == {foo.bar.baz = 1, some.nested.stuff = 2, some.nested.other = 3},

  let base = {foo | default = "a", bar = foo ++ "b"} in
  let ext1 = base & {foo = "1"} in
  let ext2 = base & {foo = "A"} in
  (base.bar == "ab"
  && ext1.bar == "1b"
  && ext2.bar == "Ab")
  |> builtins.deepSeq base
  |> builtins.deepSeq ext1
  |> builtins.deepSeq ext2,
]
|> lists.foldl (fun next acc => (next | #Assert) && acc) true