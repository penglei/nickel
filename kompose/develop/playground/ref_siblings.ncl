{
  deployment.spec = {
    image = "x",
    replica = 123,
  },

  wrapper = {
    myspec = deployment
  }
}
& {
  deployment.metadata.name = "nginx"
}
