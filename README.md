# riscv-cpu

A single-cycle RV32I processor written from scratch in Verilog, verified with self-checking testbenches, and running on a Lattice iCE40 HX8K FPGA.

Built to understand what actually happens between an instruction being fetched and a register being written — and to practise the debug loop that verification work runs on.

---

## Results

| Metric | Value |
|---|---|
| Target device | iCE40 HX8K-CB132 (Alchitry Cu) |
| Logic cells | 632 LUT4 / 7,680 (8%) |
| Flip-flops | 643 |
| Max frequency | **78.28 MHz** |
| Critical path | 3.95 ns logic, 8.82 ns routing |
| Instructions | 37 / 37 RV32I base |
| Status | Verified in simulation and on hardware |

The critical path is routing-dominated — 8.82 ns of wire delay against 3.95 ns of logic. On a chip this empty the placer has no pressure to pack blocks tightly, so signals travel further than they need to. A denser design or explicit placement constraints would close some of that gap.

---

## Instruction set

Complete RV32I base integer set:

- **Arithmetic / logic** — `add` `sub` `and` `or` `xor` `sll` `srl` `sra` `slt` `sltu`
- **Immediate forms** — `addi` `andi` `ori` `xori` `slli` `srli` `srai` `slti` `sltiu`
- **Loads** — `lw` `lh` `lhu` `lb` `lbu`
- **Stores** — `sw` `sh` `sb`
- **Branches** — `beq` `bne` `blt` `bge` `bltu` `bgeu`
- **Jumps** — `jal` `jalr`
- **Upper immediate** — `lui` `auipc`

---

## Toolchain

Entirely open-source, running natively on macOS — no vendor licences, no virtual machine.

| Tool | Purpose |
|---|---|
| Icarus Verilog | Simulation |
| VaporView | Waveform inspection |
| Yosys | Synthesis |
| nextpnr-ice40 | Place and route |
| IceStorm (`icepack`, `iceprog`) | Bitstream packing and programming |

```bash
brew install icarus-verilog yosys nextpnr-ice40 icestorm
```

---

## Building

### Simulation

```bash
iverilog -o sim_rf  tb_regfile.v regfile.v && ./sim_rf
iverilog -o sim_alu tb_alu.v alu.v         && ./sim_alu
iverilog -o sim_dec tb_decoder.v decoder.v && ./sim_dec
iverilog -o sim_cpu tb_cpu.v cpu.v decoder.v control.v regfile.v alu.v dmem.v && ./sim_cpu
```

Each testbench self-checks, prints PASS/FAIL per case, and dumps a VCD for waveform inspection.

### Hardware

```bash
yosys -p "read_verilog top.v cpu.v decoder.v control.v regfile.v alu.v dmem.v; synth_ice40 -top top -json top.json"
nextpnr-ice40 --hx8k --package cb132 --json top.json --pcf cu.pcf --asc top.asc
icepack top.asc top.bin
iceprog top.bin
```

The program is loaded from `program.hex` at synthesis time via `$readmemh`, so it becomes part of the bitstream.

---

## Architecture

```
PC ──> Instruction Memory ──> Decoder ──> Control
                                 │           │
                                 v           v
                          Register File ──> Mux ──> ALU ──> Data Memory
                                 ^                             │
                                 └─────────────────────────────┘
                                        write back
```

One clock cycle per instruction. Only the program counter, the register file write port, and the data memory write are sequential; everything else is combinational.

### Modules

| File | Responsibility | Sequential |
|---|---|---|
| `regfile.v` | 32 × 32-bit registers, 2 read / 1 write | write only |
| `alu.v` | 10 operations | no |
| `decoder.v` | Field extraction, immediate generation | no |
| `control.v` | Opcode → control signal mapping | no |
| `dmem.v` | Byte-addressable data memory | write only |
| `cpu.v` | Datapath wiring, PC, instruction memory | PC only |
| `top.v` | FPGA top level, clock divider, LED output | yes |

**`regfile.v`** — `x0` is hardwired to zero, enforced on both the read path (returns zero regardless of stored contents) and the write path (writes are blocked).

**`alu.v`** — Signed and unsigned comparison are separate operations, as are logical and arithmetic right shift. Both distinctions produce different results from identical bit patterns and are easy to get silently wrong.

