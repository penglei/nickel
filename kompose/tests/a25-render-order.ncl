let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let tree = {
  monitor = {
    "@meta" = { order = ["deployment"] },
    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "monitor-deploy",
        spec.image = "x"
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
}
in
let tree = [
  tree,
  {
    foo = {
      type = DeploymentType,
      object = {
        metadata.name = "deploy-b",
        spec.image = "yyy"
      },
    }
  },
  {
    monitor.deployment.fragment = { spec.replica = 1000, spec.image | priority 10 = "x-fragm1" }
  }
]
in

tree
