let foo = {
  a | Number = 1
}
in
let bar = {
  a | not_exported,
  b | Number = 2
}
in foo & bar
