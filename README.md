# sml-bitset

[![CI](https://github.com/sjqtentacles/sml-bitset/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-bitset/actions/workflows/ci.yml)

A small, portable packed bit-set for Standard ML.

`sml-bitset` stores a fixed-capacity set of small non-negative integers as a
packed array of bits, with the usual set algebra (`union`, `inter`, `diff`,
`complement`), population count, and ascending iteration. Updates are
persistent: every operation returns a new set and leaves its argument
unchanged.

Bits are packed 32 to a chunk regardless of the host compiler's native word
size, so behaviour is byte-for-byte identical on MLton (32-bit native words)
and Poly/ML (63-bit native words).

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads. Verified
on:

- **MLton**
- **Poly/ML**

The chunk type is a scalar `Word32.word` held in a plain `Array.array` (not
`Word32Array`, which Poly/ML lacks), masked to 32 logical bits.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-bitset
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-bitset/bitset.mlb
```

For Poly/ML, `use` the `bitset.sig` and `bitset.sml` sources in order.

## Usage

```sml
val a = Bitset.fromList 64 [1, 2, 3, 40, 63]
val b = Bitset.fromList 64 [2, 3, 4, 63]

val u = Bitset.union (a, b)        (* {1,2,3,4,40,63} *)
val i = Bitset.inter (a, b)        (* {2,3,63}        *)
val d = Bitset.diff  (a, b)        (* {1,40}          *)

val n = Bitset.count a             (* 5               *)
val xs = Bitset.toList u           (* [1,2,3,4,40,63] *)
val has = Bitset.member a 40       (* true            *)
```

`complement` is taken with respect to the set's capacity, and never exposes
phantom bits beyond it:

```sml
Bitset.equals (Bitset.complement (Bitset.empty 33), Bitset.full 33)  (* true *)
```

### Rank and select

`rank` and `select` are the usual succinct-structure primitives and are
inverses of each other on set bits.

`rank b i` counts the set bits at indices **strictly less than** `i`, i.e.
`rank(b, i) = #{ j < i : member(b, j) }`. The index `i` is clamped to
`[0, capacity]`, so `rank(b, 0) = 0` and `rank(b, i) = count b` for any
`i >= capacity` (no exception on an out-of-range `i`).

`select b k` returns the index of the `k`-th set bit, counting from `0` in
ascending order, or `NONE` when the set has fewer than `k + 1` set bits (which
includes every `k < 0`).

```sml
val b = Bitset.fromList 100 [0, 50, 99]

val r0 = Bitset.rank b 0     (* 0  — no bit below index 0          *)
val r1 = Bitset.rank b 1     (* 1  — bit 0 is below index 1        *)
val r2 = Bitset.rank b 50    (* 1  — bit 50 is not below index 50  *)
val rN = Bitset.rank b 1000  (* 3  — clamped to count              *)

val s0 = Bitset.select b 0   (* SOME 0   *)
val s1 = Bitset.select b 1   (* SOME 50  *)
val s3 = Bitset.select b 3   (* NONE     *)

(* round-trip on every set bit: rank (select k) = k for k < count *)
Bitset.rank b (valOf (Bitset.select b 1)) = 1                       (* true *)
```

## API summary

| Function | Description |
| --- | --- |
| `capacity : bitset -> int` | Number of bits the set can hold. |
| `empty : int -> bitset` | All-zero set of the given capacity. |
| `full : int -> bitset` | Every bit set, up to the capacity. |
| `fromList : int -> int list -> bitset` | Build from a capacity and indices. |
| `member : bitset -> int -> bool` | Membership test. |
| `add : bitset -> int -> bitset` | Persistent insert. |
| `remove : bitset -> int -> bitset` | Persistent delete. |
| `union / inter / diff : bitset * bitset -> bitset` | Set algebra (equal capacity). |
| `complement : bitset -> bitset` | Complement within the capacity. |
| `count : bitset -> int` | Population count. |
| `isEmpty : bitset -> bool` | Whether no bits are set. |
| `rank : bitset -> int -> int` | Set bits at indices strictly below `i`. |
| `select : bitset -> int -> int option` | Index of the k-th set bit (0-based). |
| `foldBits : (int * 'a -> 'a) -> 'a -> bitset -> 'a` | Fold set indices ascending. |
| `toList : bitset -> int list` | Set indices in ascending order. |
| `equals : bitset * bitset -> bool` | Structural equality. |

Indices are `0 .. capacity-1`. `add`/`remove`/`fromList` raise `Subscript` on
out-of-range indices; `empty`/`full` raise `Size` on negative capacity;
`union`/`inter`/`diff` raise `Size` on mismatched capacities. `member` on an
out-of-range index simply returns `false`.

## License

MIT. See [LICENSE](LICENSE).
