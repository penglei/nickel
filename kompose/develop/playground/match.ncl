let d1 = {type = {}, object = {}, fragments = []} in
let d2 = {fragments = []} in
let d3 = {fragments = [], object = {}} in
let define = fun m =>
    match {
        #{fragments} => "fragm",
        f@{fragments, object ? null} => let obj = object in f & {object = obj},
        {type,  object, fragments, .. } => "defs",
    } m
in
define d2
