let deep_update = fun fields content r =>
    let m = std.record.update in
    let rec update = fun fields content r =>
      if fields == [] then
        content
      else
        let k = std.array.first fields in
        r |> m k (update (std.array.split_at 1 fields).right content r."%{k}")
    in
    update fields content r
in

let Mender = {
  name | String,
  amend | Dyn,
  rectify | Dyn,
}
in

let ModuleObject = {
  Identifier | String,
  Schema | Dyn,
  Menders | Array Mender | default = [],
}
in
#Facet represents object partial.
let Facet = {
    fragment | Dyn, #rename to 'config' or 'partial' ?
    value | doc "input argument" | optional,
    demands | doc "demands argument" | optional, #must 'optional', we would check it by std.record.has_field, which would ignore "optional" field.
}
in
let Module = {
  type | ModuleObject | not_exported | optional, #schema and default
  objects | optional | default = [], #[{object = {..}}, ..]
  facets | Array Facet | default = [],
  inputs | doc "facet value parameter" | default = [], #[{input = ..}, {input = ..}]
  deps | doc "facet demands parameter" = {}, #params
  export : Bool | default = true,
}
in
let amend = fun default_obj menders =>
  std.array.fold_left
    (fun obj mender => mender.amend obj)
    default_obj
    #(if default_obj == null then {} else default_obj)
    menders
in
let rectify = fun facet menders =>
  std.array.fold_right
    (fun mender obj => mender.rectify obj)
    facet
    menders
in
let transform = fun ergonomic_obj facets vars deps =>
  let facets_overridable =
        std.array.map
          (match {
            x@{fragment, ..} => (
                if %typeof% fragment == 'Function then 
                    let vars_enjected_fragment = (vars & x).fragment in
                    x |> std.record.update "fragment" (vars_enjected_fragment ergonomic_obj)
                else
                    x
            ),
            x => x
           })
           facets
  in

  std.array.fold_left (&) ({ fragment = ergonomic_obj } ) (facets_overridable @ [{ demands = deps }, vars])
in

let eval_module | Module -> Dyn
  = fun m =>
    #let base_object =
    #    let wrapper = std.array.reduce_left (&) (m.objects @ [{demands = m.deps}]) in
    #    wrapper.object
    #in

    #let vars = std.array.reduce_left (&) (m.inputs @ [{input = {}, value = input}]) in

    let base_object = m.objects in

    let menders = m.type.Menders in

    let result =
        rectify #finally, convert back to correct format.
          #(transform #then do real modification in easy format.
            (amend (base_object | m.type.Schema) menders) #first we must do amend
            #m.facets
            #vars
            #m.deps
          #)
          menders
    in
    (result | m.type.Schema)
    #result
in

let mender0 = {
    name = "container-mender-helper",
    amend = fun obj =>
        obj & {
            namedContainers = obj.containers
        },
    rectify = fun obj =>
        let named_containers = obj.namedContainers in
        let obj = obj |> std.record.remove "namedContainers"  in
        obj & {containers | priority 1 = named_containers}

}
in

let mender1 = {
    name = "container-mender-helper",
    amend = fun obj =>
        obj & {
            spec.namedContainers = obj.spec.containers
        },
    rectify = fun obj => 
        let named_containers = obj.spec.namedContainers in
        let obj =
                obj |> std.record.update "spec"
                        (obj.spec |> std.record.remove "namedContainers")  in
        obj & {spec = {containers | priority 1 = named_containers}}

}
in
let mender1a = {
    name = "container-mender-helper",
    amend = fun obj =>
        deep_update ["spec", "namedContainers"] obj.spec.containers obj,
    rectify = fun obj => 
        let named_containers = obj.spec.namedContainers in
        let obj =
                obj |> std.record.update "spec"
                        (obj.spec |> std.record.remove "namedContainers")  in
        deep_update ["spec", "containers"] named_containers obj

}

in
let mender2 = {
  name = "mender-workload-named-containers",
  amend = fun workload =>
    let containers = workload.spec.containers in
    let named_containers =
      std.array.fold_left (fun acc c => std.record.insert c.name c acc) {} containers
    in
    let ergonomy =
      workload
      & {
        spec = {
          #clean as we have transfer containers to namedContainers, which would restore in the rectify method.
          containers | priority 10 = [],

          namedContainers = named_containers,
        }
      }
    in ergonomy,

  #rectify 将namedContainers还原成List Container.
  rectify = fun workload =>
    let named_containers = workload.spec.namedContainers in
    let workload =
      deep_update
        ["spec"]
        (
          workload.spec.template.spec |> std.record.remove "namedContainers"
        )
        workload
    in

    workload
    & {
      spec = {
        #namedContainers | not_exported | priority 1000 = null,
        containers | priority 1000 =
            std.array.filter
              (fun c => c != null)
              (std.record.values named_containers)
      }
    }
}

in

let Container = {
    name | String,
    image | String | optional
}
in
let DeploymentSpec0 = {
    containers | Array Container
}
in
let DeploymentSpec1 = {
    spec | {
        containers | Array Container
    }
}
in
let Deployment = {
  Identifier = "apps/v1:Deployment",
  Schema = DeploymentSpec1,
  Menders = [
    mender1a
  ],
} in


eval_module {
    type = Deployment,
    objects = (import "./deployment.yaml").type1,
}

