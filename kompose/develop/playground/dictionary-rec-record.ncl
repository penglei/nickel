let Schema = {
  oci-image = {
    registry | String,
    namespace | String,
    name | String,
    tag | String,
    repository | String | default = "%{registry}/%{namespace}/%{name}",
    reference | String | default = "%{repository}:%{tag}",
  },
  vcs = {
    source | String | default = "",
    commit | String | default = "",
    #tag | String | default = "",
    branch | String | default = "",
  },
  #version | String,
}
in

let value = {
  artifacts | { _ : Schema } = {}
}
in

value
& {
  artifacts.foo.oci-image = {
    registry = "docker.io",
    namespace = "library",
    name = "nginx",
    tag = "v1"
  }
}
