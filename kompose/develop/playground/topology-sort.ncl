let modules = {
  "khaos.platform.apiserver.deployment" = [],
  "khaos.platform.apiserver.deployment-component" = ["khaos.platform.apiserver.deployment"],
  "a" = ["b", "c"],
  "b" = ["d"],
  "c" = ["d"],
  "d" = [],
}
in
let topology-sort = fun graph =>
  let rec dfs_visit = fun ctx elem =>
    let visited = std.record.has_field elem ctx.visited in
    if visited then
      ctx
    else
      let ctx = ctx |> std.record.update "visited" (ctx.visited |> std.record.update elem true) in
      let deps = graph."%{elem}" in
      if deps == [] then
        ctx |> std.record.update "sorts" (ctx.sorts @ [elem])
      else
        let ctx = std.array.fold_left (dfs_visit) ctx deps in
        ctx |> std.record.update "sorts" (ctx.sorts @ [elem])
  in
  let result = std.array.fold_left (dfs_visit) { sorts = [], visited = {} } (std.record.fields graph)
  in
  result.sorts
in

topology-sort modules
