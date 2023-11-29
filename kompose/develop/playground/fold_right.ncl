let rec make_record = fun routes target =>
  std.array.fold_right (fun key acc => { "%{key}" = acc }) target routes
in

make_record ["a", "b", "c"] 1
