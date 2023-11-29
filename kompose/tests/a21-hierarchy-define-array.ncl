let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let monitor_ = {
  deployment = {
    type = DeploymentType,
    object = {
      metadata.name = "deploy-a",
      spec.image | default = "x"
    }
  }
}
in
let monitor_deploy_value = {
  deployment = {
    value = {
      image | default = "",
    },
    fragment = {
      spec.image = value.image
    }
  }
}
in
let platform = {
  monitor = [monitor_, monitor_deploy_value]
}
in

platform

#try:
#kp render module/devs/a21-hierarchy-array.ncl -p image="XXXX"

#### result ####
# apiVersion: apps/v1
# kind: deployment
# metadata:
#   name: deploy-a
# spec:
#   image: XXXX
#   replica: 1
