let { DeploymentType, .. } = import "./type.ncl" in

let demo = {
  self = {
    type = DeploymentType,
    object = {
      metadata.name = "deploy-a",
      spec.image = "deploy:latest"
    },
  }
}
in

demo
