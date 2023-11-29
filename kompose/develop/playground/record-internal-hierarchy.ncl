#{
#bar =
{
  v = "a",
  internal = {
    v = "b",
    x = v,
    y = internal.v
  },

  foo = internal.x
}
#}
