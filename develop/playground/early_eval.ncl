let foo = {
  a : Number | default = 1,
  str : String =
      if a == 1 then
        "one"
      else if a == 2 then "two" else ">>",
}
in
let x = std.record.merge_all [{ a = 2 }, foo] in
(x & { a | priority 1 = 3 }) #.str == "one"
