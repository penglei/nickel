{
  apiVersion = "apps/v1",
  kind = "Deployment",
  metadata = { labels = { app = "alleyway", }, name = "khaos-alleyway", },
  spec = {
    replicas = 1,
    selector = { matchLabels = { app = "alleyway", }, },
    template = {
      metadata = { labels = { app = "alleyway", }, },
      spec = {
        namedContainers | not_exported = {
            app = {
              args = [
                "--log-format=json",
                "--insecure-bind-address=0.0.0.0",
                "--insecure-port=18080"
              ],
              image | default = "ccr.ccs.tencentyun.com/cdb.khaos.platform/khaos-alleyway",
              imagePullPolicy | default = "Always",
              name | default = "app",
            }
          },
        containers | default = [namedContainers.app],
        imagePullSecrets = [{ name = "khaos-ccr-cred", }],
        serviceAccountName = "khaos-alleyway",
      },
    },
  },
}
& { spec.template.spec.namedContainers.app.imagePullPolicy = "IfNotPresentX" }
& {
  spec.template.spec.containers = [
    spec.template.spec.namedContainers.app,
    spec.template.spec.namedContainers.agent,
  ]
}
& {
  spec.template.spec.namedContainers.agent = {
    name = "khaos-agent",
    imagePullPolicy = "Always"
  }
}
