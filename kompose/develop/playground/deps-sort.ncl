let tree = {
  foo = {
    a = {
      b = {
        key1 = "aa",
        key2 = 1111,
      }
    }
  },
  bar = {
    demands = {
      a.b
    },
    custom = {
      key1 = demands.a.b.key1,
      key2 = demands.a.b.key2,
      key3 = "key3 in custom"
    }
  }
}
in

tree
