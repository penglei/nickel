let foo = {
  a : Number | default = 1,
  str : String =
      if a == 1 then
        "one"
      else if a == 2 then "two" else ">>",
}
in
let x = std.array.reduce_left (&) [foo, { a = 2 }] in
(x & { a | priority 1 = 3 }).str == ">>"
