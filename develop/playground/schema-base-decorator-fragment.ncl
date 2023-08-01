let Schema = {
  replicas : Number | default = 1,
  arr | Array Number | default = [], #= [1, 2],
  name | String | default = "",
  image | String | default = "",
}
in
let base = {
  replicas = 3,
  name = "xx",
  arr = [1, 2],
}
in
let decorator = {
  arr = [],
  namedArr = {
    "a" = 1,
    "b" = 2,
  }
}
in
let fragement = {
  image = "oci-image:v1"
}
in
let t1 = std.record.merge_all [Schema, base] in
#let t1 = Schema & base in
let t2 = { target | rec default = t1 }.target in
#{ decorator | rec default = base}
let t3 = t2 & decorator in
t3 & fragement
