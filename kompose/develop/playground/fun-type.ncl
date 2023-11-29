#https://nickel-lang.org/user-manual/typing#using-contracts-as-types
let ArtifactRevision = {
  build_version | String | default = "",
  image_name | String | default = "",
  image_namespace | String | default = "",
  image_registry | String | default = "ccr.ccs.tencentyun.com",
  image_tag | String | default = "",
  vcs_branch | String | default = "",
  vcs_commit | String | default = "",
  vcs_source | String | default = "",
  vcs_tag | String | default = "",
  ..
}
in
let render
  | ArtifactRevision -> Dyn -> Dyn
  | doc "将CI的构建产物元数据转成配置元数据格式，以提供给组件使用"
  = fun values context =>
    let data = values in
    let artifact-metadata = {
      oci-image = {
        registry = "%{data.image_registry}",
        namespace = "%{data.image_namespace}",
        name = "%{data.image_name}",
        tag = "%{data.image_tag}",
        #e.g. ccr.ccs.tencentyun.com/khaos-platform/khaos-monitor:v1.5.2-g1234abcd
        repository = "%{data.image_registry}/%{data.image_namespace}/%{data.image_name}",
        reference = "%{repository}:%{data.image_tag}"
      },
      vcs = {
        source = "%{data.vcs_source}",
        commit = "%{data.vcs_commit}",
        tag = "%{data.vcs_tag}",
        branch = "%{data.vcs_branch}"
      },
      version = "%{data.build_version}",
    }
    in
    {
      "%{context.module}".fragments.values.artifact-metadata = artifact-metadata
    }
  in
render { build_version = "v1" } { module = "statesliceset" }
