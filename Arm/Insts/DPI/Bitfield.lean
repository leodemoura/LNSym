/-
Copyright (c) 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author(s): Shilpi Goel, Nevine
-/
-- For now, support only UBFM (immediate) 32- and 64-bit versions
-- (aliased as LSR and LSL (immediate) among other aliases)

import Arm.Decode
import Arm.Insts.Common

namespace DPI

open BitVec

@[state_simp_rules]
def exec_bitfield (inst: Bitfield_cls) (s : ArmState) : ArmState :=
  if inst.opc != 0b10#2 then
    write_err (StateError.Unimplemented s!"Unsupported {inst} encountered!") s
  else
    let immr5 := inst.immr >>> 5
    let imms5 := inst.imms >>> 5
    if (inst.sf = 1 ∧ inst.N ≠ 1) ∨
      (inst.sf = 0 ∧ (inst.N ≠ 0 ∨ immr5 ≠ 0 ∨ imms5 ≠ 0)) then
      write_err (StateError.Illegal s!"Illegal {inst} encountered!") s
    else
      let datasize  := if inst.sf = 1#1 then 64 else 32
      let wtmask    := decode_bit_masks inst.N inst.imms inst.immr false datasize
      match wtmask with
      | none => write_err (StateError.Illegal s!"Illegal {inst} encountered!") s
      | some (wmask, tmask) =>
        let src := read_gpr_zr datasize inst.Rn s
        let bot := (BitVec.ror src inst.immr.toNat) &&& wmask
        let result := bot &&& tmask
        let s := write_gpr_zr datasize inst.Rd result s
        let s := write_pc ((read_pc s) + 4#64) s
        s


----------------------------------------------------------------------

/-- Generate random instructions of the DPI.Bitfield class. -/
partial def Bitfield_cls.ubfm.rand : IO (Option (BitVec 32)) := do
  -- Choose assignments based on sf that will not result in illegal instructions
  let sf := ← BitVec.rand 1
  let N := sf
  let immr := sf ++ (← BitVec.rand 5)
  let imms := sf ++ (← BitVec.rand 5)
  let (inst : Bitfield_cls) :=
    { sf    := sf,
      opc   := ← pure 0b10#2,
      N     := N,
      immr  := immr,
      imms  := imms,
       -- TODO: Do we need to limit Rn and Rd to be up to 30 as in
       -- Add_sub_imm?
      Rn    := ← BitVec.rand 5,
      Rd    := ← BitVec.rand 5 }
  pure (some (inst.toBitVec32))

-- (FIXME) We have a separate function to test LSR specifically
-- because we want to make sure it is hit during conformance testing,
-- which may not be the case when `Bitfield_cls.ubfm.rand` is used to
-- generate a small number of test cases.  Once we have conformance
-- testing running in CI, the volume of tests we'd be running will
-- eliminate the need to have alias-specific instruction generators.
partial def Bitfield_cls.lsr.rand : IO (Option (BitVec 32)) := do
  -- Specifically test the assignment that results in LSR
  let sf := ← BitVec.rand 1
  let N := sf
  let immr := sf ++ (← BitVec.rand 5)
  let imms := sf ++ 0b11111#5
  let (inst : Bitfield_cls) :=
    { sf    := sf,
      opc   := ← pure 0b10#2,
      N     := N,
      immr  := immr,
      imms  := imms,
       -- TODO: Do we need to limit Rn and Rd to be up to 30 as in
       -- Add_sub_imm?
      Rn    := ← BitVec.rand 5,
      Rd    := ← BitVec.rand 5 }
  pure (some (inst.toBitVec32))


def Bitfield_cls.rand : List (IO (Option (BitVec 32))) :=
  [ Bitfield_cls.lsr.rand,
    Bitfield_cls.ubfm.rand ]

----------------------------------------------------------------------

end DPI
