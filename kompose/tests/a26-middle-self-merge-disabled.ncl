let Comod = import "./module.ncl" in

let { ConfigmapType, .. } = import "./type.ncl" in

[
  {
    monitor = {
      configmap = {
        type = ConfigmapType,
        object = {
          metadata.name = "monitor-cfg1",
          data = 1111
        }
      },
      configmap2 = {
        type = ConfigmapType,
        object = {
          metadata.name = "monitor-cfg2",
          data = 2222
        }
      },
    },
  },
  {
    monitor.self = Comod.Disabled
  }
]
