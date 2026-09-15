`timescale 1ns/1ps
// Compliance testbench for the RV32I core against relocated riscv-tests
// rv32ui images. Does NOT modify any RTL — it only overrides cpu's memory
// size parameters at instantiation and pokes memory contents in via
// hierarchical $readmemh, exactly like a real testbench is supposed to.
//
// Usage: vvp tb_compliance.vvp +testfile=compliance/build/<name>.hex

module tb_compliance;

    // Big enough to hold any relocated rv32ui image (largest is a few KB;
    // this gives ~16x headroom) without needing to touch cpu.v/dmem.v
    // defaults, which stay at 16 words for the FPGA build.
    localparam MEM_BITS  = 16;            // address bits [MEM_BITS+1:2]
    localparam MEM_WORDS = (1 << MEM_BITS);

    localparam TIMEOUT_CYCLES = 200000;

    reg clk;
    reg rst;
    wire [31:0] dbg;

    cpu #(
        .IMEM_WORDS(MEM_WORDS), .IMEM_BITS(MEM_BITS),
        .DMEM_WORDS(MEM_WORDS), .DMEM_BITS(MEM_BITS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .dbg(dbg)
    );

    always #5 clk = ~clk;

    reg [1023:0] testfile;
    integer      cycle_count;
    reg          done;

    // SYSTEM opcode, funct3==0, funct12==0 => ecall (as opposed to
    // ebreak/mret/etc., which share the same opcode/funct3).
    wire is_ecall = (dut.inst[6:0] == 7'b1110011) &&
                    (dut.inst[14:12] == 3'b000) &&
                    (dut.inst[31:20] == 12'h000);

    initial begin
        clk = 0;
        rst = 1;

        if (!$value$plusargs("testfile=%s", testfile)) begin
            $display("ERROR: pass +testfile=<path.hex>");
            $finish;
        end

        // cpu.v's own `initial $readmemh("program.hex", imem)` runs at
        // time 0 too; the #1 here guarantees ours runs strictly after,
        // overwriting whatever that loaded (or didn't). The riscv-tests
        // image is flattened and loaded into BOTH imem and dmem: this is
        // a Harvard machine, so imem supplies .text (fetch never touches
        // dmem) and dmem supplies .data/.bss (loads/stores never touch
        // imem) out of their own copies of the same image.
        #1;
        $readmemh(testfile, dut.imem);
        $readmemh(testfile, dut.u_dmem.mem);

        cycle_count = 0;
        done = 0;

        repeat (3) @(posedge clk);
        rst = 0;

        while (!done) begin
            @(posedge clk);
            #1; // let combinational inst/regfile settle before sampling

            if (is_ecall) begin
                done = 1;
                if (dut.u_rf.regs[10] == 0)
                    $display("PASS %s", testfile);
                else
                    $display("FAIL %s testnum=%0d", testfile, dut.u_rf.regs[3] >> 1);
            end else begin
                cycle_count = cycle_count + 1;
                if (cycle_count > TIMEOUT_CYCLES) begin
                    $display("TIMEOUT %s", testfile);
                    done = 1;
                end
            end
        end

        $finish;
    end

endmodule
