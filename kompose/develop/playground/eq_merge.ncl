let Foo = {
  a : Number | default = 1,
  b : String = "foo-b",
}
in
let Bar = {
  a | Number | default = 1,
  b | String,
  c : String = "bar-c",
}
in
let raw = { a = 2, b = "foo-b" }
in
#let x | Foo | Bar = raw in x
#Foo & raw
Bar & raw
