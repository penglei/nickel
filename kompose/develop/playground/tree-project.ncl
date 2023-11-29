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

let mask1 = {
  foo.bar.a.no = {},
  foo.qux.x = {},
  x = {}
}
in
let mask = {
  foo.bar.a = {},
  foo.qux.x = {},
  x = {}
}
in
let is_empty_leaf = fun x name => x."%{name}" == {} in
let is_module_leaf = fun x name => match {'M i => true, _ => false} x."%{name}" in
let rec leaf_paths #| Dyn -> Array (Array String)
= fun tree termop =>
  std.array.flat_map
    (
      fun name =>
        let is_leaf = termop tree name in
        if is_leaf then
          [[name]]
        else
          std.array.map
            (fun ps => [name] @ ps)
            (leaf_paths tree."%{name}" termop)
    )
    (std.record.fields_with_opts tree)
in
let project = fun mask tree =>
    let rec visit
        = fun trace_routes mask mtree =>
            if mask == {} then
              mtree #TODO all leafs 
            else
              std.array.fold_left (fun acc {field, value} =>
                  let trace_routes = trace_routes @ [field] in
                  if std.record.has_field field mtree then
                      if !(std.is_record mtree."%{field}") && (std.is_record value && value != {}) then
                          std.fail_with
                            "can't drill down to project the field: %{std.string.join "." trace_routes}"
                            ++ ", because the mask field shape is different from the tree field"
                      else
                        acc |> std.record.update field (visit trace_routes value mtree."%{field}")
                  else
                      std.fail_with "can't find field:%{field}"
              ) {} (std.record.to_array mask)
    in
    visit [] mask tree
in
project mask tree