**`decoder.v`** — Reconstructs and sign-extends immediates for I, S, B, U and J formats. RISC-V scatters immediate bits across the instruction word differently per format, deliberately, to keep most bits in fixed physical positions.

**`control.v`** — Every output is assigned a safe default before the case statement. An incomplete case in combinational logic infers a latch, which synthesis warns about and simulation does not.

**`dmem.v`** — Word-addressed storage with byte and halfword access built on read-modify-write: a partial store reads the containing word, replaces the addressed bytes, and writes the whole word back.

### Three muxes

Every decision in the datapath is a multiplexer driven by one control signal:

| Mux | Selects between | Driven by |
|---|---|---|
| ALU operand B | `rs2_data` or `imm` | `alu_src` |
| Register write data | return address / `imm` / `pc+imm` / memory / ALU | `jump`, `lui`, `auipc`, `mem_to_reg` |
| Next PC | `pc+4` / `pc+imm` / `rs1+imm` | `branch`, `jump`, `jalr` |

---

## Verification

Modules are tested in isolation before integration, so a failure localises to one block rather than the whole datapath.

Testbenches drive stimulus on the **negative** clock edge while the design samples on the **positive** edge. This keeps inputs stable for half a cycle before capture and avoids the race conditions that arise when both sides move on the same edge — the simulator's event ordering shouldn't decide whether a test passes.

### Corner cases

Directed tests target the places where a plausible-looking implementation is silently wrong:

- **Sign extension** — `addi x1, x0, -1` confirms the immediate stays negative through extension rather than becoming 4095.
- **Signed vs unsigned comparison** — identical bit patterns compared both ways. `slt(-5, 3)` returns 1; `sltu` with the same inputs returns 0, because unsigned reads `0xFFFFFFFB` as a large positive value.
- **Arithmetic vs logical right shift** — `-8 >>> 1` gives -4; `-8 >> 1` gives 2,147,483,644. Same input, same distance, different fill bit.
- **`x0` protection** — writes to `x0` are attempted and confirmed to have no effect.
- **Branch inversion** — every branch test includes the case where the condition is *false*. A branch unit that always fires passes a suite that only tests taken branches.
- **Poison instructions** — the instructions a taken branch should skip write a sentinel value. Checking that the sentinel is absent proves the skip happened, rather than only that the destination was reached.
- **Partial stores** — `sb` writing `0xFF` into byte 3 of `0x12345678` must yield `0xFF345678`, not `0x000000FF`. This is the check that catches a read-modify-write that clobbers the whole word.

---

## Bugs and debugging notes

Kept deliberately. The debugging is most of the work and the part worth reading.

### The decoder tested wrong, not the decoder

Three decoder tests failed on I-type instructions. `rd`, `rs1` and `imm` were correct; only `rs2` mismatched.

The cause was the testbench. `rs2` is a fixed bit slice — `inst[24:20]` — extracted unconditionally. On I-type instructions those bits aren't a register field; they're the low five bits of the immediate. For `addi x1, x0, 10` the decoder reported `rs2 = 10`, exactly what those bits contain. The expected values had assumed zero.

Downstream logic ignores `rs2` when the opcode is I-type, so the field's contents are irrelevant rather than required to be zero.

**Takeaway:** a failing test means the design is wrong *or* the test is wrong. Telling them apart means deriving from the spec what the bits should be. Reflexively "fixing" the decoder here would have broken a correct module.

### A signal can be correct and still not connected

`lw` returned the memory *address* instead of the loaded value. Tracing showed `write_data` was 42 — the correct value — yet the register captured 20, the ALU result, on every run.

The tell was that the wrong answer was consistently *another signal's* value, across three test runs with three different addresses. That pattern points at wiring, not logic.

The register file was still instantiated with `.rd_data(alu_result)` from before the load path existed. `write_data` was computed correctly and consumed by nothing. Watching a signal in a trace says nothing about whether anything is connected to it.

Found by reproducing the design in a clean environment and diffing against the working version.

### Synthesis deleted the entire CPU

The first synthesis run reported zero cells. Yosys had optimised away the whole design.

