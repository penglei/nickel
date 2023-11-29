#rec default 和 rec force 都只是给leaf增加priority，而不会给中间的record增加priority
let foo =
  {
    #可以去掉default看一看有什么结果
    w
      | default
      | rec default
      = {
        val | default
          = {
            a = 1,
            b = 1,
          },
        x = "a"
      }
  }
  & {
    w = {
      val = null,
    }
  }
in
std.array.filter (fun x => x != null) (std.record.values foo)

#也许可以考虑增加一个语法: rec default! 表示不止leaf被设置上default，中间的subtree 也被设置上default

# 思考下面的结果：
#{ x | default | rec default = { a = 1, b = 1, } } & { x = { a = 2} }
#{ x | default | rec default = { a = 1, b = 1, } } & { x | default = { a = 2} }

#优先级还需要一个collapse过程，不要传播到最后。这是一个相当过程式--即不具有composable的能力。可能并没有意义
