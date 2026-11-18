`define SIMULATION

module datapath (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        rf_we,
    input  logic        alusrc_sel,
    input  logic [ 2:0] rfsrc_sel,
    input  logic        branch,
    input  logic        pc_en,
    input  logic        jal,
    input  logic        jalr,
    input  logic [ 3:0] alu_control,
    input  logic [31:0] drdata,
    input  logic [31:0] instr_code,
    output logic [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata
);

    logic [31:0] alu_result, rf_rd1, rf_rd2;
    logic [31:0] alusrc_mux_out, rfsrc_mux_out, imm_extend, pcsrc_mux_out;
    logic [31:0] pc_4, pc_imm, pc_next;
    logic [31:0]
        dec2exe_rs1,
        dec2exe_rs2,
        dec2exe_imm,
        reg_pc_next,
        exe2mem_daddr,
        exe2mem_dwdata,
        mem2wb_drdata,
        reg_pc;
    logic b_taken;
    assign instr_addr = reg_pc;
    assign daddr = exe2mem_daddr;
    assign dwdata = exe2mem_dwdata;

    // DECODE
    reg_file U_REG_FILE (
        .clk(clk),
        .rst_n(rst_n),
        .ra1(instr_code[19:15]),
        .ra2(instr_code[24:20]),
        .wa(instr_code[11:7]),
        .wd(rfsrc_mux_out),
        .we(rf_we),
        .rd1(rf_rd1),
        .rd2(rf_rd2)
    );
    imm_extend U_IMM_EXTEND (
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    // DECODE to EXE
    register_32bit U_REG_RS1 (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (rf_rd1),
        .qout (dec2exe_rs1)
    );
    register_32bit U_REG_RS2 (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (rf_rd2),
        .qout (dec2exe_rs2)
    );
    register_32bit U_REG_IMM (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (imm_extend),
        .qout (dec2exe_imm)
    );

    // EXE
    mux_2x1 U_ALUSRC_MUX (
        .in0(dec2exe_rs2),
        .in1(dec2exe_imm),
        .sel(alusrc_sel),
        .mux_out(alusrc_mux_out)
    );
    mux_8x1 U_RFSRC_MUX (
        .in0(alu_result),
        .in1(mem2wb_drdata),
        .in2(dec2exe_imm),
        .in3(pc_imm),
        .in4(pc_4),
        .sel(rfsrc_sel),
        .mux_out(rfsrc_mux_out)
    );
    alu U_ALU (
        .rs1(dec2exe_rs1),
        .rs2(alusrc_mux_out),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .b_taken(b_taken)
    );

    // EXE to MEM
    register_32bit U_REG_DADDR (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (alu_result),
        .qout (exe2mem_daddr)
    );
    register_32bit U_REG_DWDATA (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (dec2exe_rs2),
        .qout (exe2mem_dwdata)
    );

    // MEM to WB
    register_32bit U_REG_DRDATA (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (drdata),
        .qout (mem2wb_drdata)
    );

    program_counter_next U_PC_NEXT (
        .b_taken(b_taken),
        .branch(branch),
        .imm_extend(dec2exe_imm),
        .rs1(dec2exe_rs1),
        .jal(jal),
        .jalr(jalr),
        .pc(reg_pc),
        .pc_next(pc_next),
        .pc_4(pc_4),
        .pc_imm(pc_imm)
    );
    register_32bit U_REG_PC_NEXT (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (pc_next),
        .qout (reg_pc_next)
    );
    register_pc U_REG_PC (
        .clk  (clk),
        .rst_n(rst_n),
        .pc_en(pc_en),
        .din  (reg_pc_next),
        .qout (reg_pc)
    );
endmodule


module reg_file (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [ 4:0] ra1,
    input  logic [ 4:0] ra2,
    input  logic [ 4:0] wa,
    input  logic [31:0] wd,
    input  logic        we,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] ram_file[0:31];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
`ifdef SIMULATION
            ram_file[0] <= 0;
`else
            ram_file[0] <= 0;
`endif
        end else begin
            if (we) ram_file[wa] <= wd;
        end
    end

    assign rd1 = (ra1 != 0) ? ram_file[ra1] : 32'd0;
    assign rd2 = (ra2 != 0) ? ram_file[ra2] : 32'd0;
endmodule


