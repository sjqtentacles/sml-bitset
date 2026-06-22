(* Tests for sml-bitset, standardized on the shared sml-test Harness. *)

structure Tests =
struct
  open Harness

fun raisesSub (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Subscript => true | _ => false

fun raisesSize (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Size => true | _ => false

structure B = Bitset

(* ---- reference rank/select over a plain bool array ---- *)

fun refArray cap is =
    let val arr = Array.array (cap, false)
    in List.app (fn i => Array.update (arr, i, true)) is; arr end

(* number of set entries at indices strictly less than i, i clamped to [0,cap] *)
fun refRank arr i =
    let
      val n = Array.length arr
      val hi = if i < 0 then 0 else if i > n then n else i
      fun go (j, acc) =
          if j >= hi then acc
          else go (j + 1, if Array.sub (arr, j) then acc + 1 else acc)
    in go (0, 0) end

(* index of the k-th set entry (0-based), NONE if fewer than k+1 *)
fun refSelect arr k =
    let
      val n = Array.length arr
      fun go (j, rem) =
          if j >= n then NONE
          else if Array.sub (arr, j)
               then if rem = 0 then SOME j else go (j + 1, rem - 1)
               else go (j + 1, rem)
    in if k < 0 then NONE else go (0, k) end

(* deterministic, fixed-seed LCG yielding 32-bit words; wrap-around is free
   because Word32 arithmetic is modulo 2^32. *)
local
  val seed = ref (0w2463534242 : Word32.word)
in
  fun nextWord () =
      (seed := Word32.+ (Word32.* (!seed, 0w1664525), 0w1013904223); !seed)
  (* uniform-ish int in [0, n) for n > 0 *)
  fun randInt n = Word32.toInt (Word32.mod (nextWord (), Word32.fromInt n))
end

fun run () =
  let
    (* ---- construction / capacity ---- *)
    val () = check "empty capacity" (B.capacity (B.empty 10) = 10)
    val () = check "empty is empty" (B.isEmpty (B.empty 10))
    val () = check "empty count 0" (B.count (B.empty 100) = 0)
    val () = check "full count = capacity (33)" (B.count (B.full 33) = 33)
    val () = check "full count = capacity (64)" (B.count (B.full 64) = 64)
    val () = check "full count = capacity (0)" (B.count (B.full 0) = 0)
    val () = check "empty 0 isEmpty" (B.isEmpty (B.empty 0))
    val () = check "negative capacity raises Size" (raisesSize (fn () => B.empty ~1))

    (* ---- add / remove / member round-trips ---- *)
    val s = B.add (B.add (B.add (B.empty 100) 0) 50) 99
    val () = check "member 0" (B.member s 0)
    val () = check "member 50" (B.member s 50)
    val () = check "member 99" (B.member s 99)
    val () = check "non-member 1" (not (B.member s 1))
    val () = check "count after 3 adds" (B.count s = 3)
    val () = check "add is persistent (original unchanged)"
                   (B.count (B.empty 100) = 0)
    val s2 = B.remove s 50
    val () = check "remove drops bit" (not (B.member s2 50))
    val () = check "remove keeps others" (B.member s2 0 andalso B.member s2 99)
    val () = check "original still has removed bit (persistent)" (B.member s 50)
    val () = check "add idempotent count"
                   (B.count (B.add (B.add (B.empty 10) 3) 3) = 1)
    val () = check "remove absent is no-op"
                   (B.count (B.remove (B.empty 10) 5) = 0)

    (* out-of-range *)
    val () = check "member out-of-range is false" (not (B.member s 100))
    val () = check "member negative is false" (not (B.member s ~1))
    val () = check "add out-of-range raises" (raisesSub (fn () => B.add (B.empty 10) 10))
    val () = check "add negative raises" (raisesSub (fn () => B.add (B.empty 10) ~1))
    val () = check "remove out-of-range raises" (raisesSub (fn () => B.remove (B.empty 10) 99))

    (* ---- fromList / toList / foldBits ascending ---- *)
    val fl = B.fromList 100 [99, 0, 50, 1, 31, 32, 63, 64]
    val () = check "fromList toList ascending"
                   (B.toList fl = [0, 1, 31, 32, 50, 63, 64, 99])
    val () = check "fromList count" (B.count fl = 8)
    val () = check "fromList out-of-range raises"
                   (raisesSub (fn () => B.fromList 10 [3, 20]))
    val () = check "foldBits sums set indices"
                   (B.foldBits (op +) 0 (B.fromList 10 [1,2,3,4]) = 10)
    val () = check "toList of empty is []" (B.toList (B.empty 50) = [])

    (* ---- cross-chunk boundaries (bits 31, 32, 63, 64) ---- *)
    val bnd = B.fromList 80 [31, 32, 63, 64]
    val () = check "boundary bit 31 set" (B.member bnd 31)
    val () = check "boundary bit 32 set" (B.member bnd 32)
    val () = check "boundary bit 63 set" (B.member bnd 63)
    val () = check "boundary bit 64 set" (B.member bnd 64)
    val () = check "boundary 30 unset" (not (B.member bnd 30))
    val () = check "boundary 33 unset" (not (B.member bnd 33))
    val () = check "boundary count" (B.count bnd = 4)

    (* ---- set algebra ---- *)
    val a = B.fromList 64 [1, 2, 3, 40, 63]
    val b = B.fromList 64 [2, 3, 4, 63]
    val () = check "union"
                   (B.toList (B.union (a, b)) = [1, 2, 3, 4, 40, 63])
    val () = check "inter"
                   (B.toList (B.inter (a, b)) = [2, 3, 63])
    val () = check "diff a-b"
                   (B.toList (B.diff (a, b)) = [1, 40])
    val () = check "diff b-a"
                   (B.toList (B.diff (b, a)) = [4])
    val () = check "union with empty is identity"
                   (B.equals (B.union (a, B.empty 64), a))
    val () = check "inter with full is identity"
                   (B.equals (B.inter (a, B.full 64), a))
    val () = check "mismatched capacity union raises Size"
                   (raisesSize (fn () => B.union (B.empty 10, B.empty 20)))

    (* ---- complement (must not expose phantom high bits) ---- *)
    val () = check "complement of empty is full"
                   (B.equals (B.complement (B.empty 33), B.full 33))
    val () = check "complement of full is empty"
                   (B.isEmpty (B.complement (B.full 33)))
    val () = check "complement count (cap 33, 5 set => 28)"
                   (B.count (B.complement (B.fromList 33 [0,1,2,3,4])) = 28)
    val () = check "double complement is identity"
                   (B.equals (B.complement (B.complement a), a))
    (* capacity 1: complement of {0} must be empty, not 31 phantom bits *)
    val () = check "tiny capacity complement no phantom bits"
                   (B.count (B.complement (B.fromList 1 [0])) = 0)

    (* ---- equals ---- *)
    val () = check "equals reflexive" (B.equals (a, a))
    val () = check "equals same contents"
                   (B.equals (B.fromList 10 [1,2,3], B.fromList 10 [3,2,1]))
    val () = check "not equals different contents"
                   (not (B.equals (B.fromList 10 [1,2], B.fromList 10 [1,3])))
    val () = check "not equals different capacity"
                   (not (B.equals (B.fromList 10 [1], B.fromList 20 [1])))

    (* ---- a larger consistency batch ---- *)
    val big = B.fromList 1000 [0, 100, 500, 999, 512, 511]
    val () = check "large set count" (B.count big = 6)
    val () = check "large set toList"
                   (B.toList big = [0, 100, 500, 511, 512, 999])
    val () = check "large set member 999" (B.member big 999)
    val () = check "large set non-member 998" (not (B.member big 998))

    (* ---- rank: convention + edge cases ---- *)
    val rs = B.fromList 100 [0, 50, 99]
    val () = check "rank at 0 is 0" (B.rank rs 0 = 0)
    val () = check "rank counts bits strictly below i (1 excludes bit 0... )"
                   (B.rank rs 1 = 1)
    val () = check "rank excludes bit at i (50 not yet counted)"
                   (B.rank rs 50 = 1)
    val () = check "rank includes bit just below i" (B.rank rs 51 = 2)
    val () = check "rank at capacity = count" (B.rank rs 100 = B.count rs)
    val () = check "rank past the end = count" (B.rank rs 1000 = B.count rs)
    val () = check "rank of negative i = 0" (B.rank rs ~5 = 0)
    val () = check "rank on empty is 0" (B.rank (B.empty 64) 64 = 0)
    val () = check "rank across chunk boundary"
                   (B.rank (B.fromList 80 [31, 32, 63, 64]) 64 = 3)

    (* ---- select: convention + edge cases ---- *)
    val () = check "select 0 = first set bit" (B.select rs 0 = SOME 0)
    val () = check "select 1 = second set bit" (B.select rs 1 = SOME 50)
    val () = check "select 2 = third set bit" (B.select rs 2 = SOME 99)
    val () = check "select count = NONE" (B.select rs (B.count rs) = NONE)
    val () = check "select beyond count = NONE" (B.select rs 10 = NONE)
    val () = check "select negative = NONE" (B.select rs ~1 = NONE)
    val () = check "select on empty = NONE" (B.select (B.empty 100) 0 = NONE)
    val () = check "select on empty (k>0) = NONE" (B.select (B.empty 100) 5 = NONE)

    (* ---- round-trip identities ---- *)
    val () = check "rank o select identity over rs"
                   (let fun ok k = k >= B.count rs
                                   orelse (B.rank rs (valOf (B.select rs k)) = k
                                           andalso ok (k + 1))
                    in ok 0 end)
    val () = check "select o rank lands on a set bit"
                   (B.foldBits (fn (i, acc) =>
                        acc andalso B.select rs (B.rank rs i) = SOME i) true rs)

    (* ---- randomized property test vs bool-array reference ---- *)
    val trials = 400
    val rankOk = ref true
    val selectOk = ref true
    val roundOk = ref true
    fun trial _ =
        let
          val cap = 1 + randInt 256
          val k = randInt (cap + 1)            (* how many inserts to attempt *)
          val idxs = List.tabulate (k, fn _ => randInt cap)
          val bs = B.fromList cap idxs
          val arr = refArray cap idxs
          val n = B.count bs
          (* rank agrees at every boundary in [0, cap], plus past-the-end *)
          fun checkRank i =
              if i > cap + 2 then ()
              else (if B.rank bs i <> refRank arr i then rankOk := false else ();
                    checkRank (i + 1))
          val () = checkRank 0
          (* select agrees for every k in [0, n], and round-trips for k < n *)
          fun checkSel kk =
              if kk > n then ()
              else
                (if B.select bs kk <> refSelect arr kk then selectOk := false
                 else ();
                 (case B.select bs kk of
                      SOME i => if B.rank bs i <> kk then roundOk := false else ()
                    | NONE => ());
                 checkSel (kk + 1))
          val () = checkSel 0
        in () end
    val () = List.app trial (List.tabulate (trials, fn i => i))
    val () = check "randomized rank matches bool-array reference" (!rankOk)
    val () = check "randomized select matches bool-array reference" (!selectOk)
    val () = check "randomized rank(select k) = k round-trip" (!roundOk)
  in
    Harness.run ()
  end
end