The debug output was wired to `regs[5]`, and the test program never writes to `x5`. Yosys proved the output was constant zero, so everything feeding it was dead logic. Simulation had never noticed, because the testbench reached into the hierarchy with `dut.u_rf.regs[3]` — a path that doesn't exist in hardware.

Two related problems surfaced in the same investigation:

- `imem[pc[31:2]]` uses a 30-bit index into a 64-entry array. Simulation truncates silently; synthesis treats almost the whole range as out-of-bounds.
- `reg [31:0] pc;` with no initial value is `x` at synthesis time, which lets the optimiser fold downstream logic to constants.

**Takeaway:** in simulation, anything observable exists. In synthesis, only what reaches a pin exists. A design that simulates perfectly can synthesise to nothing.

### It fitted in simulation and not on the chip

First successful synthesis: 7,490 LUTs and 8,322 flip-flops against 7,680 available logic cells. Over budget on both.

`Number of memories: 0` in the report was the clue. A 64-word instruction memory and a 256-word data memory had been built from flip-flops rather than inferred into block RAM, because both have combinational reads and iCE40 block RAM requires a registered read port.

Resolved for now by shrinking both memories to 16 words, which brought the design to 632 LUTs and 643 flip-flops — 8% of the device. The proper fix is synchronous reads, which would need the datapath restructured to absorb the extra cycle of latency.

**Takeaway:** memory inference rules are a synthesis concern with no simulation equivalent. A memory that works in a testbench may be physically unbuildable.

### An infinite loop in a test program

A `jalr` test passed all its checks while the PC sat at address 20 forever. The jump target register held 20 — the address of the `jalr` instruction itself, so it jumped to itself indefinitely.

The assertions still passed because everything they checked happened before the loop began. A test can be green and still be wrong about what it exercised.

### Toolchain: every source build failing at once

Multiple unrelated Homebrew packages failed with `fatal error: 'cstdint' file not found`. The cause was a broken Command Line Tools installation with missing C++ SDK headers, which breaks every from-source build — and on an Intel Mac, where prebuilt bottles are no longer published, that is nearly everything.

A second, independent failure: `gmplib.org` was unreachable from the network in use, so one dependency could not fetch its source at all. Worked around by downloading the tarball from a kernel.org mirror and placing it in Homebrew's cache under the filename returned by `brew --cache --build-from-source gmp`.

**Takeaway:** two unrelated environment failures presenting as one symptom. Separating them was most of the work.

---

## Scope

Design decisions and their consequences, stated up front:

- **Single-cycle by design.** One instruction per clock, so the critical path spans the whole datapath. A pipelined implementation would clock significantly faster at the cost of hazard handling.
- **16-word memories.** Sized to fit the device without block RAM inference. Enough for the test programs; a larger design would need synchronous reads.
- **Verified with directed tests**, not the official compliance suite. Conformance is demonstrated against hand-written corner cases rather than formally proven.

## What I'd do differently

**Write the build automation on day one.** Every test was a hand-typed `iverilog` invocation with the full file list. That is tolerable for two modules and actively discourages running the full suite once there are seven.

**Keep every testbench as its own file.** Test programs were repeatedly overwritten in a single `tb_cpu.v`, so earlier coverage was lost as new instructions were added. A regression suite would have caught breakage during the FPGA changes.

**Synthesise earlier.** The design was fully verified in simulation before the first synthesis run, and synthesis then exposed a class of problems — dead outputs, out-of-range indices, memory inference — that simulation structurally cannot find. Running synthesis after the first working instruction would have surfaced all of them a week sooner.

**Reconsider the memory interface.** Combinational reads made the single-cycle datapath simple and made block RAM inference impossible. That trade-off was made implicitly on day one and only became visible at synthesis.

---

## References

- RISC-V Unprivileged ISA Specification, Volume I
- Harris & Harris, *Digital Design and Computer Architecture: RISC-V Edition*
- Project F and the IceStorm documentation, for the open-source FPGA flow
- Alchitry Cu schematic, for pin assignments

---

## Repository layout

```
regfile.v      tb_regfile.v
alu.v          tb_alu.v
decoder.v      tb_decoder.v
control.v
dmem.v
cpu.v          tb_cpu.v
top.v          cu.pcf         program.hex
```
