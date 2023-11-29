let { DeploymentType, TadComponentType, .. } = import "./type.ncl" in

let apiserver = {
  apiserver = {
    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "nginx",
        spec.image = "nginx:1.25",
      }
    }
  }
}
in

let tad_apiserver_deployment_wrapper = {
  apiserver = {
    deployment."@meta" = { hidden = true },
    deployment-component = {
      type = TadComponentType,
      demands = {
        apiserver.deployment = {}
      },
      object = {
        metadata.name = "apiserver-component",
        spec.workload = demands.apiserver, #"deployment" 路径被引入到这里
      }
    }
  }
}
in

[
  apiserver,
  tad_apiserver_deployment_wrapper
]
