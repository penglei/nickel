let index_arr = fun items => std.array.fold_left (fun acc e => std.record.insert e.name e acc) {} items in
let to_arr = fun r => std.array.map (fun k => std.record.update "name" k r."%{k}") (std.record.fields r) in
let schema = {
  arr | default = [],
}
in
let basic = {
  arr = [
    {
      name = "foo",
      value = "foo in basic"
    }
  ]
}
in
let decorator = {
  arr | priority 10 = [],
  namedArr = index_arr arr,
}
in
let decorate = fun t =>
  let defaultNamedArr = index_arr t.arr in
  {
    arr | priority 10 = [],
    namedArr = defaultNamedArr,
  }
in
let restore = fun records => #std.array.map (fun k => std.record.update "name" k t."%{k}") (std.record.fields t)
  {
    namedArr | priority 100 = null,
    arr | priority 100 = (to_arr records.namedArr),
  }
in
let frag1 = {
  namedArr.bar = { name = "bar", value = "bar in frag1" }
}
in
#schema & basic & decorator & frag1
let p1 = schema & basic in
let p2 = (p1 & (decorate p1)) & frag1 in
p2 & restore (p2)
