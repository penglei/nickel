let Deployment = {
  value = {
    component | String,
    artifacts = {},
  },
  fragment = if std.record.has_field value.component value.artifacts then "foo" else "bar"
}
in

let values = {
  value.component = ""
}
in

Deployment & values
