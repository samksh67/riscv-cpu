module tb_alu;

    localparam int NUM_OPS = 10;

    // ---------------- DUT ----------------
    logic [31:0] a, b;
    logic [3:0]  op;
    logic [31:0] result;

    alu dut (.a(a), .b(b), .op(op), .result(result));

    // ---------------- transaction ----------------
    // One stimulus item. Values are weighted toward the corners where ALU
    // bugs actually live: uniform 32-bit randoms would essentially never
    // produce 0, -1, or the signed-overflow boundary.
    class Transaction;
        bit [31:0] a;
        bit [31:0] b;
        bit [3:0]  op;

        function void randomize_tr();
            op = $urandom_range(0, NUM_OPS-1);
            a  = pick_operand();
            b  = pick_shift_or_operand();
        endfunction

        function bit [31:0] pick_operand();
            int unsigned sel = $urandom_range(0, 9);
            case (sel)
                0: pick_operand = 32'h0000_0000;   // zero
                1: pick_operand = 32'hFFFF_FFFF;   // -1
                2: pick_operand = 32'h8000_0000;   // most negative
                3: pick_operand = 32'h7FFF_FFFF;   // most positive
                default: pick_operand = $urandom();
            endcase
        endfunction

        // shift amounts cluster at 0, 1, 31, 32 - the boundaries
        function bit [31:0] pick_shift_or_operand();
            int unsigned sel = $urandom_range(0, 9);
            case (sel)
                0: pick_shift_or_operand = 32'd0;
                1: pick_shift_or_operand = 32'd1;
                2: pick_shift_or_operand = 32'd31;   // max legal shift
                3: pick_shift_or_operand = 32'd32;   // one past - must wrap
                4: pick_shift_or_operand = 32'hFFFF_FFFF;
                // mid-range shift: coverage showed bin[2] was never reached,
                // because a uniform 32-bit random is almost always >= 32
                5: pick_shift_or_operand = $urandom_range(2, 30);
                default: pick_shift_or_operand = $urandom();
            endcase
        endfunction
    endclass

    // ---------------- reference model ----------------
    // Written from the ISA spec, independently of alu.v. Copying the RTL
    // here would make a shared misunderstanding agree with itself and the
    // bug would survive.
    function automatic logic [31:0] ref_model(
        input logic [31:0] ra, input logic [31:0] rb, input logic [3:0] rop);
        case (rop)
            4'd0: ref_model = ra + rb;                                     // ADD
            4'd1: ref_model = ra - rb;                                     // SUB
            4'd2: ref_model = ra & rb;                                     // AND
            4'd3: ref_model = ra | rb;                                     // OR
            4'd4: ref_model = ra ^ rb;                                     // XOR
            4'd5: ref_model = ra << rb[4:0];                               // SLL
            4'd6: ref_model = ra >> rb[4:0];                               // SRL
            4'd7: ref_model = $signed(ra) >>> rb[4:0];                     // SRA
            4'd8: ref_model = ($signed(ra) < $signed(rb)) ? 32'd1 : 32'd0; // SLT
            4'd9: ref_model = (ra < rb) ? 32'd1 : 32'd0;                   // SLTU
            default: ref_model = 32'd0;
        endcase
    endfunction

    // ---------------- functional coverage ----------------
    // Covergroup and coverpoint are unsupported by this simulator, so the
    // model is built explicitly: the same bins and crosses a covergroup
    // would declare, counted by hand.
    localparam int SIGN_BINS  = 2;   // negative, non-negative
    localparam int SHIFT_BINS = 5;   // 0, 1, 2-30, 31, >=32

    int cov_op    [NUM_OPS];
    int cov_sign  [SIGN_BINS];
    int cov_shift [SHIFT_BINS];
    int cross_op_sign  [NUM_OPS][SIGN_BINS];    // every op x operand sign
    int cross_op_shift [NUM_OPS][SHIFT_BINS];   // every op x shift bin

    function automatic int shift_bin(input bit [31:0] v);
        if (v >= 32) begin
            shift_bin = 4;               // shift amount that must wrap
        end else begin
            case (v[4:0])
                5'd0:    shift_bin = 0;
                5'd1:    shift_bin = 1;
                5'd31:   shift_bin = 3;
                default: shift_bin = 2;
            endcase
        end
    endfunction

    task automatic sample_coverage();
        int sb;
        int sg;
        sb = shift_bin(b);
        sg = int'(a[31]);
        cov_op[op]++;
        cov_sign[sg]++;
        cov_shift[sb]++;
        cross_op_sign[op][sg]++;
        cross_op_shift[op][sb]++;
    endtask

    function automatic real coverage_pct();
        int hit;
        int total;
        hit   = 0;
        total = 0;
        for (int i = 0; i < NUM_OPS; i++) begin
            total++; if (cov_op[i] > 0) hit++;
        end
        for (int i = 0; i < SIGN_BINS; i++) begin
            total++; if (cov_sign[i] > 0) hit++;
        end
        for (int i = 0; i < SHIFT_BINS; i++) begin
            total++; if (cov_shift[i] > 0) hit++;
        end
        for (int i = 0; i < NUM_OPS; i++)
            for (int j = 0; j < SIGN_BINS; j++) begin
                total++; if (cross_op_sign[i][j] > 0) hit++;
            end
        for (int i = 0; i < NUM_OPS; i++)
            for (int j = 0; j < SHIFT_BINS; j++) begin
                total++; if (cross_op_shift[i][j] > 0) hit++;
            end
        coverage_pct = 100.0 * real'(hit) / real'(total);
    endfunction

    // ---------------- scoreboard ----------------
    int pass_count = 0;
    int fail_count = 0;

    string op_name [NUM_OPS] = '{
        "ADD","SUB","AND","OR","XOR","SLL","SRL","SRA","SLT","SLTU"
    };

    task automatic check();
        logic [31:0] expected;
        expected = ref_model(a, b, op);
        if (result === expected) begin
            pass_count++;
        end else begin
            fail_count++;
            if (fail_count <= 10)
                $display("FAIL  %-4s  a=%h b=%h  got=%h  expected=%h",
                         op_name[op], a, b, result, expected);
        end
    endtask

    // ---------------- run ----------------
    Transaction tr;
    localparam int N = 20000;

    initial begin
        tr = new();

        for (int i = 0; i < N; i++) begin
            tr.randomize_tr();
            a  = tr.a;
            b  = tr.b;
            op = tr.op;
            #1;
            sample_coverage();
            check();
        end

        $display("");
        $display("=================================================");
        $display("  ALU constrained-random regression");
        $display("=================================================");
        $display("  transactions  : %0d", N);
        $display("  passed        : %0d", pass_count);
        $display("  failed        : %0d", fail_count);
        $display("  func coverage : %0.2f%%", coverage_pct());
        $display("");
        $display("  per-operation hits:");
        for (int i = 0; i < NUM_OPS; i++)
            $display("    %-4s %6d", op_name[i], cov_op[i]);
        $display("");
        $display("  coverage holes:");
        begin
            int holes = 0;
            for (int i = 0; i < NUM_OPS; i++)
                for (int j = 0; j < SHIFT_BINS; j++)
                    if (cross_op_shift[i][j] == 0) begin
                        $display("    %-4s x shift_bin[%0d]", op_name[i], j);
                        holes++;
                    end
            for (int i = 0; i < NUM_OPS; i++)
                for (int j = 0; j < SIGN_BINS; j++)
                    if (cross_op_sign[i][j] == 0) begin
                        $display("    %-4s x sign[%0d]", op_name[i], j);
                        holes++;
                    end
            if (holes == 0) $display("    none");
        end
        $display("=================================================");

        if (fail_count == 0) $display("  *** ALL CHECKS PASSED ***");
        else                 $display("  *** %0d MISMATCHES ***", fail_count);
        $display("");
        $finish;
    end

endmodule