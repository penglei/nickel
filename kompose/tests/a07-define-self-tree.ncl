let { DeploymentType, StatefulsetType, ConfigmapType, .. } = import "./type.ncl" in

{
  deployment = {
    self = {
      type = DeploymentType,
      object = {
        metadata.name = "deploy-a",
        spec.image = "deploy:latest"
      },
    }
  }
}
