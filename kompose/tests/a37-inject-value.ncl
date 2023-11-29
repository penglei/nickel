let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let monitor = {
  deployment = {
    type = DeploymentType,
    object = {
      metadata.name = "deploy-demo",
      spec.image | default = "x"
    },
  },
}
in

let deployment_artifact = {
  deployment = {
    value = {
      component | String,
      artifacts = {},
    },
    fragment =
      (std.when (std.record.has_field value.component value.artifacts))
        {
          spec.image = value.artifacts."%{value.component}".oci-image ++ "-zzz",
        },
  }
}
in

let top_input = {
  input = {
    artifacts = {
      monitor.oci-image = "monitor:latest"
    }
  },
}
in

[
  monitor,
  deployment_artifact,
  {
    deployment = {
      value.component = "monitor"
    }
  },
  top_input,
]
