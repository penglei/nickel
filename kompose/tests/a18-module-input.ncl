let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let demo = {
  base = {
    monitor = {
      configmap = {
        type = ConfigmapType,
        object = {
          metadata.name = "monitor-cfg",
          data = 2
        }
      },

      deployment = {
        type = DeploymentType,
        object = {
          metadata.name = "deploy-demo",
          spec.image | default = "x"
        },
      },
    }
  },
  fragm_value = {
    monitor = {
      deployment = {
        value | Dyn,
        fragment = {
          spec.image = value.oci-image.reference ++ "-image-by-value",
        },
      }
    }
  },
  fragm_input = {
    monitor = {
      deployment = {
        input = { oci-image.reference = "xxx:v1" }
      }
    }
  },
}
in

[
  demo.base,
  demo.fragm_value,
  demo.fragm_input,
]

#==---- results ----==

# - data: 2
# - apiVersion: apps/v1
#   kind: deployment
#   metadata:
#     name: deploy-demo
#   spec:
#     image: xxx:v1-image-by-value
#     replica: 1
