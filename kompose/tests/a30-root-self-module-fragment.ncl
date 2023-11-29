let Comod = import "./module.ncl" in

let { ConfigmapType, .. } = import "./type.ncl" in

let tree = [
  {
    self.fragment = {
      data = 2222,
    }
  },
  {
    type = ConfigmapType,
    object = {
      metadata.name = "monitor-cfg1",
      data | default = 1111
    }
  }
]
in

tree
