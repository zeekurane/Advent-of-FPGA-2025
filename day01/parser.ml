open! Base
open Stdio

let parse_command cmd_str =
  let cmd_str = String.strip cmd_str in
  if String.is_empty cmd_str then
    None
  else
    let direction_char = cmd_str.[0] in
    let direction_bit = 
      if Char.equal direction_char 'R' then 1
      else if Char.equal direction_char 'L' then 0
      else -1
    in
    
    if direction_bit = -1 then
      None
    else
      let num_str = String.sub cmd_str ~pos:1 ~len:(String.length cmd_str - 1) in
      let is_numeric = String.for_all num_str ~f:Char.is_digit in
      
      if not is_numeric then
        None
      else
        let (middle_digits, last_digits) = 
          if String.length num_str < 3 then
            (0, Int.of_string num_str)
          else
            let last_two = String.sub num_str 
              ~pos:(String.length num_str - 2) ~len:2 in
            let middle_part = String.sub num_str 
              ~pos:0 ~len:(String.length num_str - 2) in
            (Int.of_string middle_part, Int.of_string last_two)
        in
        Some (direction_bit, middle_digits, last_digits)

let parse_file filename =
  let commands = ref [] in
  let ic = In_channel.create filename in
  
  let line_num = ref 0 in
  In_channel.iter_lines ic ~f:(fun line ->
    line_num := !line_num + 1;
    let line = String.strip line in
    
    if not (String.is_empty line) && not (String.is_prefix line ~prefix:"#") then
      match parse_command line with
      | Some cmd -> commands := cmd :: !commands
      | None -> 
          printf "Line %d: Failed to parse '%s'\n" !line_num line;
          printf "Provide input in acceptable format!\n"
  );
  
  
  In_channel.close ic;
  List.rev !commands
  
