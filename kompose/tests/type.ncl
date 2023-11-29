let TypeMeta = {
  apiVersion | String,
  kind | String,
}
in
let Metadata = {
  metadata
    | {
      name | String,
      namespace | String | optional,
      labels | { _ : String } | optional,
    }
}
in
let DeploymentSpec = {
  spec
    | {
      image | String,
      replica | Number | default = 1,
    }
}
in
let StatefulSetSpec = {
  spec
    | {
      image | String,
      replica | Number | default = 1,
    }
}
in
{
  ConfigmapType = {
    Identifier = "v1:ConfigMap",
    Schema =
      {
        data | Dyn
      }
      & Metadata
  },

  DeploymentType = {
    Identifier = "apps/v1:Deployment",
    Schema =
      (
        {
          apiVersion | String = "apps/v1",
          kind | String = "deployment",
        } | TypeMeta
      )
      & Metadata
      & DeploymentSpec,
  },

  StatefulsetType = {
    Identifier = "apps/v1:StatefulSet",
    Schema =
      (
        {
          apiVersion | String = "apps/v1",
          kind | String = "deployment",
        } | TypeMeta
      )
      & Metadata
      & StatefulSetSpec,
  },

  TadComponentType = {
    Identifier = "infra.tce.io/v1:Component",
    Schema =
      (
        {
          apiVersion | String = "infra.tce.io/v1",
          kind | String = "Component",
        } | TypeMeta
      )
      & Metadata
      & { spec | { workload | Dyn } },
  }
}
