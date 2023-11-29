let Comod = import "./module.ncl" in

let { ConfigmapType, .. } = import "./type.ncl" in

let tree = [
  {
    value = {},
    self = [[Comod.Disabled]]
  },
  {
    monitor = {
      configmap = {
        type = ConfigmapType,
        object = {
          metadata.name = "monitor-cfg1",
          data = 1111
        }
      },
    },
  }
]
in

tree
