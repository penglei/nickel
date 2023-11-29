let Comod = import "./module.ncl" in

let { ConfigmapType, .. } = import "./type.ncl" in

let tree = [
  {
    monitor = {
      configmap = {
        type = ConfigmapType,
        object = {
          metadata.name = "monitor-cfg1",
          data = 1111
        }
      }
    }
  },
  {
    monitor = Comod.Disabled
  }
]
in

let Dev = Comod."#develop" in
tree
#|> Comod.define
#|> Dev.merge_stage1
#|> Dev.merge_stage2
#|> Dev.show_lazy_tree
