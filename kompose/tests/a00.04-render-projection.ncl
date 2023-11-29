let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in
let Comod = import "module.ncl" in

let tree = {
  monitor = {
    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "monitor-deploy",
        spec.image = "monitor:latest"
      },
    },
    configmap = {
      type = ConfigmapType,
      object = {
        metadata.name = "monitor-cfg",
        data = 1
      }
    },
  },

  apiserver = {
    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "apiserver-deploy",
        spec.image = "apiserver:latest"
      },
    }
  },
}
in
tree |> Comod.render [ "*.deployment", "monitor.configmap" ] 4
