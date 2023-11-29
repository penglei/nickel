let Spec = {
  #spec = { foo | String }
  spec | { foo | String } #
}
in

let amend = fun obj =>
  obj
  & {
    x.spec.bar = obj.x.spec.foo ++ "!"
  }
in
let rectify = fun obj =>
  let bar = obj.x.spec.bar in
  let objx = obj.x |> std.record.update "spec" (obj.x.spec |> std.record.remove "bar") in
  #({ spec.foo | priority 1 = bar } & obj)
  {
    x = (obj.x & objx)
  }
in

let result = rectify (amend ({ x | Spec = { spec.foo = "a" } }))
in
#(result.x | Spec)

##simlest demo
#let sth = { x | Spec = { spec.foo = "a" } } in
#sth & { x.bar = "??" }

#use update recursive record to normal dict
let sth = { x | Spec = { spec.foo = "a" } } in
std.record.update "bar" "??" sth
