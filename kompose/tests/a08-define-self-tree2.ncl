let { DeploymentType, StatefulsetType, ConfigmapType, .. } = import "./type.ncl" in

let deployment_module = {
  type = DeploymentType,
  object = {
    metadata.name = "deploy-a",
    spec.image = "deploy:latest"
  },
}
in

let demo = {
  first = {
    deployment = {
      self = deployment_module,
    },
    configmap = {
      type = ConfigmapType,
      object = {
        metadata.name = "monitor-cfg",
        data = 1
      }
    },
  },

  second = {
    statefulset = {
      type = StatefulsetType,
      object = {
        metadata.name = "sts-a",
        spec.image = "sts:v1"
      },
    },
    foobarqux = {
      self = first
    }
  },
}
in

[
  [demo.first],
  [demo.second],
  [
    {
      foobarqux.configmap.fragment = { data | force = 666666 }
    }
  ]
]
