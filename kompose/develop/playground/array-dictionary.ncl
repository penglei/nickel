let Person = {
  name | String,
  age | Number,
}
in
let Team = {
  Title | String,
  Members | Array { _ : Person }
}
in
let createTeam : String -> Array { _ : Person } -> Team = fun t members =>
    {
      Title = t,
      Members = members
    } | Team
  in
createTeam
  "ybyte"
  [
    { first = { name = "alice", age = 20 } },
    { second = { name = "bob", age = 30 } },
  ]
