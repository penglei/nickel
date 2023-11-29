let tree = {
  foo.bar.qux = {},
  foo.a = {},
  bar.a = {},
  a.b.c = {},
  a = {}
}
in

let show_string = std.serialize 'Json in

let get_opt_fields = fun x =>
  let fields_with_opts = std.record.fields_with_opts x in
  let fields_with_opts = std.trace "fields_with_opts: %{show_string fields_with_opts}" fields_with_opts in
  let field_cache = std.array.fold_left (fun acc field => std.record.insert field true acc) {} fields_with_opts in
  let fields = std.record.fields x in
  let fields = std.trace "fields:%{show_string fields}" fields in
  let opt_fields_cache = std.array.fold_left (fun fc name => std.record.update name false fc) field_cache fields in
  std.trace "opt_fields_cache:%{show_string opt_fields_cache}" opt_fields_cache
in

let rec tree_paths #| Dyn -> Array (Array String)
= fun tree =>
  #let opt_fields_cache = get_opt_fields tree in
  std.array.flat_map
    (
      fun name =>
        let is_leaf =
          #opt_fields_cache."%{name}"
          tree."%{name}" == {}
        in
        if is_leaf then
          [[name]]
        else
          std.array.map
            (fun ps => [name] @ ps)
            (tree_paths tree."%{name}")
    )
    (std.record.fields_with_opts tree)
in

tree_paths tree
