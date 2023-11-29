# misc

## 作为helm替代品用来管理cluster manifests的思考

1. 获取cluster信息，转换成各个组件的input

   a. 选择集群，根据cluster名字动态加载。但是nickel不支持动态加载，我们只能从一个全量的配置中获取

2. 获取artifact信息

   a. 选择版本号，根据版本号得到artifact metadata。

3. 动态加载配置信息

   a. 根据cluster中的配置，动态加载mode、schedulerconfig、zone、secret等信息

   b. 根据artifact信息，动态加载base manifest

如何把这些灵活配置组在一块呢？

  通过 module fragment可组合特性实现。

如何生成一个配置组件**包**呢?

: 要点: 1. 包的格式要非常简单；
        2. 需要比较容易生成input field

: 问题：

  1. 这些ad-hoc package需要保存吗？
     跟上层流程相关，每一个流程之间的传递需要持久化，这意味着所有dependencies也要持久化；

  2. 如何定义包的名字和ID

## 关于merge的一些早期思考

下面这一行无用，因为annotation无法merge。(即此处无法给spec.selector本身加上default annotation)

    let deploy_raw = deploy_raw & {spec = { selector | default = {}}} in

从merge (&)的语法和语义设计来讲，这很难设计，考虑如下merge:

    {foo = 1} & { foo | default } & { foo = 2}

中间的 `fragment: {foo | default}` 应该把foo的default annotation 分配给谁呢？ 显然分配给谁都不合适，
它只能是中间fragment 自己内部的annotation。如果要支持 annotation本身的merge，
必需设计另外一个annotation的merge语法和语义，例如：

    ({foo = 1} |&| { foo | default }) & { foo = 2}

进一步考虑如下merge表达式：

    {foo = 1} |&| { foo | default } & { foo | default = 2}

此时， `|&|` 运算符的优先级需要高于 & 的优先级

语义详细设计：

* |&| 合并 annotation 是需要优先级吗？如何判断两个annotation是"相同的" ?
* 从使用角度来看，annotation通常表示某一类属性、动作，通常是全局的：即横跨 merge(&) 的各个分量，
* 因此，给这些annotation进行命名，不同名进行合并，同名需要覆盖。 那么，如何覆盖呢？这又引入了anntation之间的优先级！

复杂情况可虑: [annotation priority] of [value priority] ?

     {foo | default:100 = 1 } |&| { foo | default:100 = 2}

但是我们真的需要所有annotation都可覆盖么？

* 对于value priority，我们可能需要的是灵活的blcok scope 的 rec priority
* 对于 optional 我们可能需要的是它能 force hide 来忽略已经赋值的情况
