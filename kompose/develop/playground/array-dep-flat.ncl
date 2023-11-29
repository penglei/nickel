let arr = #
  [
    1,
    [2, 3],
    [
      4,
      [
        5,
        6
      ],
      [
        7,
        [
          8,
          9
        ],
        9.1
      ],
      9.2,
    ],
    10
  ]
in

let new = fun i => 'C i in

let recdef = fun sth =>
  let rec deepflatmap #| Dyn -> Array Dyn
  = fun acc x =>
    if std.is_array x then
      std.array.fold_left deepflatmap acc x
    else
      acc @ [new x]
  in
  deepflatmap [] sth
in

recdef arr == std.array.map new [1, 2, 3, 4, 5, 6, 7, 8, 9, 9.1, 9.2, 10]
