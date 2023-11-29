let { StatefulsetType, .. } = import "./type.ncl" in

[
  {
    foo = {
      type = StatefulsetType,
      object = {
        metadata.name = "sts-a",
        spec.replica = 0,
        spec.image = "SECOND"
      }
    }
  },
  {
    "@meta" = { hidden = false },
  }
]
