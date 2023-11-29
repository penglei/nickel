let { DeploymentType, TadComponentType, .. } = import "./type.ncl" in

let apiserver = {
  deployment = {
    type = DeploymentType,
    object = {
      metadata.name = "nginx",
      spec.image = "nginx:1.25",
    },
  },
}
in

let tad_apiserver_deployment_wrapper = {
  deployment."@meta" = { hidden = true },
  tad-deployment-component = {
    type = TadComponentType,
    demands = {
      deployment = {}
    },
    object = {
      metadata.name = "apiserver-component",
      spec.workload = demands.deployment,
    },
  }
}
in

let tad_khaos = [
  apiserver,
  tad_apiserver_deployment_wrapper,
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
