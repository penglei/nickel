let tree = {
  foo = {
    bar = {
      a = 1,
      b = 2,
    },
    qux = {
      a = 1,
      b = 2,
      x.y.z = 1,
    }
  },
  x = 1,
  y = 333,
  z = 333
}
in

let filter_tree | Dyn -> Array (Array String) -> Dyn
  = fun tree paths =>
    std.record.merge_all
      (
        std.array.map
          (
            fun paths =>
              let name = std.array.last paths in
              {
                "%{name}" = std.array.fold_left (fun acc k => acc."%{k}") tree paths
              }
          )
          paths
      )
  in

filter_tree tree [["x"], ["foo", "bar"], ["y"]]
