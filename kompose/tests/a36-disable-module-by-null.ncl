let Comod = import "./module.ncl" in
let { DeploymentType, .. } = import "./type.ncl" in

let deployment_module = (
  {
    type = DeploymentType,
    object = { spec.image | default = "x" },
  }
)
in
let demo = {
  base = {
    deployment = {
      value = {
        _enable = !value.disable_monitor_deployment,
      },

      self = null,
    }
  },
  top_input = {
    input = { replica = 11111, disable_monitor_deployment = true }
  }
}
in

let tree = [
  demo.base,
  demo.top_input,
]
in

tree
