#let Mixin = {
#  name | String,
#  decorate | Dyn,
#  restore | Dyn,
#}
#in
#
#let ModuleObject = {
#  Identifier | String,
#  Schema | Dyn,
#  ..
#}
#in
#let Module = {
#  _input | Dyn | optional | default = null,
#  object | ModuleObject | optional | default = null,
#  mixins | Array Mixin | default = [],
#  raw | Dyn, # don't set default value here,
#  fragments | Dyn | default = [],
#  disable : Bool | default = false,
#}
#in
#let ComponentMeta = {
#  orders
#    | Array Dyn
#    | doc "module exporting orders"
#    | default
#    = []
#}
#in
#let rec Component = {
#  name | String,
#  modules #| Array { _ : Module } #Array Dyn
#    | Array Dyn
#    | doc "{_ : Module} 以及一个额外的字段 {_input: Dyn}",
#  origins | Array Component | default = [],
#  meta | optional | ComponentMeta,
#}
#in
#let define | String -> { _ : Module } -> ComponentMeta -> Component
#  = fun name_ modules_ meta_ =>
#    let modules_internal_ =
#      std.record.map
#        (
#          fun _n m =>
#            match {
#                'Component c => 
#                    'Component {},
#                _ => 
#                    if _n == "_input" then 
#                        m
#                    else
#                        let m1 = m & Module in
#                        'Module {
#                            object = m1.object,
#                            mixins = m1.mixins,
#                            raw | default = m1.raw, # make raw whole overridable.
#                            fragments = m1.fragments,
#                            disable = m1.disable,
#                        }
#            }
#        )
#        modules_
#    in
#    'Component {
#      name = name_,
#      modules = [modules_internal_],
#      origins = [],
#      meta = if meta_ != null then meta_ else ComponentMeta, #how to do null override better?
#    }
#  in
#
##let rec PathNode = [| 'Path String, 'Module Module |] in PathNode
##let define :  String -> { _ : Dyn  } -> Component
##  = fun name_ defs_ =>
##    let r = { name = name_, modules = [] } | Component in
##    #std.trace "%{std.typeof onex}" r
##  in
#let khaos-monitor =
#  define
#    "monitor"
#    {
#      deploy = { raw = "raw" }
#    }{}
#in
#let khaos-platform =
#  define
#    "platform"
#    {
#      monitor = khaos-monitor
#    }{}
#in
let Component = { #node
    id : String | default = "",
    nodes : forall c m p. { _ : [| 'Component c, 'Module m; p |]} | default = {},
    meta: Array String | default = [],
    #meta: Array String | default= 空,
    _input | Dyn = {},
} in

let Module = { #leaf
    type | Dyn | default = null,
    fragments | Array Dyn | default = [],
    _input | Dyn = {},
} in

let demo1 = 'Component ({
    id = "a",
    nodes = {
        deploy = 'Module ({
            fragments = [{}]
        } | Module),
        _input = {
            x = 1,
            y = "sth",
        },
    }
} | Component) in

match {
    'Component c => c  #std.serialize 'Yaml c
}
demo1

