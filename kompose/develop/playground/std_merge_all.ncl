let x1 = std.record.merge_all [{ a | default = 1 }, { a = 2 }] in
let x2 = x1 & { a = 3 } in
x2
