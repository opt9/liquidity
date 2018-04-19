module Xor = struct (* from digestif *)
  module Nat =
  struct
    include Nativeint

    let ( lxor ) = Nativeint.logxor
  end

  module B = Digestif_bytes

  let imin (a : int) (b : int) = if a < b then a else b
  let size_of_long = Sys.word_size / 8

  let xor_into src src_off dst dst_off n =
    let n = ref n in
    let i = ref 0 in

    while !n >= size_of_long
    do
      B.cpu_to_benat
        dst (dst_off + !i)
        Nat.((B.benat_to_cpu dst (dst_off + !i)) lxor (B.benat_to_cpu src (src_off + !i)));

      n := !n - size_of_long;
      i := !i + size_of_long;
    done;

    while !n > 0
    do
      B.cpu_to_benat dst (dst_off + !i)
        Nat.((B.benat_to_cpu src (src_off + !i)) lxor (B.benat_to_cpu dst (dst_off + !i)));
      incr i;
      decr n;
    done

  let xor_into a b n =
    if n > imin (B.length a) (B.length b)
    then raise (Invalid_argument "Baijiu.Xor.xor_inrot: buffers to small")
    else xor_into a 0 b 0 n

  let xor a b =
    let l = imin (B.length a) (B.length b) in
    let r = B.copy (B.sub b 0 l) in
    ( xor_into a r l; r )
end


module Uncommon = struct

  let (//) x y =
    if y < 1 then raise Division_by_zero else
    if x > 0 then 1 + ((x - 1) / y) else 0 [@@inline]

  let cdiv = (//)

  let imin (a : int) b = if a < b then a else b
  let imax (a : int) b = if a < b then b else a

  module Cs = struct

    open Cstruct

    let empty = create 0

    let null cs = len cs = 0

    let (<+>) = append

    let xor cs1 cs2 =
      let len = imin (len cs1) (len cs2) in
      let b2 = Cstruct.to_bytes cs2 in
      Xor.xor_into (Cstruct.to_bytes cs1) b2 len;
      Cstruct.of_bytes b2

    let (lxor) cs1 cs2 = xor cs1 cs2

  end

end


module Hash = struct
  
  type hash = Digestif.hash

  module type S = sig
    type buffer = Cstruct.t
    type ctx
    type t = Cstruct.t

    val digest_size    : int

    val init           : unit -> ctx
    val feed           : ctx -> buffer -> unit
    val get            : ctx -> t

    val digest         : buffer -> t
    val digestv        : buffer list -> t
    val hmac           : key:buffer -> buffer -> t
    val hmacv          : key:buffer -> buffer list -> t

    val compare        : t -> t -> int
    val eq             : t -> t -> bool
    val neq            : t -> t -> bool

    val pp             : Format.formatter -> t -> unit
    val of_hex         : buffer -> t
    val to_hex         : t -> buffer
  end

  module MakeCstruct (H : Digestif.S) : S = struct
    open H.Bytes
    type buffer = Cstruct.t
    type ctx = H.Bytes.ctx
    type t = Cstruct.t
    let digest_size = H.digest_size
    let init = init
    let feed ctx b = feed ctx (Cstruct.to_bytes b)
    let get c = Cstruct.of_bytes (get c)
    let digest b = digest (Cstruct.to_bytes b) |> Cstruct.of_bytes
    let digestv bs = digestv (List.map Cstruct.to_bytes bs) |> Cstruct.of_bytes
    let hmac ~key b = hmac ~key:(Cstruct.to_bytes key) (Cstruct.to_bytes b)
                      |> Cstruct.of_bytes
    let hmacv ~key bs =
      hmacv ~key:(Cstruct.to_bytes key) (List.map Cstruct.to_bytes bs)
      |> Cstruct.of_bytes
    let compare = Cstruct.compare
    let eq = Cstruct.equal
    let neq x y = not (eq x y)
    let pp fmt x = pp fmt (Cstruct.to_bytes x)
    let of_hex b = of_hex (Cstruct.to_bytes b) |> Cstruct.of_bytes
    let to_hex h = Cstruct.of_bytes (to_hex (Cstruct.to_bytes h))
  end

  module BLAKE2B : S = MakeCstruct(Digestif.BLAKE2B)
  module BLAKE2S : S = MakeCstruct(Digestif.BLAKE2S)
  module MD5 : S = MakeCstruct(Digestif.MD5)
  module RMD160 : S = MakeCstruct(Digestif.RMD160)
  module SHA1 : S = MakeCstruct(Digestif.SHA1)
  module SHA224 : S = MakeCstruct(Digestif.SHA224)
  module SHA256 : S = MakeCstruct(Digestif.SHA256)
  module SHA384 : S = MakeCstruct(Digestif.SHA384)
  module SHA512 : S = MakeCstruct(Digestif.SHA512)


  let module_of = function
    | `BLAKE2B -> (module BLAKE2B : S)
    | `BLAKE2S -> (module BLAKE2S : S)
    | `MD5 -> (module MD5 : S)
    | `RMD160 -> (module RMD160 : S)
    | `SHA1 -> (module SHA1 : S)
    | `SHA224 -> (module SHA224 : S)
    | `SHA256 -> (module SHA256 : S)
    | `SHA384 -> (module SHA384 : S)
    | `SHA512 -> (module SHA512 : S)

  let digest h =
    let module H = (val (module_of h)) in
    H.digest

end
