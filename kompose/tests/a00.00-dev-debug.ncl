let Comod = import "module.ncl" in
let Dev = Comod."#develop" in

let tree = 'C { meta = {}, data = { foo = 'M 1, bar = 'M 2 } }
in

tree |> Dev.show_tree
