(* demo.sml - packed bit-set operations: membership, persistent update, set
   algebra, complement, and rank/select. Deterministic: identical output on
   every run and both compilers. *)

fun ints xs = "[" ^ String.concatWith "," (List.map Int.toString xs) ^ "]"

val a = Bitset.fromList 20 [1,3,5,7,9,11]
val () = print ("a = " ^ ints (Bitset.toList a) ^ "\n")
val () = print ("  count a    = " ^ Int.toString (Bitset.count a) ^ "\n")
val () = print ("  capacity a = " ^ Int.toString (Bitset.capacity a) ^ "\n")

val () = print ("member a 5 = " ^ Bool.toString (Bitset.member a 5) ^ "\n")
val () = print ("member a 6 = " ^ Bool.toString (Bitset.member a 6) ^ "\n")

val a' = Bitset.add (Bitset.remove a 5) 6
val () = print "after remove 5, add 6:\n"
val () = print ("  a  = " ^ ints (Bitset.toList a) ^ "  (unchanged)\n")
val () = print ("  a' = " ^ ints (Bitset.toList a') ^ "\n")

val b = Bitset.fromList 20 [3,4,5,6]
val () = print ("b = " ^ ints (Bitset.toList b) ^ "\n")
val () = print ("union a b = " ^ ints (Bitset.toList (Bitset.union (a, b))) ^ "\n")
val () = print ("inter a b = " ^ ints (Bitset.toList (Bitset.inter (a, b))) ^ "\n")
val () = print ("diff  a b = " ^ ints (Bitset.toList (Bitset.diff  (a, b))) ^ "\n")

val small = Bitset.fromList 8 [0,2,4,6]
val () = print ("complement of " ^ ints (Bitset.toList small)
                ^ " over capacity 8: count = "
                ^ Int.toString (Bitset.count (Bitset.complement small)) ^ "\n")

(* rank/select are inverses on set bits: rank(select k) = k for k < count *)
val () = print ("rank a 6   = " ^ Int.toString (Bitset.rank a 6) ^ "\n")
val () = print ("select a 2 = " ^ (case Bitset.select a 2 of
                                      SOME i => Int.toString i
                                    | NONE => "NONE") ^ "\n")

val sum = Bitset.foldBits (fn (i, acc) => i + acc) 0 a
val () = print ("sum of set-bit indices in a = " ^ Int.toString sum ^ "\n")
