let Comod = import "./module.ncl" in
let { define, .. } = Comod in
let Dev = Comod."#develop" in

let { DeploymentType, ConfigmapType, .. } = import "./type.ncl" in

let tree = {
  monitor = {
    "@meta" = { order = ["deployment"] },
    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "deploy-a",
        spec.image = "x"
      },
    },
    configmap = {
      type = ConfigmapType,
      object = { data = 1 }
    },
  },
}
in
let tree = [
  tree,
  {
    foo = {
      type = DeploymentType,
      object = {
        metadata.name = "deploy-b",
        spec.image = "yyy"
      },
    }
  },
  {
    monitor.deployment.fragment = { spec.replica = 1000, spec.image | priority 10 = "x-fragm1" }
  }
]
in

let tree =
  tree
  |> define
  |> Dev.merge_stage1
  |> Dev.merge_stage2
  |> Dev.merge_stage3_simplify #LazyTree transform to Tree
in

let graph = Dev.merge_stage4_parse_dep_graph tree
in

let result = Dev.merge_stage6_render ["*"] tree graph in
result
