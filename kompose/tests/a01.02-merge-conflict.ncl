let {StatefulsetType, ..} = import "./type.ncl" in

let _nls_disable_format_by_bug_ = match { v => false } in

let demo = {
    first = {
        statefulset = {
            type = StatefulsetType,
            object = {
                metadata.name = "sts-1",
                spec.image = "s:1"
            },
        }
    }
    ,
    second = {
        statefulset = {
            type = StatefulsetType,
            object = {
                spec.image = "s:2"
            },
        }
    }
}
in

[demo.first, demo.second]

