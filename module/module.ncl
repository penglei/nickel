#let Nullable = fun contract label value =>
#  if value == null then
#    value
#  else
#    std.contract.apply contract label value
#in
#decorate the object to an ergonomic object.
let decorate = fun default_obj mixins =>
  std.array.fold_left (fun acc w => w.decorate acc) (if default_obj == null then {} else default_obj) mixins
in
let restore = fun fat_obj mixins =>
  std.array.fold_left (fun acc w => w.restore acc) fat_obj mixins
in
#transform add fragments to ergonomic object
let transform = fun ergonomic_obj fragments =>
  let fragments_overridable =
    std.array.map (fun f => if %typeof% f == 'Function then (f ergonomic_obj) else f) fragments
  in
  std.array.fold_left (&) ergonomic_obj fragments_overridable
in
let Mixin = {
  name | String,
  decorate | Dyn,
  restore | Dyn,
}
in
let ModuleObject = {
  Identifier | String,
  Schema | Dyn,
  ..
}
in
let Module = {
  object | ModuleObject | optional,
  mixins | Array Mixin | default = [],
  raw | Dyn | default = null,
  fragments | Array Dyn | default = [],
}
in
let rec Component = {
  name | String,
  modules | { _ : Module },
  origins | Array Component | default = [],
}
in

#build_ is the module mergence framework
let build_ | Module -> Dyn
  = fun m =>
    let object = m.object in
    let mixins = m.mixins in
    let raw = if m.raw == null then {} else m.raw in
    let fragments =
      #std.trace "build.fragments.length:%{std.to_string(std.array.length fragments)}"
      m.fragments
    in
    let result = restore (transform (decorate (raw | object.Schema) mixins) fragments) mixins
    in
    #std.trace
    #  "object: %{result.kind}/%{result.metadata.name}\n"
    result
  in

#XXX? module api
#create_ | Module -> Array Mixin -> Array Dyn -> ModuleEx
#rebase_ | ModuleEx -> Dyn -> ModuleEx
#evolve_ | ModuleEx -> Array Dyn -> ModuleEx
#enhance_ | ModuleEx -> Array Mixin -> ModuleEx
#bootstrap_create | Module -> ModuleEx
let remove_field = fun field record =>
  if std.record.has_field field record then
    std.record.remove field record
  else
    record
in
let merge_module_raws | Array Module -> Dyn
  = fun module_pieces_ =>
    let wrapper_raws =
      std.array.map
        (
          fun m =>
            #(std.trace "module fields: %{std.serialize 'Json (std.record.fields m)}" m)
            m
            |> remove_field "fragements"
            |> remove_field "object"
            |> remove_field "mixins"
        )
        (std.array.filter (fun m => std.record.has_field "raw" m && m.raw != null) module_pieces_)
    in
    let raw =
      if (std.array.length wrapper_raws) == 0 then
        null
      else
        (std.array.reduce_left (&) wrapper_raws).raw
    in
    #std.trace "selected raw: %{std.serialize 'Json raw}"
    raw
  in

#let ensure_same_module_raws | Array Module -> Dyn
#  = fun module_pieces_ =>
#    let cas_module_raws =
#      std.array.map
#        (
#          fun m =>
#            let text_ = std.serialize 'Yaml m.raw in
#            {
#              data = m.raw,
#              hash = std.hash 'Md5 text_,
#              text = text_,
#            }
#        )
#        #filter no raw
#        (std.array.filter (fun m => std.record.has_field "raw" m && m.raw != null) module_pieces_)
#    in
#
#    let uniq_raw =
#      (
#        std.array.reduce_left
#          (
#            fun first next =>
#              if first.hash == next.hash then
#                first
#              else
#                std.fail_with
#                  "The raw of two modules are different: \n%{std.serialize 'Json first.text}\n%{std.serialize 'Json next.text}"
#          )
#          cas_module_raws
#      ).data
#    in
#    uniq_raw
#  in

# compose_ merge multi module pieces together to a new module.
# 1. object定义只能有一个: 每个object都定义唯一的Identifier，如果增加包管理器，那么这个Identifier必需包含包名(可参考golang的设计)。
# 2. raw 只能有一份：计算raw的md5值识别唯一性
# 3. mixin 去重：mixin都定义了unique name
# 4. fragments 取并集
let compose_ | Array Module -> Module | std.array.NonEmpty -> Module
  = fun module_pieces_ =>
    let uniq_object = #first module object
      (
        std.array.reduce_left
          (
            fun first next =>
              if (std.record.has_field "object" first) == false || first.object == null then
                next
              else if (std.record.has_field "object" next) == false || next.object == null then
                first
              else if first.object.Identifier == next.object.Identifier then
                first
              else
                std.fail_with
                  "The object identifier of two modules are different: %{first.object.Identifier} %{next.object.Identifier}"
          )
          module_pieces_
      ).object
    in

    #let uniq_raw = ensure_same_module_raws module_pieces_ in
    let uniq_raw = merge_module_raws module_pieces_ in

    let distinct_mixins =
      std.array.fold_left
        (
          fun acc w =>
            if std.array.any (fun e => e.name == w.name) acc then
              acc
            else
              acc @ [w]
        )
        []
        (std.array.flat_map (fun m => m.mixins) module_pieces_)
    in

    let all_fragments = std.array.flat_map (fun m => m.fragments) module_pieces_ in
    #let all_fragments = std.trace "fragments: %{std.to_string (std.array.length all_fragments)}" all_fragments in
    {
      object = uniq_object,
      mixins = distinct_mixins,
      raw = uniq_raw,
      fragments = all_fragments,
    }
  in

#combine_ compose every component's module piece that distributing in each component gens.
let combine_ | Array Component -> Component
  = fun components =>
    if std.array.length components == 1 then
      std.array.first components
    else
      let all_module_names = std.array.flat_map (fun comp => std.record.fields comp.modules) components in
      let distinct_module_names =
        std.record.fields
          (std.array.fold_left (fun acc n => std.record.update n true acc) {} all_module_names)
      in
      let module_bindings =
        std.array.map
          (
            fun n =>
              let module_pieces_ =
                std.array.fold_left
                  (fun acc comp => acc @ (if std.record.has_field n comp.modules then [comp.modules."%{n}"] else []))
                  []
                  components
              in
              {
                field = n,
                value = compose_ module_pieces_,
              }
          )
          distinct_module_names
      in
      let comp_modules = std.record.from_array module_bindings in
      {
        name = "",
        modules = comp_modules,
        origins = [],
      }
  in

#define_
let define_ | String -> { _ : Module } -> Component
  = fun name_ modules_ =>
    {
      name = name_,
      modules = modules_,
      origins = [],
    }
  in

#derive_
let derive_ | String -> Dyn -> { _ : Module } -> Component
  = fun name_ ancestors_ modules_ =>
    let origins_ = if std.is_record ancestors_ then [ancestors_] else ancestors_ in
    {
      name = name_,
      modules = modules_,
      origins = origins_,
    }
  in
let TraverseState = {
  visited : { _ : Bool } | default = {},
  dependencies | Array Component | default = [],
}
in
let rec traverse_component | TraverseState -> Component -> TraverseState
  = fun state component =>
    if std.record.has_field component.name state.visited then
      #std.trace
      #  "the component has visited:%{component.name}"
      state
    else
      let newState =
        state
        |> std.record.update "visited" (std.record.update component.name true state.visited)
        |> std.record.update "dependencies" (state.dependencies @ [component])
      in
      std.array.fold_left
        #(fun s dep_comp => traverse_component s dep_comp)
        traverse_component
        newState
        component.origins
  in
let collect_components | Component -> Array Component
  = fun component =>
    (traverse_component TraverseState component).dependencies
  in

#export_ exports all modules in the component with defined order.
let export_ | Component -> Array String -> Array Dyn
  = fun component ordered_module_names =>
    let components = collect_components component in
    let virtual_component = combine_ components in
    std.array.map
      (fun name => build_ (virtual_component.modules."%{name}"))
      ordered_module_names
  in
{
  #合并module pieces成为最终的module
  compose = compose_,
  #build 将module 转换成可最终可输出的数据(主要是将离散的配置片段merge成一个配置)
  build = build_,

  #创建一个component
  define = define_,

  #从一些组件(component)衍生出一个新的component。
  derive = derive_,

  #按指定顺序导出component中所有module的最终配置
  export = export_,
}
