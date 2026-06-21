(* Dependency-free test runner for the Bitset structure.
 * Prints one line per assertion and exits non-zero if any assertion fails. *)

val passed = ref 0
val failed = ref 0

fun check (name : string) (cond : bool) : unit =
    if cond
    then (passed := !passed + 1; print ("ok   - " ^ name ^ "\n"))
    else (failed := !failed + 1; print ("FAIL - " ^ name ^ "\n"))

fun raisesSub (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Subscript => true | _ => false

fun raisesSize (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Size => true | _ => false

structure B = Bitset

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
  in
    print ("\n" ^ Int.toString (!passed) ^ " passed, "
           ^ Int.toString (!failed) ^ " failed\n");
    OS.Process.exit (if !failed = 0 then OS.Process.success else OS.Process.failure)
  end

val () = run ()
