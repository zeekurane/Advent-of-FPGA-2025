open! Base
open Hardcaml

module Dial_rotation = struct
  module I = struct
    type 'a t = { clock : 'a; clear : 'a; direction : 'a [@bits 1]; last_digits : 'a [@bits 7]; middle_digits : 'a [@bits 4]; valid : 'a [@bits 1]}
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = { count_part1 : 'a [@bits 32]; count_part2 : 'a [@bits 32]; position : 'a [@bits 7]; ready : 'a [@bits 1]}
    [@@deriving sexp_of, hardcaml]
  end

  let create _scope (i : _ I.t) =
    let open Signal in
    
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    
    (* Helper function to calculate new position and crossing *)
    let calculate_rotation pos last_dig is_right =
      (* RIGHT: if last >= (100-pos) then cross *)
      let hundred_minus_pos = of_int_trunc ~width:7 100 -: pos in
      let right_will_cross = last_dig >=: hundred_minus_pos in
      let right_new_pos = mux2 right_will_cross (last_dig -: hundred_minus_pos) (pos +: last_dig) in
      
      (* LEFT: if last >= pos then cross *)
      let left_will_cross = last_dig >=: pos in
      let last_minus_pos = last_dig -: pos in
      let left_new_pos = mux2 left_will_cross (of_int_trunc ~width:7 100 -: last_minus_pos) (pos -: last_dig) in
      
      (* Select based on direction *)
      let new_pos = mux2 is_right right_new_pos left_new_pos in
      let will_cross = mux2 is_right right_will_cross left_will_cross in
      ((mux2 (new_pos ==: (of_int_trunc ~width:7 100)) (zero 7) new_pos), (mux2 ((pos ==: (of_int_trunc ~width:7 100)) |: (pos ==: (zero 7))) (zero 1) will_cross)) in
    
    
    (* Position register *)
    let position_reg = reg_fb spec ~width:7 ~f:(fun pos_fb ->
      let pos = mux2 i.clear (of_int_trunc ~width:7 50) pos_fb in
      let (new_position, _) = calculate_rotation pos i.last_digits i.direction in
      mux2 i.valid new_position pos_fb
    ) in
    
    (* Calculate for counters (using current position before update) *)
    let pos = mux2 i.clear (of_int_trunc ~width:7 50) position_reg in
    let (new_position, extra_cross) = calculate_rotation pos i.last_digits i.direction in
    
    (* Total crossings *)
    let total_crossings = uresize ~width:5 i.middle_digits +: uresize ~width:5 extra_cross in
    
    (* Landed on zero check *)
    let landed_on_zero = new_position ==: zero 7 in
    
    (* Part 1 counter *)
    let count_part1_reg = reg_fb spec ~width:32 ~f:(fun count_fb ->
      let count = mux2 i.clear (zero 32) count_fb in
      let next = mux2 landed_on_zero (count +: one 32) count in
      mux2 i.valid next count
    ) in
    
    (* Part 2 counter *)
    let count_part2_reg = reg_fb spec ~width:32 ~f:(fun count_fb ->
      let count = mux2 i.clear (zero 32) count_fb in
      let next = count +: uresize ~width:32 total_crossings in
      mux2 i.valid next count
    ) in

    { O.count_part1 = count_part1_reg; count_part2 = count_part2_reg; position = position_reg; ready = vdd}
end