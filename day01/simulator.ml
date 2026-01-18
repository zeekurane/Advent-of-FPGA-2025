open! Base
open Stdio
open Hardcaml

let run_simulation commands =
  printf "=== Advent of (CODE |: FPGA) Day 1 - Secret Entrance Simulator ===\n\n";
  
  (* Create simulator *)
  let module Sim = Cyclesim.With_interface (Hardware_core.Dial_rotation.I) (Hardware_core.Dial_rotation.O) in
  let scope = Scope.create ~flatten_design:true () in
  let sim = Sim.create (Hardware_core.Dial_rotation.create scope) in
  
  (* Total Reset *)
  Cyclesim.reset sim;

  (* Command R50 to move dial position needed as per the problem*)
  let inputs = Cyclesim.inputs sim in
    inputs.direction := Bits.of_int_trunc ~width:1 1;
    inputs.last_digits := Bits.of_int_trunc ~width:7 50;
    inputs.middle_digits := Bits.of_int_trunc ~width:4 0;
    inputs.valid := Bits.vdd;
    Cyclesim.cycle sim;
  
  (*
  (* Check initial state *)
  let outputs = Cyclesim.outputs sim in
  let initial_pos = Bits.to_int_trunc !(outputs.position) in
  printf "Initial state: position=%d, subproblem1_answer=0, subproblem2_answer=0\n\n" initial_pos;
  *)
  
  (* Process commands starts *)
  printf "Processing %d commands...\n" (List.length commands);
  
  List.iteri commands ~f:(fun _idx (dir, middle, last) ->
    let inputs = Cyclesim.inputs sim in
    inputs.direction := Bits.of_int_trunc ~width:1 dir;
    inputs.last_digits := Bits.of_int_trunc ~width:7 last;
    inputs.middle_digits := Bits.of_int_trunc ~width:4 middle;
    inputs.valid := Bits.vdd;
    Cyclesim.cycle sim;
    
    (*
    (* Progress every 100 commands *)
    if (idx + 1) % 100 = 0 then (
      let outputs = Cyclesim.outputs sim in
      let p1 = Bits.to_int_trunc !(outputs.count_part1) in
      let p2 = Bits.to_int_trunc !(outputs.count_part2) in
      let pos = Bits.to_int_trunc !(outputs.position) in
      printf "  After %d commands: pos=%d, part1=%d, part2=%d\n" (idx + 1) pos p1 p2
    )
    *)
  );
  
  (* Final results *)
  printf "\n=== Final Answer ===\n";
  let outputs = Cyclesim.outputs sim in
  let part1 = Bits.to_int_trunc !(outputs.count_part1) in
  let part2 = Bits.to_int_trunc !(outputs.count_part2) in
  let pos = Bits.to_int_trunc !(outputs.position) in
  printf "Subproblem 1 answer (lands on 0): %d\n" part1;
  printf "Subproblem 2 answer (crosses 0): %d\n" part2;
  printf "Final dial position: %d\n" pos

let () =
  printf "=== Day 1 - FPGA Simulator ===\n";
  printf "==============================\n\n";
  
  let argv = Sys.get_argv () in

  let input_file = 
    if Array.length argv > 1 then
      argv.(1)
    else
      "input.txt"
  in
  
  printf "Reading from: %s\n\n" input_file;
  
  (* Check if file exists *)
  if not (Stdlib.Sys.file_exists input_file) then (
    printf "Error: File '%s' not found!\n" input_file;
    printf "\nUsage: dune exec ./simulator.exe <input_file.txt>\n";
    Stdlib.exit 1
  );

  (* Parse input *)
  let commands = Parser.parse_file input_file in
  (* List.iter commands ~f:(fun(x, y, z) -> printf "(%d, %d, %d)\n" x y z); *)
  
  if List.is_empty commands then (
    printf "Error: No commands found in input file\n";
    Stdlib.exit 1
  );
  
  (* Run simulation *)
  run_simulation commands