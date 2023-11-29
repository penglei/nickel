# kompas

**Kit for Organizing and Managing Packages with a Structured approach**

`kompas` 是基于 nickel 语言实现的配置包管理工具，kompas 起始于管理大量的 kubernets 配置，但不限于在 kubernetes 场景下使用。

## 概念

对象(Object)
: Object 是基本的配置单元，包含一些不可分割的结构化配置，
例如，一个 Kubernetes Deployment 对象。

: 技术上，每个 Object 由 module 表示，module 支持多个配置片段合并成最终的 object。

组件(Component)

: 组件是完整的模块配置，它通常由有多个由多个 object 组成。
例如，Kubernetes 的无状态工作负载，通常会包含 deployment，service，configmap，secret 等对象配置。

包(Package)

: 包是用来封装一个或多个组件，实现复杂配置的分发与复用。

: 一个完整的服务通常由多个组件(component)构成，可以使用包对一个服务的配置进行集中管理。

Manifest
: 语义视角的配置信息，通常指一个包最终生成的结构化配置。
package 级别还支持的一些 ad-hoc 功能：

- 开关组件

  临时打开会关闭一些组件。

  ::: Warning

  关闭组件只影响最终生成的配置，并不提供如何清理集群中已存在组件的功能。

  ::::::::::::

- 受限的全局配置

## 一些 Kubernetes 上的 _Deploy_ 经验

- 组件可能读取三种配置信息：

  - 集群信息(cluster)

    一些组件在最终部署的时候可能需要感知部署集群的上下文，
    例如组件开关、集群提供的存储配置、密钥信息等。

    我们使用一些配持续部署工具，如 argocd，在生成最终的部署 Manifest 时，可能会给其中的 Ojbect 增加一些索引(labels)等信息，以方便后续管理动作的实施，例如 ArgoCD 通过 GUI 进行部署查看、升级等。

  - 部署模式(mode)

    包含各个组件的日志级别、隔离模式等。对于开发、测试、运营环境，它们部署的 artifact 可能具有不同的编译策略，输出的日志也详尽不同。

  - 版本制品(Variant)

    配合项目的版本管理，部署的时候会选择不同仓库中的不同版本制品：

    - 组件对象中的镜像版本地址
    - 组件原始 raw 格式的配置

      ::: Info

      通常我们会写一个默认的 yaml 配置作为基本的 manifest，后续再对这个基础 manifest 进行特化，适配不同的集群环境。

      :::::::::

## 设计

根本难点:

1. merge操作在包级别管理，引申出如何**标识合并分量**的问题

  逻辑上，merge操作最终生成的对象是在kubernetes集群范围类唯一的。但是不同时间的merge可能生成不同的对象，即使他们是同一个"template"。
  这一点和我们的设计有本质上的冲突：我们认为merge的是目标对象，不是一个template! 只不过这个目标对象不是用它在现实中的真实标识进行定位的。
  那他在我们的配置模板系统中应该如何标识呢？显然只能用我们的 **模块标识** ，这个模块标识与生成的对象的标识之间的关系由使用者进行
  维护。因此，这要求我们的**模块标识**需要易用、复合直觉。

2. 第一点介绍了如何合并一个对象，但是通常一个服务由多个对象构成组件，多个组件构成包。如何合并组件呢？
   根本上合并组件就是合并对象。


### 包 API

### 组件 API

定义基底组件

: 在组件的特化过程中，组件以一个基础版本为起点，`define` 即定义了一个组件的起始版本(称作基底组件)

        basic = module.define "basic" {x = xmodule, y = ymodule}

扩展组件

: 基底组件没有足够的配置信息，常常不能直接使用，需要增加更多的特化信息才能得到最终可使用的组件配置：

        extend1 = module.derive "extend1" basic {x = xmodule_piece, y = ymodule_piece}
        extend2 = module.derive "extend2" [basic] {z = zmodule_piece }
        main = module.derive "main" [extend1, extend2] {}

导出组件

: 将组件导出为原始格式(e.g. yaml)

: 一个组件通常包含多个 module，导出一个组件会得到对象数组的原始格式。
原始对象在提交给服务端如 api server 的时候，可能对提交的对象有顺序要求，
因此，导出接口提供一个可导出对象的有序列表名。

        result = export main ["x", "y", "z"]

### Module API

定义单个 module

: 一个 module 由对象类型、原始值、对象扩展(mixins)、配置片段组成

        x = compose [{object | Object, raw | Any, mixins | Array Mixin, fragments | Array any}]

导出单个 module

: result = build x

### 命令行

#### 渲染组件

    kompas render $package --value=value.yaml

####

#### 导出单个 object

::: Warning

单个 object 的操作暂未实现

::::::::::

```console
kompas run
  --schema apps/v1:deployment
  --raw deploy.yaml
  --fragments fragments.ncl,...
  --fragment-inline '{spec.template.spec.namedContainers.app.image = "xxx"}'
  --mixins WorkloadMxin,...
```

## 语言设计

Record

: 无序
: 语义

〚Record & Record 〛= merge (List[Option[(String, Option[Value])]], List[...])

: e.g.

    data Value =
        | Record k v

    data OptionField k v =
        |None k
        |Some (k, v)

    [None("qux"),  Some(("foo", 1)), Some(("bar", 2))]

merge operation

    [None("qux"), Some(("foo", 1))] & [Some(("qux", 1))] = []

OrderedRecored

: 有序记录是Reproducible非常重要的能力。

    {[
        foo = "a",
        bar = "b"
    ]}

: 将这段配置导出为yaml是不变的

    foo: a
    bar: b

Set

: 集合，其中的元素是唯一的

    {{ "b", "a" }}

: 导出'集合'为yaml时，它的结果是确定的数组

    - b
    - a

`=` 定义的初始值只是片断，这一点要求语言是lazy的，否则无法为record只定义部份字段的初始值。
不过，如果约定所有类型都有默认值，也可能不要求lazy。
