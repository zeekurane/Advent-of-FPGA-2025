# Advent-of-FPGA-2025

# Day 1 - Secret Entrance (Dial Rotation)

## Table of Contents
* [Problem Statement Summary](#problem-statement-summary-full-problem-statement-day-1-secret-entrance)
* [Format of input commands](#format-of-commands-inside-input_filetxt)
* [Apprach in Brief](#approach-in-brief)
       * [Tinkering With The Problem](#tinkering-with-the-problem)
       * [Ideas](#ideas)
       * [Parsing Phase](#parsing-phase)
       * [FPGA Circuit](#fpga-circuit)
       * [Simulation Phase](#simulation-phase)
* [Architecture](#architecture)
* [Hardware Resources](#hardware-resources)
* [FPGA Challenge Performance Parameters](#fpga-challenge-performance-parameters)
* [How To RUN?](#how-to-run)
       * [1. Create Your Input File](#1-create-your-input-file)
       * [2. Build and Run Simulation](#2-build-and-run-simulation)
       * [3. Get Results](#3-get-results)


## Problem Statement Summary (Full problem statement: [Day 1: Secret Entrance](https://adventofcode.com/2025/day/1))

The dial has positions [`0` - `99`], with 100 wrapping to `0`. Starting at position 50, process rotation commands:
- **Part 1**: Count how many times the dial lands exactly on zero
- **Part 2**: Count total number of times the dial crosses/passes through 0 (How many clicks lead to passing through zero)

## Format of commands inside `input_file.txt`
       R203
       L20
       R2
       R890
       ...
- Each command starts with uppercase letter `R` or `L` representing right/clockwise direction or left/anti-clockwise direction respectively, followed by natural numbers which represent number of dial turns/clicks in the direction said before.

## Approach In Brief
### Tinkering With The Problem

Started with understanding syntax and getting a feel of ocaml and hardcaml. Having already solved the AoC problems meant, I only needed to create a working (probably) solution in `HARDcaml`. Brainstormed a few different ways to solve this problem.

Definitely, this particular problem is sequential in nature due to its constarints like, we need to know how many times a command ends up the dial at `0`. Hence, we can't run the command process parallelly.

# Ideas:
- Apply each click per cycle. This idea is simple to implement and staright forward, but lacks performance and doesn't use the provided resources to its full extent.
- Use the modulo, division operators to simplify the process. This idea seemed better than previous one, but those operations on a fpga are heavy.

*Thought an idea*: If multiplication by `2` in decimal is exactly same as left-shift in binary, then same rule might also apply for other numbers too, right? Turns out multiplication and similar operations are just the implementation of same idea in binary (hardware-level).

       4*7 → 2*2*(6 + 1) → 2*2*(2*3 + 1) → 2*2*(2*(2 + 1) + 1) → 2*2*2*2 + 2*2*2 + 2*2 →  0000 0001 ← 4 left shift
        |                                                                               + 0000 0001 ← 3 left shift
        |                                                                               + 0000 0001 ← 2 left shift
        ↓                                                                               ---------------------------
        28                                                                                0001 0000
                                                                                        + 0000 1000
                                                                                        + 0000 0100
                                                                                        ------------
                                                                                          0001 1100 ← 28 in binary

**Key understandings**: Using Modulo, Division, Multi-variable multiplication arithmetics meant large performance loss. Solving it without these operators will boost the `speed` and proper usage of resources.

While exploring ways to provide input (rotation commands) for the hardware (FPGA), conceptualised that there should be atleast 11 bits (1 bit- direction, 10 bits- number of clicks/turns of dial which represent numbers from 0 to 1023) of information that needed to be pushed.

Thought about parsing (hardware parsing and software parsing) and finalised to parse commands in software due to following complexities:
       
1. Hardware Parsing would require knowledge of different communication protocols or atleast the format of data fed to circuit.
2. This challenge is immersive and enjoyable for the time being, creating a whole hardware system is FUN, but i need more free time for that to happen :(

### Parsing Phase

Created a prototype program in python for parsing of commands which needed to be fed to the circuit/fpga.
While playing with the secret entrance problem, noticed that number of clicks aren't larger than 1000 in the puzzle input file for AoC. Found out that, the number can be broken down into two seperate terms, one of which will only impact a total rotations of the dial and another which will impact the dial position aswell as the rotation.
                     
Split: `L203` → `(L, 2, 03)` = direction + hundreds + last two digits
- Hundreds represent full rotations (200 clicks = 2 complete dial rotations)
- These go directly to the crossing counter
- Only the last two digits actually change position and may increment crossing counter by 1
- **Avoids expensive division/modulo operations!**

Now, the input size has been increased from 11 bits to 12 bits (1 bit - Direction, 7 bits - to represent last two digits in the command, 4 bits - representation of middle numbers) but the fpga complexity is reduced by great extent as it would've needed to convert binary data (the number) into two parts as mentioned above.

Converted the python parser program into ocaml program, as it was being inefficient for the overall process.

### FPGA Circuit

The position of the dial is always between 0 and 100, hence 7 bits are good enough for its representation, whereas the counters (registers which store subproblem 1 and 2's answer) are kindof depended on number of commands applied in one simulation. Hence, chose to keep it at 32 bits each, however for the sake of the AoC problem 16 bits would've been enough.

Psuedo-code for the hardware:

Consider `x` to be current position of the dial, `counter2` to be the number of times dial passes through zero.

       If R:
              if x + last_digits < 100
                     x = x + last_digits;
              else
                     x = x + last_digits - 100;
                     counter2 += 1;
              counter2 += middle_digits;

       If L:
              if last_digits < x
                     x = x - last_digits;
              else
                     x = x - last_digits + 100;
                     counter2 += 1;
              counter2 += middle_digits;

Let's see whether you can catch the `EXTRA hidden assumption` that creates problem in the above psuedocode or not.


Here's the thing,

**Problem:** `x + last_digits < 100`, doesn't it look a *bit* wrong?

`x` and `last_digits`, both are of 7 bits, when added the sum needs 8 bits (99 + 99 = 198) to be correctly represented. But, after some serious work I found the way through it. If we do, something like `x < (100 - last_digits)` then?

We don't need the 8th bit :)

Hence modified the psuedo-code to,

       If R:
              if x < (100 - last_digits)
                     x = x + last_digits;
              else
                     x = x - (100 - last_digits);
                     counter2 += 1;
              counter2 += middle_digits;

       If L:
              if last_digits < x
                     x = x - last_digits;
              else
                     x = x + (100 - last_digits);
                     counter2 += 1;
              counter2 += middle_digits;

### Simulation Phase

Now, its a piece of cake. Created a program which calls the parser program and gets the required commands in acceptable format. Then, it simulates the fpga program cycle by cycle and that's it. Let's run it.

The program didn't threw any errors, neither it printed right answers. So, I added some `"print"` statments and checked for the proper behaviour of each block of code. Found the bug! Dial wasn't set to 50 initially. FPGA same as some other hardware initialise with `0` at startup.
Hence, tried to have position register's value default to `50` at resets, but being a beginner at hardcaml, couldn't do it in stipulated time. Hence, implemented an another solution to this issue, by simply injecting `R50` command in the beginning of each simulation. It will use a cycle worth of more computation but that's acceptable.

## Architecture

### Single-Cycle Processing Pipeline
```
Input Command → [Parse] → [Position Update] → [Crossing Detection] → [Counters]
                  ↓              ↓                    ↓                  ↓
            (dir,mid,last)    New position      Did we cross 0?     Part1 & Part2
                                                                     
All in 1 clock cycle!
```

## Hardware Resources

- **Position register**: 7 bits (0-99, resets to 50)
- **Part 1 counter**: 32 bits (counts landings on 0)
- **Part 2 counter**: 32 bits (counts total crossings)
- **Combinational logic**: Comparators, adders, muxes
- **No division/modulo**: Only addition, subtraction, comparison

## FPGA Challenge Performance Parameters

✅ **Scalability**: Design handles 10× - 100x larger inputs by just changing bit widths  
✅ **Efficiency**: Single-cycle processing vs multi-cycle iterative approaches


## How To RUN?

### 1. Create Your Input File

Create an input text file with your AoC commands OR copy-paste-save commands in acceptable format inside `input.txt` file in the folder before running the executable file:

              R456
              L123
              R789
              ...

### 2. Build and Run Simulation

```bash
# Build with dune
dune build

# Run simulator (acceptable commands)

# command 1) <input_file.txt> refers to path to your input file or its name if its in same directory/folder
dune exec ./simulator.exe <input_file.txt>

# command 2) Leave it blank. The program will use the default `input.txt` file in the same folder
dune exec ./simulator.exe
```

### 3. Get Results

```
Subproblem 1 answer (lands on 0): 42
subproblem 2 answer (crosses 0): 156
Final dial position: 73
```


## License

MIT License - Free to use and modify

---

**Author**: Jishan Kurane  
**Challenge**: Jane Street Advent of FPGA 2025  
**Problem**: Advent of FPGA 2025 Day 1