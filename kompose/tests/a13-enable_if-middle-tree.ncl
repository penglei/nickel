let Comod = import "./module.ncl" in
let { enable_if, .. } = Comod in

let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let deployment_module = {
  type = DeploymentType,
  object = {
    metadata.name = "monitor-deploy",
    spec.image | default = "x"
  },
}
in

let demo = {
  first = {
    monitor = {
      value = {
        disable_monitor | default = false
      },
      self =
        enable_if
          (!value.disable_monitor)
          (
            {
              configmap = {
                type = ConfigmapType,
                object = {
                  metadata.name = "monitor-cfg",
                  data = 2
                }
              },

              deployment = deployment_module,
            }
          ),
    }
  },

  fragm_value = {
    monitor = {
      deployment = {
        value | Dyn,
        fragment = {
          spec.image = value.oci-image.reference ++ "-image-by-value",
          #spec.replica = value.replica,
        },
      }
    }
  },

  middle_input = {
    monitor = {
      input = {
        oci-image.reference = "xxx:v1",
        disable_monitor = true, #!!override here
      }
    }
  },

  top_input = {
    input = { replica = 11111 }
  },
}
in

[
  demo.first,
  demo.fragm_value,
  demo.middle_input,
  demo.top_input,
]

#==---- results ----==

# []
