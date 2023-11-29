let foo1 = {
  foo1x = "foo1x",
  _global = {
    name | String,
    age | Number | default = 1,
  },

  result = {
    introduction = "I'm %{_global.name}, and I'm %{std.to_string _global.age} years old"
  }
}
in

let foo2 = {
  foo2x = "foo2x",
  _global = {
    name = "penglei",
    age = 18,
  },
  result = {
    from = "foo2"
  }
}
in
let foo1_2 = {
  result = {
    _global | Dyn | not_exported,
    introduction = "I'm %{_global.name}, and I'm %{std.to_string _global.age} years old"
  }
}
in
{
  case1 = foo1 & foo2,

  # run `nickel eval FILE ` to test all
  # or   `nickel export FILE --field case4` to run `case4` only

  case2 | not_exported = foo1.result & foo2.result, #it doesn't work

  case3 | not_exported = #it does't work
      (
        {
          _global = foo1._global,
          result = foo1.result
        }
      )
      & (
        {
          _global = foo2._global,
          result = foo2.result,
        }
      ),

  case4 | not_exported =
      let merged_global = foo1._global & foo2._global in
      let injection_global = { _global = merged_global } in
      {
        result = foo1.result & injection_global
      }
      & {
        result = foo2.result & injection_global
      },

  case5 =
    let merged_global = foo1._global & foo2._global in
    let injection_global = { _global = merged_global } in
    {
      result = foo1_2.result & injection_global
    }
    & {
      result = foo2.result & injection_global
    },
}
