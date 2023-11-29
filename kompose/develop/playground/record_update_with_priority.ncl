let base = {
  foo = 1,
  bar = 2,
}
in

let patch = {
  foo | priority 100 = 1111,
}
in
let x = std.record.update "foo" patch.foo base in
#x & base # priority would be lost in update
x
