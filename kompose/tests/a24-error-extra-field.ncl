let { DeploymentType, .. } = import "./type.ncl" in

{
  deployment = {
    type = DeploymentType,
    object = {
      metadata.name = "deploy-a",
      spec.image = "x"
    }
  }
}
