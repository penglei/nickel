let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let monitor_ = {
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
}
in

{
  monitor = monitor_,
  apiserver = [],
}
