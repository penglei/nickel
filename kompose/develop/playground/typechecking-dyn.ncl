let { when } = {
  when
    : Bool -> Dyn -> Dyn
    | doc m%" return empty record if `cond` is false "%
    = fun cond v => if cond then v else {},
}
in

{
  x = when true 1,
}
