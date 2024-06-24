let show_fields = fun r => std.serialize 'Json (std.record.fields r) in
let show_typeof = fun x => std.to_string (std.typeof x) in
let trace_fields = fun label r => std.trace "%{label}: %{show_fields r}" r in
let show_string = fun r => std.serialize 'Json r in
let show_length = fun r => show_string (std.array.length r) in

let std_trace = fun show value => if false then std.trace show value else value in

####################### module #################################
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
  Fragments | Array Dyn | default = [],
}
in

#Facet wraps object fragment with input value and demand deps.
let Facet = {
  fragment | Dyn,
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
  hidden : Bool | default = false,
}
in

let TreeMeta = {
  order : Array String | default = [], # this field only affect tree nodes, but doesn't leaves.
  inputs | not_exported | Array Dyn | default = [],
  disabled | Bool | default = false, # We don't refer to use this field, but require it to make dinstict with others while do merge.
  hidden | Bool | default = false,
}
in

#LazyTree represents AST for component merge operation
let rec LazyTree = [|
  'Meta TreeMeta,
  'In { input | Dyn | default = {}, value | Dyn | optional },
  'C {
    meta : TreeMeta,
    data
      : {
        _ : Array {
          # we must distinct "input" with "normal" configuration, because we should prepare
          # input values before do real merge. And the input values would be provided to
          # final merge operation.
          class | String | default = "CM", #CM, R, IN
          value | not_exported | default = {},
          self | LazyTree, #为了支持literal disable. (enable_if)
        }
      }
  },
  'M (Array Module),
  'Ref { value | optional, self | Dyn } #为了支持可组合的disable. (disable_if)
  ,
|]
in
let Disabled =
  'C {
    meta = { disabled = true } | TreeMeta,
    data = {},
  }
