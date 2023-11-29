#cat << EOF | nickel
#($(cat examples/optional-field.ncl)) & {foo = 1, storage_driver | priority 1 = "s3"}
#EOF
#echo "{ wrapper = ($(cat examples/optional-field.ncl))} & {wrapper | force = {foo = 1, storage_driver = \"s3\"}}" | nickel export  | jq '.wrapper'
let p1 = { storage_driver | String, s3 | optional, fs | optional } in
let p2 = {
  storage_driver | String,
  s3 =
    if storage_driver == "s3" then
      { bucket = "xxx", secret = {} }
    else
      null,
  fs =
    if storage_driver == "fs" then
      { path = "/data" }
    else
      {},
  mongo | optional
}
in p1 & p2 & { storage_driver | not_exported = "mongo" }
