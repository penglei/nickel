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
          metadata.name = "deploy-a",
          spec.image | default = "x"
        },
      },
    }
  },
  fragm1 = {
    monitor = {
      deployment.fragment = {
        spec.replica = 333,
      }
    }
  },
  fragm2 = {
    monitor = {
      deployment.fragment = {
        spec.image = "x:v1",
      }
    }
  },
}
in

[demo.base, demo.fragm1, demo.fragm2]

#==---- results ----==

# - data: 2
# - apiVersion: apps/v1
#   kind: deployment
#   metadata:
#     name: deploy-a
#   spec:
#     image: x:v1
#     replica: 333
