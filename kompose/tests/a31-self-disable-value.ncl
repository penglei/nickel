let Comod = import "./module.ncl" in

let { ConfigmapType, .. } = import "./type.ncl" in

let tree = [
  {
    configmap = {
      type = ConfigmapType,
      object = {
        metadata.name = "monitor-cfg1",
        data = 1111
      }
    },
  },
  {
    configmap = {
      value = {
        disable | default = false
      },
      self = Comod.disable_if value.disable
    }
  }
]
in

tree
