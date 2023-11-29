let ObjectHeader = {
  name | String
}
in
let DeploymentSpec = {
  replicas | Number | default = 1,
  image | String | default = "",
}
in

let Deployment = {
  Schema | (ObjectHeader & { spec | DeploymentSpec }) | rec default = {
      spec.replicas = 5
    }
}
in

let a = (
  {
    name = "foo",
    spec = {
      replicas = 3,
      image = "x",
    },
  } | Deployment.Schema
)
in
a
