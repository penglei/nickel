let x1 = { a | default = 1 } & ({ a | priority 100 = 2 }) in
let x2 = x1 & { a = 3 } in
x2
