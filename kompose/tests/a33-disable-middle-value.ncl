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
    monitor = {
      value = {
        enable | default = false,
        is-disabled = !enable
      },
      self = Comod.disable_if value.is-disabled
    }
  },
  {
    input = {
      enable = false
    }
  }
]
in

tree
