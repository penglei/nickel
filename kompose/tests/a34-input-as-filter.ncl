let Comod = import "./module.ncl" in

let { ConfigmapType, DeploymentType, .. } = import "./type.ncl" in

let apps = {
  monitor = {
    configmap = {
      type = ConfigmapType,
      object = {
        metadata.name = "monitor-cfg1",
        data = {
          x = 1111
        }
      }
    },

    deployment = {
      type = DeploymentType,
      object = {
        metadata.name = "deploy-demo",
        spec.image | default = "x"
      },
    },
  }
}
in

let component_filter = [
  {
    input = {
      deploy-replica | Number,
      cfg = {
        replica = deploy-replica * 111,
      }
    }
  },
  {
    monitor = {
      configmap = {
        value = {
          deploy-replica | Number,
          mode | String,
          cfg | doc "component filter generated configuration",
          replica = cfg.deploy-replica
        },
        fragment = {
          data.mode = value.mode,
          data.replica = value.deploy-replica
        }
      },
      deployment = {
        value = {
          cfg,
          replica = cfg.replica
        },
        fragment = {
          spec.replica = value.replica
        }
      }
    }
  },
]
in

let root_inputs = {
  input = {
    mode = "dev",
    deploy-replica = 2,
  }
}
in

let tree = [
  apps,
  component_filter,
  root_inputs
]
in

tree
