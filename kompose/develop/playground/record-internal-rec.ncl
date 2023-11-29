{
  inputs | not_exported = {
      foo | default = 1,
      bar | default = "a"
    },
  target = {
    foo = inputs.foo
  }
}
& {
  inputs.foo = 11111111111111
}
