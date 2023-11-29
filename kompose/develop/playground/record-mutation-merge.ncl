let foo = {
  a = {
    v1 = 111,
    v2 = 222,
  },

  b = 1,
  c = {},
}
in
let bar = {
  a | priority 200 = {
      v3 = 333,
    }
}
in

let foo_clean = foo |> std.record.remove "b" |> std.record.remove "c" in
let merge_after_clean = foo_clean & bar in
let foo_a = { a = foo.a } in
let bar_a = { a = bar.a } in
let projective_merge = foo_a & bar_a in
#projective_merge
merge_after_clean
