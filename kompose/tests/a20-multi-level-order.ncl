let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

{
  "@meta".order = ["monitor"],

  monitor = {
    "@meta" = { order = ["deployment"] },

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
