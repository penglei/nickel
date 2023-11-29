let outer = {
  foo | Number = 1,
  inner = {
    bar | Number = 1,
  }
}
in
({ target | rec default = outer }) & { target = { inner | rec default = { bar = 1 } } }
