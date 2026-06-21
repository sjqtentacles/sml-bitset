(* bitset.sig

   A fixed-capacity, persistent set of small non-negative integers, stored as a
   packed array of bits.

   A `bitset` is created with a capacity (the number of bits it can hold); the
   valid indices are `0 .. capacity - 1`. All update operations are persistent:
   they return a new bitset and leave the argument unchanged.

   Representation note: bits are packed 32 to a chunk, regardless of the host
   compiler's native word size. This keeps behaviour identical across MLton
   (32-bit native words) and Poly/ML (63-bit native words).

   Set-algebra operations (`union`, `inter`, `diff`) require both arguments to
   share the same capacity; they raise `Size` otherwise. *)

signature BITSET =
sig
  type bitset

  (* Number of bits a set can hold; indices are 0 .. capacity-1. *)
  val capacity : bitset -> int

  (* `empty n` is the all-zero set of capacity n; `full n` has every bit set.
     Raise `Size` if n < 0. *)
  val empty : int -> bitset
  val full  : int -> bitset

  (* `fromList n is` builds a capacity-n set with exactly the bits in `is` set.
     Raises `Subscript` if any index is out of range, `Size` if n < 0. *)
  val fromList : int -> int list -> bitset

  (* Membership; out-of-range indices are simply not members (no exception). *)
  val member : bitset -> int -> bool

  (* Persistent single-bit update. Raise `Subscript` if the index is out of
     range for the set's capacity. *)
  val add    : bitset -> int -> bitset
  val remove : bitset -> int -> bitset

  (* Set algebra; arguments must have equal capacity (else `Size`). *)
  val union      : bitset * bitset -> bitset
  val inter      : bitset * bitset -> bitset
  val diff       : bitset * bitset -> bitset
  val complement : bitset -> bitset

  (* Number of set bits (population count). *)
  val count   : bitset -> int
  val isEmpty : bitset -> bool

  (* `rank b i` is the number of set bits at indices strictly less than `i`:
     rank(b, i) = #{ j < i : member(b, j) }. `i` is clamped to [0, capacity],
     so rank(b, 0) = 0 and rank(b, i) = count b for any i >= capacity (no
     exception on out-of-range `i`). *)
  val rank : bitset -> int -> int

  (* `select b k` is the index of the k-th set bit, counting from 0 in
     ascending order, or NONE when the set has fewer than k+1 set bits (which
     includes every k < 0). Inverse of `rank` on set bits:
     rank(b, valOf (select(b, k))) = k for 0 <= k < count b. *)
  val select : bitset -> int -> int option

  (* Fold over the indices of set bits in ascending order. *)
  val foldBits : (int * 'a -> 'a) -> 'a -> bitset -> 'a

  (* Set-bit indices in ascending order. *)
  val toList : bitset -> int list

  (* Structural equality (same capacity and same bits). *)
  val equals : bitset * bitset -> bool
end
