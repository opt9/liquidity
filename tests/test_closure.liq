
[%%version 0.4]

type storage = int

let%entry main
      (parameter : int)
      (storage : int) =
  let x = parameter + 10 in
  let f = fun ( arg : int * int ) ->
    arg.(1) + x
  in
  let storage = (parameter, storage) |> f in
  ( ([] : operation list), storage )
