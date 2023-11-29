let { DeploymentType, StatefulsetType, ConfigmapType, .. } = import "./type.ncl" in

let deploy = {
  type = DeploymentType,
  object = {
    metadata.name = "deploy-a",
    spec.image = "deploy:latest"
  },
}
in

{
  deployment = {
    self = [[deploy]]
  }
}