module alu (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [ 3:0] alu_control,
    output logic [31:0] alu_result,
    output logic        b_taken
);

    always_comb begin
        alu_result = 32'h0000_0000;
        case (alu_control)
            // {funct7[5], funct3}
            4'b0000: alu_result = rs1 + rs2;  // add
            4'b1000: alu_result = rs1 - rs2;  // sub
            4'b0100: alu_result = rs1 ^ rs2;  // xor
            4'b0110: alu_result = rs1 | rs2;  // or
            4'b0111: alu_result = rs1 & rs2;  // and
            4'b0001: alu_result = rs1 << rs2[4:0];  // sll
            4'b0101: alu_result = rs1 >> rs2[4:0];  // srl
            4'b1101: alu_result = $signed(rs1) >>> rs2[4:0];  // sra
            4'b0010: alu_result = ($signed(rs1) < $signed(rs2));  // slt
            4'b0011: alu_result = (rs1 < rs2);  // sltu

            // 4'b0001: alu_result = rs1 << rs2;  // sll
            // 4'b0101: alu_result = rs1 >> rs2;  // srl
            // 4'b1101: alu_result = $signed(rs1) >>> rs2;  // sra
        endcase
    end

    always_comb begin
        b_taken = 1'b0;
        case (alu_control)
            4'b0000: b_taken = (rs1 == rs2);
            4'b0001: b_taken = (rs1 != rs2);
            4'b0100: b_taken = ($signed(rs1) < $signed(rs2));
            4'b0101: b_taken = ($signed(rs1) >= $signed(rs2));
            4'b0110: b_taken = (rs1 < rs2);
            4'b0111: b_taken = (rs1 >= rs2);
        endcase
    end

endmodule


module program_counter_next (
    input  logic        b_taken,
    input  logic        branch,
    input  logic [31:0] imm_extend,
    input  logic [31:0] rs1,
    input  logic        jal,
    input  logic        jalr,
    input  logic [31:0] pc,
    output logic [31:0] pc_next,
    output logic [31:0] pc_4,
    output logic [31:0] pc_imm
);
    logic [31:0] imm_pc_rs1;
    logic        pcsrc_sel;

    assign pcsrc_sel = b_taken & branch;

    mux_2x1 U_MUX_PCRS1 (
        .in0(pc),
        .in1(rs1),
        .sel(jalr),
        .mux_out(imm_pc_rs1)
    );

    assign pc_4   = pc + 4;
    assign pc_imm = imm_pc_rs1 + imm_extend;

    mux_2x1 U_MUX_PCNEXT (
        .in0(pc_4),
        .in1(pc_imm),
        .sel(pcsrc_sel || jal),
        .mux_out(pc_next)
    );
endmodule


module imm_extend
    import rv32i_pkg::*;
(
    input  logic [31:0] instr_code,
    output logic [31:0] imm_extend
);
    opcode_e opcode;
    assign opcode = opcode_e'(instr_code[6:0]);
    always_comb begin
        imm_extend = 32'd0;
        case (opcode)
            OP_STYPE:
            imm_extend = {
                {20{instr_code[31]}}, instr_code[31:25], instr_code[11:7]
            };
            OP_ITYPE: begin
                if (instr_code[14:12] == 3'b101)
                    imm_extend = {{27{1'b0}}, instr_code[24:20]};
                else imm_extend = {{20{instr_code[31]}}, instr_code[31:20]};
            end
            OP_ILTYPE: begin
                imm_extend = {{20{instr_code[31]}}, instr_code[31:20]};
            end
            OP_BTYPE: begin
                imm_extend = {
                    {19{instr_code[31]}},
                    instr_code[31],
                    instr_code[7],
                    instr_code[30:25],
                    instr_code[11:8],
                    1'b0
                };
            end
            OP_UTYPE: begin
                imm_extend = {instr_code[31:12], 12'h000};
            end
            OP_UATYPE: begin
                imm_extend = {instr_code[31:12], 12'h000};
            end
            OP_JTYPE: begin
                imm_extend = {
                    {11{instr_code[31]}},
                    instr_code[31],
                    instr_code[19:12],
                    instr_code[20],
                    instr_code[30:21],
                    1'b0
                };
            end
            OP_JLTYPE: begin
                imm_extend = {{20{instr_code[31]}}, instr_code[31:20]};
            end
        endcase
    end
endmodule


module mux_2x1 (
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic        sel,
    output logic [31:0] mux_out
);
    assign mux_out = (sel) ? in1 : in0;
endmodule



module mux_8x1 (
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    input  logic [31:0] in3,
    input  logic [31:0] in4,
    input  logic [ 2:0] sel,
    output logic [31:0] mux_out
);
    always_comb begin
        mux_out = in0;
        case (sel)
            3'b000: mux_out = in0;
            3'b001: mux_out = in1;
            3'b010: mux_out = in2;
            3'b011: mux_out = in3;
            3'b100: mux_out = in4;
        endcase
    end
endmodule


module register_32bit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] din,
    output logic [31:0] qout
);
    always_ff @(posedge clk) begin
        if (!rst_n) qout <= 32'd0;
        else qout <= din;
    end
endmodule



module register_pc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pc_en,
    input  logic [31:0] din,
    output logic [31:0] qout
);
    always_ff @(posedge clk) begin
        if (!rst_n) qout <= 32'd0;
        else if (pc_en) qout <= din;
        else qout <= qout;
    end
endmodule
