let { DeploymentType, TadComponentType, .. } = import "./type.ncl" in

let apiserver = {
  deployment = {
    type = DeploymentType,
    object = {
      metadata.name = "nginx",
      spec.image = "nginx:1.25",
      #spec.replica = 1
    },
  },
}
in

let tad_apiserver_deployment_wrapper = {
  deployment."@meta" = { hidden = true },
  deployment-component = {
    type = TadComponentType,
    object = {
      metadata.name = "apiserver-component",
      spec.workload = {},
    }
  }
}
in
let tad_apiserver_deployment_ref = {
  deployment-component = {
    demands = {
      deployment = {}
    },
    fragment = {
      spec.workload = demands.deployment,
    }
  },
}
in

let tad_apiserver_deployment_fragm1 = {
  deployment-component = {
    fragment = {
      spec.workload.spec.replica = 71
    }
  }
}
in

let tad_khaos = [
  apiserver,
  tad_apiserver_deployment_wrapper,
  tad_apiserver_deployment_ref,
  tad_apiserver_deployment_fragm1,
]
in

#tad_khaos
#|> Comod.define
#|> Comod."#develop".merge_stage1
#|> Comod."#develop".merge_stage2
#|> Comod."#develop".show_lazy_tree
#----------------------
#tad_khaos
#|> Comod.define
#|> Comod."#develop".merge_stage1
#|> Comod."#develop".merge_stage2
#|> Comod."#develop".merge_stage3_simplify
#|> Comod."#develop".show_tree
#----------------------
#tad_khaos
#|> Comod.define
#|> Comod."#develop".merge_stage1
#|> Comod."#develop".merge_stage2
#|> Comod."#develop".merge_stage3_simplify
#|> Comod."#develop".merge_stage4_parse_dep_graph
#|> std.serialize 'Json
#----------------------
tad_khaos
