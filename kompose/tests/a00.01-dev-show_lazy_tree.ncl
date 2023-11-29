let Comod = import "module.ncl" in

let tree = {
  platform.apiserver.deployment = {
    foo.fragment = {
      spec.replica = 1
    }
  }
}
in

tree
|> Comod.define
|> Comod."#develop".show_lazy_tree