in
let enable_if = fun enable x => if enable then x else null in
let disable_if = fun x => if x then null else {} in
let NewC = fun x => ('C x) in
let NewM = fun x => ('M x) in
let NewMt = fun x => ('Meta x) in
let NewRef = fun x => ('Ref x) in
let DataNode = { class | String | default = "CM", self | LazyTree, value | default = {} } in
let unwrap = match {
  'C a => { kind = 1, x = a },
  'M a => { kind = 2, x = a },
  'In a => { kind = 3, x = a },
  'Meta a => { kind = 4, x = a },
  'Ref a => { kind = 5, x = a },
  a => { kind = 0, x = a },
}
in
let tree_class = match {
  'In i => "IN",
  'Ref i => "R",
  'Meta i => "META",
  'C i => "CM",
  'M i => "CM",
}
in
let make_data_node = fun c => { class = tree_class c, self = c } in

#Tree is simplified LazyTree, which leaf is un-merged Module.
let rec Tree = [|
  'C {
    meta : TreeMeta,
    data : { _ : Tree }
  },
  'M {
    meta = {},
    data | Dyn
  },
|]
in
######### utils #############
let rupdate = std.record.update in
let not = fun f => fun x => !(f x) in
let compose = fun f g => fun x => f (g x) in
let first_field_name = fun r => std.array.first (std.record.fields r) in
let first_field = fun r => std.record.get (first_field_name r) r
in
let array_concat_merge : Array String -> Array String -> Array String
  = fun arr1 arr2 =>
    #this impl is incorrect! we should do it by topology sort(becareful how to find root vertices)
    arr1 @ (std.array.filter (fun s => !(std.array.elem (s | Dyn) (arr1 | Array Dyn))) arr2)
  in
let remove_field : String -> { _ : Dyn } -> { _ : Dyn }
  = fun field record =>
    if std.record.has_field field record then std.record.remove field record else record
  in
let field_eq = fun field value d => std.record.has_field field d && d."%{field}" == value
in
let sort_by | Array String -> Array String -> Array String
  = fun order keys =>
    let cache =
      std.array.fold_left
        (
          fun acc k =>
            let _sorts = rupdate k acc.order acc.sorts in
            let _order = acc.order + 1 in
            {
              sorts = _sorts,
              order = _order,
            }
        )
        { sorts = {}, order = 0 }
        order
    in
    let order = cache.order + 1 in
    std.array.sort
      (
        fun k1 k2 =>
          let k1order = if std.record.has_field k1 cache.sorts then cache.sorts."%{k1}" else order in
          let k2order = if std.record.has_field k2 cache.sorts then cache.sorts."%{k2}" else order in
          if k1order < k2order then
            'Lesser
          else if k1order > k2order then
            'Greater
          else
            'Equal
      )
      keys
  in
let join_routes = std.string.join "." in
let show_routes = fun routes => join_routes (std.array.split_at 1 routes).right in
let rec paths_to_tree | Array String -> Dyn
  = fun keys =>
    if std.array.length keys == 0 then
      {}
    else
      let k = std.array.first keys in
      let subdict = paths_to_tree (std.array.drop_first keys) in
      if std.record.is_empty subdict then
        { "%{k}" | force = subdict } | Dyn
      else
        { "%{k}" = subdict } | Dyn
  in
let rec make_record = fun seps target =>
  std.array.fold_right (fun key acc => { "%{key}" = acc }) target seps
in
let topology-sort = fun graph_adjacency_list =>
  let rec dfs_visit = fun ctx elem =>
    let visited = std.record.has_field elem ctx.visited in
    if visited then
      ctx
    else
      let ctx = ctx |> rupdate "visited" (ctx.visited |> rupdate elem true) in
      let deps = graph_adjacency_list."%{elem}" in
      if deps == [] then
        ctx |> rupdate "sorts" (ctx.sorts @ [elem])
      else
        let ctx = std.array.fold_left (dfs_visit) ctx deps in
        ctx |> rupdate "sorts" (ctx.sorts @ [elem])
  in
  let result = std.array.fold_left (dfs_visit) { sorts = [], visited = {} } (std.record.fields graph_adjacency_list)
  in
  result.sorts
in

#tree_paths accumulates all leaves path from tree root.
#If the tree is leaf, get_subtree_names must return empty.
let rec tree_paths #| Dyn(fun) -> Dyn(fun) -> Dyn(fun) -> Dyn -> Array (Array String)
= fun get_subtree_names downward termop tree =>
  std.array.flat_map
    (
      fun name =>
        let is_leaf = termop name tree in
        if is_leaf then
          [[name]]
        else
          std.array.map
            (fun ps => [name] @ ps)
            (tree_paths get_subtree_names downward termop (downward name tree))
    )
    (get_subtree_names tree) #
in
let record_field = fun name tree => tree."%{name}" in
let is_empty_leaf = fun name tree => tree."%{name}" == {} in
let record_tree_paths =
  tree_paths
    std.record.fields
    (record_field)
    is_empty_leaf
in

###########debug############
let show_lazy_tree #LazyTree|Array LazyTree -> Dyn
= fun sth =>
  let rec visit = fun tree =>
    match {
      'In i => i,
      'Meta meta => meta,
      'C c =>
        let data_ =
          std.record.map_values
            (
              fun farr =>
                std.array.map
                  (fun node => { class = node.class, self = (visit node.self) })
                  farr
            )
            c.data
        in
        c |> rupdate "data" data_,
      'M ms => std.array.map (fun m => m |> remove_field "type") ms,
      'Ref r => ["<Ref node can't show detail. {%{std.string.join "," (std.record.fields r)}}>"]
    }
      tree
  #(std.trace "show_lazy_tree matching:%{show_typeof tree}" tree)
  in
  if std.is_array sth then
    std.array.map visit sth
  else
    visit sth
in

let show_tree = fun tree =>
  let rec visit = fun tree =>
    match {
      'C c => c |> rupdate "data" (std.record.map_values visit c.data),
      'M m => m,
      _ => std.fail_with "not tree",
    }
      tree
  in
  visit tree
in
############################
let amend = fun default_obj menders =>
  std.array.fold_left
    (fun obj mender => mender.amend obj)
    (if default_obj == null then {} else default_obj)
    menders
in
let rectify = fun facet menders =>
  std.array.fold_right
    (fun mender obj => mender.rectify obj)
    facet.fragment
    menders
in
#transform overrides object by fragment function
let transform = fun ergonomic_obj facets vars deps =>
  #let facets_overridable =
  #  std.array.map
  #    (
  #      fun facet =>
  #        let facet_injected = facet & vars in
  #        if %typeof% facet_injected.fragment == 'Function then
  #          facet_injected |> rupdate "fragment" (facet_injected.fragment ergonomic_obj)
  #        else
  #          facet_injected
  #    )
  #    facets
  #in
  #std.array.fold_left (&) ({ fragment = ergonomic_obj }) (facets_overridable @ [{ demands = deps }])
  let typed_facets =
    std.array.fold_left
      (
        fun acc facet =>
          let facet_injected = facet & vars in
          if std.is_function facet_injected.fragment then
            acc |> rupdate "overrides" (acc.overrides @ [facet_injected])
          else
            acc |> rupdate "merges" (acc.merges @ [facet_injected])
      )
      {
        overrides = [],
        merges = [],
      }
      facets
  in

  let merged_ergonomic_obj = std.record.merge_all (typed_facets.merges @ [{ fragment = ergonomic_obj }]) in
  let overrides = std.array.map (fun facet => facet |> rupdate "fragment" (facet.fragment (merged_ergonomic_obj.fragment))) typed_facets.overrides in
  std.record.merge_all ([merged_ergonomic_obj] @ overrides @ [{ demands = deps }])
in

let eval_module | Module -> Dyn
  = fun m =>
    let base_object =
      let wrapper = std.array.reduce_left (&) (m.objects @ [{ demands = m.deps }]) in
      wrapper.object
    in

    let vars = std.array.reduce_left (&) (m.inputs @ [{ input = {}, value = input }]) in

    let menders = m.type.Menders in

    let builtin_fragments = m.type.Fragments in
    let facets = builtin_fragments @ m.facets in # run internal fragments before others
    let result =
      rectify #finally, convert back to correct format.
        (
          transform #then do real modification in easy format.
            (amend (base_object | m.type.Schema) menders) #first we must do amend
            facets
            vars
            m.deps
        )
        menders
    in
    (result | m.type.Schema)
  in
######## constructor ###########
let meta_field_key = "@meta" in

let flatten_def #| Dyn -> Array Dyn -> Array Dyn
= fun cb arr =>
  let rec deepflatmap = fun acc x =>
    if std.is_array x then
      std.array.fold_left deepflatmap acc x
    else
      acc @ [cb x]
  in
  deepflatmap [] arr
in

# define envelop literal record as LazyTree
let define | Dyn -> Array LazyTree
  = fun sth =>
    let rec def | Dyn -> LazyTree
      = fun sth =>
        let def_record = fun meta_ defs_ =>
          match {
            x @ { type, object, fragments ? [], demands ? null } =>
              #module definition api
              'M [
                {
                  type = x.type,
                  objects =
                    let object_wrapper =
                      # shadow merge object to preserve 'object' field priority: each 'object' in a module is an atomic field.
                      # "demands" also are preserved.
                      x
                      |> remove_field "type"
                      |> remove_field "fragments"
                    in [object_wrapper],
                  facets =
                    std.array.map
                      (
                        fun f =>
                          match {
                            { fragment, value ? null } => f,
                            _ => { fragment = f }, #default is fragment
                          }
                            f
                      )
                      fragments,
                  hidden = meta_.hidden,
                }
              ],
            x @ { fragment, value ? null, demands ? null } =>
              ('M [{ facets = [x], hidden = meta_.hidden }]),
            x @ { value } =>
              #('M [{ facets = [x], hidden = meta_.hidden }]),
              'In x,
            x @ { input, value ? null } => 'In x #input values api.
            ,
            x @ { self, value ? null } =>
              #Becareful, the 'self' field is not defined as LazyTree here,
              #which would be defined when do shallow merge operation in the later stage2.
              (NewRef x),
            x =>
              (
                let children =
                  std.array.fold_left
                    (
                      fun acc { field, value } =>
                        if value == {} || value == [] then
                          acc
                        else
                          let child_segs =
                            let trees = flatten_def def (if std.is_array value then value else [value]) in
                            std.array.map make_data_node trees
                          in
                          acc |> std.record.insert field child_segs
                    )
                    {}
                    (std.record.to_array x)
                in
                (NewC { meta = meta_, data = children })
              ),
          }
            defs_
        in

        match {
          'M i => sth,
          'C i => sth,
          'In i => sth,
          'Ref i => sth,
          'Meta i => sth,
          x =>
            if std.is_record x then
              if std.record.has_field meta_field_key x then
                let defs_ = x |> std.record.remove meta_field_key in
                if defs_ == {} then
                  #For now we still has no informertion about into what's the tree node type will be to merged,
                  #so we must mark it as meta and do merge lazily in the shallow merge stage.
                  NewMt x."%{meta_field_key}"
                else
                  def_record x."%{meta_field_key}" defs_
              else
                def_record TreeMeta x
            else
              std.fail_with "unknown define: %{show_string x}:%{show_typeof x}",
        }
          sth
      in

    if sth == [] || sth == {} then
      []
    else if std.is_array sth then
      flatten_def def sth
    else
      [def sth]
  in

#merge stage1 will combine multiple components into one virtual root component
let merge_stage1 | Array LazyTree -> LazyTree
  = fun trees =>
    (
      'C {
        meta = {},
        data."__root__" = std.array.map make_data_node trees
      }
    )
  in

#stage2 will narrow LazyTree
let merge_stage2 | LazyTree -> LazyTree
  = fun tree =>
    #merge_op will reduce on trees, so it must has the shape 'X->X->X'
    let merge_op | { self | LazyTree, .. } -> { self | LazyTree, .. } -> DataNode
      = fun c1 c2 =>
        let c1wrapper = unwrap c1.self in
        let c2wrapper = unwrap c2.self in
        if c1wrapper.kind == c2wrapper.kind then
          if c1wrapper.kind == 1 then
            let meta1 = c1wrapper.x.meta in
            let meta2 = c2wrapper.x.meta in
            let meta_ = {
              order = array_concat_merge meta1.order meta2.order,

              #XXX how can we do override: key in the nearest input should override that in the ctx inputs?
              inputs = (meta1.inputs @ meta2.inputs),

              hidden = meta1.hidden || meta2.hidden,
            }
            in

            let data1 = c1wrapper.x.data in
            let data2 = c2wrapper.x.data in

            #let data1 = std.trace "data1 fields:%{show_fields data1}" data1 in
            #let data2 = std.trace "data2 fields:%{show_fields data2}"data2 in
            let data_ =
              std.array.fold_left
                (
                  fun acc { field, value } =>
                    let this_comps = if std.record.has_field field acc then acc."%{field}" else [] in
                    let value = (this_comps @ value) in
                    acc |> rupdate field value
                )
                data1
                (std.record.to_array data2)
            in
            {
              class = "CM",
              self =
                NewC
                  {
                    meta = meta_,
                    data = data_,
                  },
            }
          else if c1wrapper.kind == 2 then
            {
              class = "CM",
              self = NewM (c1wrapper.x @ c2wrapper.x)
            }
          else
            std.fail_with
              (
                "can't merge: \nkind=%{std.to_string c1wrapper.kind}:%{show_string c1wrapper.x}"
                ++ ",\nkind=%{std.to_string c2wrapper.kind}:%{show_string c2wrapper.x}"
              )
        else if c1wrapper.kind == 4 then
          std.fail_with "can't reduce on 'Meta left"
        else if c2wrapper.kind == 4 then
          if c1wrapper.kind == 1 then
            let meta1 = c1wrapper.x.meta in
            let meta2 = c2wrapper.x in
            let meta_ = {
              order = array_concat_merge meta1.order meta2.order,
              #XXX how can we do override: key in the nearest input should override that in the ctx inputs?
              inputs = (meta1.inputs @ meta2.inputs),
              hidden = meta1.hidden || meta2.hidden,
            }
            in

            {
              class = "CM",
              self =
                NewC
                  {
                    meta = meta_,
                    data = c1wrapper.x.data,
                  }
            }
          else if c1wrapper.kind == 2 then
            let meta2_ = c2wrapper.x in
            {
              class = "CM",
              self = NewM (c1wrapper.x @ [{ hidden = meta2_.hidden, inputs = meta2_.inputs }])
            }
          else
            std.fail_with
              ("can't merge Meta into kind:%{std.to_string c1wrapper.kind}")
        else
          #Explain: Why 'c1' is not stringable but std.to_string is called on it?
          #         It is for debugging, which would  trigger panic and then show traceback.
          #std.seq "can't merge component node: %{std.to_string c1}"
          std.fail_with
            (
              "can't merge two incompatible tree nodes: [%{std.to_string c1wrapper.kind}"
              ++ ", %{std.to_string c2wrapper.kind}]"
            )
      in

    let shallow_merge_modules | Dyn -> Array Module -> Module
      = fun ctx modules =>
        let uniq_type =
          let types = (std.array.filter (fun m => std.record.has_field "type" m && m.type != {}) modules) in
          if types == [] then
            std.fail_with "object(%{show_routes ctx.routes}) has no 'type' attribute, maybe you misspelled component path"
          else
            (std.array.first types).type
        in
        ##Do we need merge or/and dinstict menders in type definition?
        #let uniq_type.Menders = distinct_menders in

        # shallow merge objects to preserve 'object' field priority: each 'object' in a module is an atomic field.
        let all_objects =
          std.array.flat_map
            (
              fun m =>
                let m =
                  m
                  |> remove_field "type"
                  |> remove_field "facets"
                  |> remove_field "inputs"
                in
                m.objects
            )
            (std.array.filter (fun m => std.record.has_field "objects" m) modules)
        in

        let inputs_ = std.array.fold_left (fun acc m => acc @ m.inputs) ctx.inputs modules in

        let facets_ = std.array.flat_map (fun m => m.facets) modules in

        let hidden_ = std.array.fold_left (fun hidden m => m.hidden || hidden) false modules in

        let merged_module =
          {
            type = uniq_type,
            objects = all_objects,
            facets = facets_,
            inputs = inputs_,
            hidden = hidden_,
          } | Module
        in
        merged_module
      in

    let check_disable #| Array {self|LazyTree, ..} -> Bool
    = fun nodes =>
      std.array.fold_left
        (fun disabled n => disabled || n.self == Disabled || n.self == null)
        false
        nodes
    in
    let filter_input = fun x => field_eq "class" "IN" x in
    let filter_ref = fun x => field_eq "class" "R" x in
    let filter_meta = fun x => field_eq "class" "META" x in
    let filter_cm = fun x => field_eq "class" "CM" x in
    let show_nodes = fun nodes => show_string (std.array.map (fun n => [n.class, (unwrap n.self).kind]) nodes) in

    let shallow_merge_subtrees #| Dyn -> {_ : Array DataNode} -> Dyn -> {_ : Array DataNode}
    = fun ctx data cont_traverse =>
      #let data = std.trace "shallow merge data fields:%{show_fields data}" data in
      #shallow merge children
      std.array.fold_left #It's custom record map values. We want to track the field name in context.
        # every subtree should do deep merge
        (
          fun acc { field, value } => #| { field : String, value : Array DataNode }
            #let field = std.trace "merge the field:%{field}" field in
            if value == [] then
              acc
            else
              let field_nodes = value in
              let inputs_ =
                std.array.map
                  (fun { self = 'In input, .. } => input)
                  (std.array.filter filter_input field_nodes)
              in
              let inputs = ctx.inputs @ inputs_ in
              let ctx =
                ctx
                |> rupdate "inputs" inputs
                |> rupdate "routes" (ctx.routes @ [field])
              in
              let the_routes = "[%{show_routes ctx.routes}]" in

              let inputs_as_value = std.record.merge_all (inputs @ [{ input, value = input }]) in

              let meta_nodes = std.array.filter filter_meta field_nodes in
              let ref_nodes = std.array.filter filter_ref field_nodes in
              let cm_nodes = std.array.filter filter_cm field_nodes in

              #let settled_cm_nodes = std.array.map (fun n => n & inputs_as_value) cm_nodes in
              let settled_cm_nodes = cm_nodes in

              # sub tree can be 'Disabled', so we must check it
              let child_disabled = (check_disable settled_cm_nodes) in
              if child_disabled then
                #in-completeness, lazy node is checking in the bellow
                std_trace
                  "!!'%{show_routes ctx.routes}' disabled!!"
                  acc
              else
                # ref nodes 延迟定义，需要define之后进行lift。
                # 注意我们只lift一次，不支持lift `{self.self.self=...}` 到当前层级，这种写法
                #没有实际意义，却会明显增加shallow merge的实现复杂度：需要在保持context的情况
                #下进行递归define。
                let settled_ref_nodes = std.array.map (fun n => n & inputs_as_value) ref_nodes in
                let lazy_def_trees = (
                  std.array.flat_map
                    (
                      fun n =>
                        let ref = n.self in
                        let wref = (unwrap ref) in
                        let setteld_node = wref.x & inputs_as_value in
                        let def = setteld_node.self in

                        #support use null to disable lazytree
                        if def == null then
                          [Disabled]
                        else
                          (define def)
                    )
                    settled_ref_nodes
                )
                in

                let lazy_nodes = std.array.map make_data_node lazy_def_trees in
                #lazy_nodes is usually empty. If it's not,
                #we must check disable by explicit value 'Disabled', not empty value!
                if check_disable lazy_nodes then
                  std_trace
                    "!!'%{show_routes ctx.routes}' disabled(lazy)!!"
                    acc
                else
                  let nodes = settled_cm_nodes @ lazy_nodes @ meta_nodes in

                  let determined_head_nodes =
                    let ctx_inputs_as_metanode = make_data_node (NewMt { inputs = ctx.inputs }) in
                    #meta nodes must behind the 'primary' nodes,
                    #or we can't determine into what the primary node type to merge for meta node.
                    (nodes @ [ctx_inputs_as_metanode])
                  in
                  if std.array.length nodes == 0 then
                    #only contains inputs, ignore
                    acc
                  else
                    let child_datanode = std.array.reduce_left merge_op determined_head_nodes in

                    #drill down to descendant
                    let self_ = child_datanode.self in

                    #make_data_node?
                    let child = { class = "CM", self = cont_traverse ctx self_ } in

                    acc |> rupdate field [child]
        )
        {}
        (std.record.to_array data)
    in

    let rec traverse_merge | Dyn -> LazyTree -> LazyTree
      = fun ctx tree =>
        let cwrapper = unwrap tree in
        if cwrapper.kind == 1 then
          let children = shallow_merge_subtrees ctx cwrapper.x.data traverse_merge in
          NewC
            {
              meta = cwrapper.x.meta,
              data = children
            }
        else if cwrapper.kind == 2 then
          NewM [(shallow_merge_modules ctx cwrapper.x)]
        else
          std.fail_with "can't do deep narrow, merge is impossible:%{show_string cwrapper}}"
      in

    let ctx = { routes = [], inputs = [{ input = {} }] } in
    traverse_merge ctx tree
  in

let ContextModuleMeta = {
  name = std.string.join "." routes,
  routes | Array String | default = [],
  hidden : Bool | default = false,
  disabled | Bool | default = false,
  demands, #local demands declare -> module demand full routes
  demands_routes | default = {},
}
in

let DepGraph = {
  edges : { _ : Array String } | default = {},
  vertices
    | { _ : ContextModuleMeta }
    | default
    = {},
}
in

#merge_stage3_simplify will convert narrowed LazyTree to Tree
let merge_stage3_simplify | LazyTree -> Tree
  = fun tree =>
    let rec simplify | Dyn -> LazyTree -> Tree
      = fun routes lazytree =>
        match {
          'C c =>
            NewC
              {
                meta = { order = c.meta.order, hidden = c.meta.hidden },
                data =
                  std.record.map
                    (
                      fun field value =>
                        let child = (std.array.first value) in
                        simplify (routes @ [field]) child.self
                    )
                    c.data
              },
          'M x =>
            let m = std.array.first x in
            let demands_ =
              std.array.fold_left
                (
                  fun acc i =>
                    if std.record.has_field "demands" i then
                      (i.demands & acc)
                    else
                      acc
                )
                {}
                (m.facets @ m.objects)
            in
            let routes_ = routes in
            NewM
              {
                meta =
                  {
                    routes = routes_,
                    demands = demands_,
                    hidden = m.hidden,
                  } | ContextModuleMeta,
                data = m,
              },
        }
          lazytree
      in
    simplify [] tree
  in

let merge_stage4_parse_dep_graph | Tree -> DepGraph
  = fun tree =>
    let rec find_env = fun name env =>
      if env == null then
        null
      else if std.record.has_field name (unwrap env.subtree).x.data then
        env
      else
        find_env name env.parent
    in
    let find_subtree #same as get_leaf_module ?
    = fun routes_ tree =>
      let rec drilldown = fun routes tree =>
        if routes == [] then
          tree
        else
          let n = unwrap (tree) in
          if n.kind == 1 then
            let key = std.array.first routes in
            let routes = (std.array.split_at 1 routes).right in
            drilldown routes n.x.data."%{key}"
          else
            std.fail_with "can't find the subtree:%{show_routes routes_} at %{show_routes routes}"
      in
      drilldown routes_ tree
    in
    let rec go | Dyn -> Tree -> DepGraph
      = fun ctx tree =>
        match {
          'C c =>
            let newenv = {
              parent = ctx.env,
              subtree = tree,
              routes = ctx.routes,
            }
            in
            std.array.fold_left
              (
                fun acc { field, value } =>
                  let routes_ = ctx.routes @ [field] in
                  let ctx = {
                    env = newenv,
                    routes = routes_,
                  }
                  in
                  let child_graph = go ctx value in
                  acc & child_graph
              )
              {}
              (std.record.to_array c.data),
          'M m =>
            let local_demands = m.meta.demands in
            #let local_demands = std.trace "depgraph, local_demands:%{show_string local_demands}" local_demands in
            let local_dep_paths = record_tree_paths local_demands in

            let demand_envs = std.record.map (fun head_var_name _v => find_env head_var_name ctx.env) local_demands in

            let demands_routes =
              std.record.values
                (
                  std.record.map
                    (fun head_var_name env => env.routes @ [head_var_name])
                    demand_envs
                )
            in

            let dep_full_tree =
              std.array.fold_left
                (
                  fun acc demand => #demand is local routes
                    let head_var_name = std.array.first demand in

                    let env = demand_envs."%{head_var_name}" in
                    #let env = std.trace "env.routes:%{show_string env.routes}" env in
                    if env == null then
                      std.fail_with "can't find demand head :%{show_routes demand}"
                    else
                      let demand_tree = find_subtree demand env.subtree in
                      #let demand_tree = std.trace "demand_tree.meta:%{show_string (unwrap demand_tree).x.meta}" demand_tree in
                      let demand_module_routes =
                        tree_paths
                          (
                            fun tree => #get children names
                              let t = unwrap tree in
                              if t.kind == 1 then
                                let data = t.x.data in
                                std.record.fields data
                              else
                                []
                          )
                          (fun name tree => (unwrap tree).x.data."%{name}") #downward
                          (
                            fun name tree => #terminate
                              let kind = (unwrap ((unwrap tree).x.data."%{name}")).kind in
                              kind == 2
                          )
                          demand_tree
                      in

                      if demand_module_routes == [] then
                        #depend on module (tree leaf)
                        acc & (make_record (env.routes @ demand) {})
                      else
                        std.array.fold_left
                          (fun acc subroutes => acc & (make_record (env.routes @ demand @ subroutes) {}))
                          acc
                          demand_module_routes
                )
                {}
                local_dep_paths
            in

            let dep_tree_routes = record_tree_paths dep_full_tree in

            let name = m.meta.name in
            {
              edges = { "%{name}" = std.array.map join_routes dep_tree_routes },
              vertices = {
                "%{name}" =
                  m.meta
                  |> rupdate "demands" dep_full_tree
                  |> rupdate "demands_routes" demands_routes
              },
            },
        }
          tree
      in
    let ctx = {
      env = {
        parent = null,
        subtree = tree,
        routes = [],
      },
      routes = [],
    }
    in
    go ctx tree
  in

let tree_project = fun mask tree =>
  let rec visit = fun trace_routes mask tree =>
    if mask == {} then
      tree
    else
      std.array.fold_left
        (
          fun acc { field, value } =>
            let trace_routes = trace_routes @ [field] in
            if std.record.has_field field tree then
              if !(std.is_record tree."%{field}") && (std.is_record value && value != {}) then
                std.fail_with
                  "can't drill down to project the field: %{show_routes trace_routes}"
                ++ ", because the mask field shape is different from the tree field"
              else
                acc |> rupdate field (visit trace_routes value tree."%{field}")
            else
              std.fail_with "can't find field:%{field}"
        )
        {}
        (std.record.to_array mask)
  in
  visit [] mask tree
in

let tree_filter | Dyn -> Array (Array String) -> Dyn
  = fun tree paths =>
    std.record.merge_all
      (
        std.array.map
          (
            fun paths =>
              let name = std.array.last paths in
              {
                "%{name}" = std.array.fold_left (fun acc k => acc."%{k}") tree paths
              }
          )
          paths
      )
  in

#merge_stage5_force 把tree合并成最终的record，record的叶子节点是合并后的module
let merge_stage5_force | Dyn -> Tree -> DepGraph -> Dyn
  = fun wrapper tree graph =>
    let ordered_modules = topology-sort graph.edges in
    let ordered_modules_meta =
      std.array.map
        (fun name_ => graph.vertices."%{name_}")
        ordered_modules
    in

    let rec get_leaf_module | Tree -> Array String -> { meta | Dyn, data | Module }
      = fun tree routes =>
        if routes == [] then
          let m = (unwrap tree).x in
          m
        else
          let key = std.array.first routes in
          let routes = (std.array.split_at 1 routes).right in
          let x = (unwrap tree).x.data in
          get_leaf_module x."%{key}" routes
      in
    let result =
      std.array.fold_left
        (
          fun acc meta =>
            #let meta = std.trace "demand_route:%{show_string meta.demands}" meta in
            #let meta = std.trace "routes:%{show_string meta.routes}" meta in
            let routes = meta.routes in

            let demand_route = meta.demands in #e.g. {__root__.a.b = {}}
            let deps =
              if demand_route == {} then
                #std.trace "no demands"
                {}
              else
                let full_route_deps = tree_project demand_route acc in
                let demands_routes = meta.demands_routes in
                #let demands_routes = std.trace "demands_routes:%{show_string demands_routes}" demands_routes in
                let demands_from_deps = tree_filter full_route_deps demands_routes in
                #let demands_from_deps = std.trace ("demands_from_deps:%{show_string demands_from_deps}") demands_from_deps in
                demands_from_deps
            in
            #let deps = std.trace "deps: %{show_string deps}" deps in
            let m = get_leaf_module tree routes in
            let lazy_module =
              m.data
              |> rupdate "deps" deps
            in

            let data = eval_module lazy_module in
            let data = wrapper data in
            acc & (make_record routes data)
        )
        {}
        ordered_modules_meta
    in
    result
  in

let rec visit_tree = fun ctx acc tree result =>
  let make_sub_acc = fun key sub_acc =>
    if acc.depth == 0 then
      sub_acc
      |> rupdate "path_key" acc.path_key
      |> rupdate "path" acc.path
    else
      sub_acc
      |> rupdate "path_key" (if acc.path_key == "" then key else (std.string.join "/" [acc.path_key, key]))
      |> rupdate "path" (acc.path @ [key])
      |> rupdate "depth" (acc.depth - 1)
  in

  let go_select_subtree = fun c ordered_keys =>
    let export_all = std.record.has_field "*" ctx.selection in
    let export_keys =
      std.array.filter
        (fun i => i.visible)
        (
          std.array.map
            (
              fun k =>
                let specified = std.record.has_field k ctx.selection in
                {
                  key = k,
                  visible = export_all || specified,
                  subselection =
                    if visible then
                      if export_all && specified then
                        #merge sub selection strategy
                        let s_all = ctx.selection."*" in
                        let s_k = ctx.selection."%{k}" in
                        if (std.is_bool s_all && s_all == true)
                        || (std.is_bool s_k && s_k == true) then
                          true
                        else
                          s_all & s_k
                      else if export_all then
                        let s_all = ctx.selection."*" in
                        if (std.is_bool s_all && s_all == true) then true else s_all
                      else if specified then
                        let s_k = ctx.selection."%{k}" in
                        if (std.is_bool s_k && s_k == true) then true else s_k
                      else
                        {} #export nothing for the child
                    else
                      {}
                }
            )
            ordered_keys
        )
    in

    std.array.fold_left
      (
        fun sub_acc w =>
          let key = w.key in
          let t = c.data."%{key}" in

          let sub_ctx = (
            if std.is_bool w.subselection && w.subselection == true then
              ctx
              |> rupdate "slow_select" false
              |> rupdate "selection" w.subselection
            else
              ctx |> rupdate "selection" w.subselection
          )
          in

          let sub_acc = make_sub_acc key sub_acc in

          visit_tree sub_ctx sub_acc t result."%{key}"
      )
      acc
      (export_keys)
  in

  match {
    'C c =>
      if !c.meta.hidden && !c.meta.disabled then
        let ordered_keys = sort_by c.meta.order (std.record.fields c.data) in

        if ctx.slow_select then
          go_select_subtree c ordered_keys
        else
          std.array.fold_left
            (
              fun sub_acc key =>
                let t = c.data."%{key}" in

                let sub_acc = make_sub_acc key sub_acc in
                visit_tree ctx sub_acc t result."%{key}"
            )
            acc
            (ordered_keys)
      else
        acc,
    'M m =>
      if !m.meta.hidden && !m.meta.disabled then
        let p = acc.path_key in
        let pcollect = {
          objs =
            if std.record.has_field p acc.collects then
              acc.collects."%{p}".objs @ [result]
            else
              [result],

          path = acc.path,
        }
        in
        acc |> rupdate "collects" (rupdate p pcollect acc.collects)
      else
        acc,
  }
    tree
in

let merge_stage6_demo | Tree -> DepGraph -> Dyn
  = fun tree graph =>
    let result = merge_stage5_force (fun i => i) tree graph in
    result."__root__"
  in

let merge_stage6_render_split_only = fun depth_ tree graph =>
  let result = merge_stage5_force (fun i => i) tree graph in

  let rec visit = fun acc tree result =>
    match {
      'C c =>
        if !c.meta.hidden && !c.meta.disabled then
          let ordered_keys = sort_by c.meta.order (std.record.fields c.data) in

          std.array.fold_left
            (
              fun sub_acc key =>
                let t = c.data."%{key}" in

                let sub_acc =
                  if acc.depth == 0 then
                    sub_acc
                    |> rupdate "path_key" acc.path_key
                    |> rupdate "path" acc.path
                  else
                    sub_acc
                    |> rupdate "path_key" (if acc.path_key == "" then key else (std.string.join "/" [acc.path_key, key]))
                    |> rupdate "path" (acc.path @ [key])
                    |> rupdate "depth" (acc.depth - 1)
                in

                visit sub_acc t result."%{key}"
            )
            acc
            ordered_keys
        else
          acc,
      'M m =>
        if !m.meta.hidden && !m.meta.disabled then
          let p = acc.path_key in
          let pcollect = {
            objs =
              if std.record.has_field p acc.collects then
                acc.collects."%{p}".objs @ [result]
              else
                [result],

            path = acc.path,
          }
          in
          acc |> rupdate "collects" (rupdate p pcollect acc.collects)
        else
          acc,
    }
      tree
  in

  let acc =
    visit
      {

        path_key = "",
        path = [],
        depth = depth_ + 1, #Increase one to skip __root__

        #collect leaves
        collects = {}, #{_ : {objs = [], path = []}}
      }
      tree
      result
  in

  acc.collects
in

let merge_stage6_render | Dyn -> Number -> Tree -> DepGraph -> Dyn
  = fun paths depth_ tree graph =>
    let paths = std.array.map (fun path => ["__root__"] @ (std.string.split "." path)) paths in
    let selection_ = std.record.merge_all (std.array.map (fun p => make_record p true) paths) in

    let result = merge_stage5_force (fun i => i) tree graph in
    let acc =
      visit_tree
        {
          selection = selection_,
          slow_select = true,
        }
        {

          path_key = "",
          path = [],
          depth = depth_ + 1, #Increase one to skip __root__

          #collect leaves
          collects = {}, #{_ : {objs = [], path = []}}
        }
        tree
        result
    in
    acc.collects
  in

let merge_prepare | Dyn -> { tree | Tree, graph | DepGraph }
  = fun tree =>
    let tree =
      tree
      |> define
      |> merge_stage1
      |> merge_stage2
      |> merge_stage3_simplify
    in
    let graph = merge_stage4_parse_dep_graph tree in
    let tree_ = tree in
    let graph_ = graph in
    { tree = tree_, graph = graph_ }
  in

let merge_render_internal = fun paths depth tree =>
  #pattern match has bug, it will execute merge_prepare more than once.
  #let {tree, graph} = merge_prepare tree in
  let x = merge_prepare tree in

  merge_stage6_render paths depth x.tree x.graph
in

let merge_render = fun paths depth tree =>
  let x = merge_prepare tree in

  let acc = merge_stage6_render paths depth x.tree x.graph in
  std.array.map
    (
      fun m =>
        {
          path = (std.array.split_at 1 m.path).right,
          objs = m.objs,
        }
    )
    (std.record.values acc)
in

let merge_render_all = fun tree =>
  let acc = merge_render_internal ["*"] 0 tree in
  if std.record.has_field "__root__" acc then
    acc."__root__".objs
  else
    []
in

let merge_render_split = fun depth tree =>
  #pattern match has bug, it will execute merge_prepare more than once.
  #let {tree, graph} = merge_prepare tree in
  let x = merge_prepare tree in

  merge_stage6_render_split_only depth x.tree x.graph
in
################################
let apis = [
  ["Mender", Mender],
  ["ModuleObject", ModuleObject],
  ["Module", Module],
  ["TreeMeta", TreeMeta],
  ["LazyTree", LazyTree],
  ["Tree", Tree],
  ["define", define],
  ["render", merge_render],
  ["render_all", merge_render_all],
  ["render_split", merge_render_split],
  ["enable_if", enable_if],
  ["disable_if", disable_if],
  ["Disabled", Disabled],
  [
    "#develop",
    (
      'Apis [
        ["show_lazy_tree", show_lazy_tree],
        ["show_tree", show_tree],
        ["merge_stage1", merge_stage1],
        ["merge_stage2", merge_stage2],
        ["merge_stage3_simplify", merge_stage3_simplify],
        ["merge_stage4_parse_dep_graph", merge_stage4_parse_dep_graph],
        ["merge_stage5_force", merge_stage5_force],
        ["merge_stage6_render", merge_stage6_render],
        ["render_internal", merge_render_internal],
      ]
    )
  ]
]
in
let rec export_apis = fun apis =>
  std.array.fold_left
    (
      fun exports pair =>
        let name = std.array.first pair in
        let api = std.array.last pair in
        exports
        |> rupdate
          name
          (
            match {
              'Apis apis => export_apis apis,
              x => x
            }
              api
          )
    )
    {}
    apis
in

export_apis apis
