
module instruction_rom (
	input		logic [31:0] instr_addr,
	output	logic [31:0] instr_code
);

	logic [31:0] instr_rom [0:127];

  `ifdef SIMULATION_TEST

	initial begin
		// R - type
    instr_rom[0]  = 32'h0074_04b3;  // add x9, x8, x7             (x9 <- 8 + 7)
    instr_rom[1]  = 32'h4074_0533;  // sub x10, x8, x7            (x10 <- 8 - 7)

    instr_rom[2]  = 32'h0062_c133;  // xor x2, x5, x6             (x2 <- 0101 ^ 0110)
    instr_rom[3]  = 32'h0062_e1b3;  // or x3, x5, x6              (x3 <- 0101 | 0110)
    instr_rom[4]  = 32'h0062_f233;  // and x4, x5, x6             (x4 <- 0101 & 0110)

    instr_rom[5]  = 32'h0018_15b3;  // sll x11, x16, x1           (x11 <- 32'h8000_0000 << 1)
    instr_rom[6]  = 32'h0018_5633;  // srl x12, x16, x1           (x12 <- 32'h8000_0000 >> 1)
    instr_rom[7]  = 32'h4018_56b3;  // sra x13, x16, x1           (x13 <- 32'h8000_0000 >>> 1)

    instr_rom[8]  = 32'h00e7_a933;  // slt x18, x15, x14          (x18 <- signed(15) < signed(14))
    instr_rom[9]  = 32'h0107_a9b3;  // slt x19, x15, x16          (x19 <- signed(15) < signed(32'h8000_0000))
    instr_rom[10] = 32'h0108_aa33;  // slt x20, x17, x16          (x20 <- signed(32'h8000_0001) < signed(32'h8000_0000))
    instr_rom[11] = 32'h0107_bab3;  // sltu x21, x15, x16         (x21 <- unsigned(15) < unsigned(32'h8000_0000))

    // S - type
    instr_rom[12] = 32'h0053_2323;  // sw x5, 6(x6)               (mem_byte[6+6](mem_word[3]) <- 32'h0000_0005)
    instr_rom[13] = 32'h0053_1623;  // sh x5, 12(x6)              (mem_byte[6+12](mem_word[4] [31:16]) <- 16'h0005)
    instr_rom[14] = 32'h0053_07a3;  // sb x5, 15(x6)              (mem_byte[6+15](mem_word[5] [15:8]) <- 8'h05)

    // I - type
    instr_rom[15] = 32'h0084_0493;  // addi x9, x8, 8             (x9 <- 8 + 8)

    instr_rom[16] = 32'h0042_c113;  // xori x2, x5, 4             (x2 <- 0101 ^ 0100)
    instr_rom[17] = 32'h0042_e193;  // ori x3, x5, 4              (x3 <- 0101 | 0100)
    instr_rom[18] = 32'h0072_f213;  // andi x4, x5, 7             (x4 <- 0101 & 0111)

    instr_rom[19] = 32'h0028_9593;  // slli x11, x17, 2           (x11 <- 32'h8000_0001 << 2)
    instr_rom[20] = 32'h0028_5613;  // srli x12, x16, 2           (x12 <- 32'h8000_0000 >> 2)
    instr_rom[21] = 32'h4028_5693;  // srai x13, x16, 2           (x13 <- 32'h8000_0000 >>> 2)

    instr_rom[22] = 32'h0107_a913;  // slti x18, x15, 16          (x18 <- signed(15) < 16)
    instr_rom[23] = 32'h8007_a993;  // slti x19, x15, 12'h800     (x19 <- signed(15) < 12'h800)
    instr_rom[24] = 32'h8008_aa13;  // slti x20, x17, 12'h800     (x20 <- signed(32'h8000_0001) < signed(12'h800))
    instr_rom[25] = 32'h8007_ba93;  // sltiu x21, x15, 12'h800    (x21 <- unsigned(15) < unsigned(12'h800))

    // LI - type
    instr_rom[26] = 32'h0063_2c03;  // lw x24, 6(x6)              (x24 <- mem_byte[6+6](mem_word[3]))
    instr_rom[27] = 32'h0083_1c83;  // lh x25, 8(x6)              (x25 <- mem_byte[6+8](mem_word[3]))
    instr_rom[28] = 32'h0093_0d03;  // lb x26, 9(x6)              (x26 <- mem_byte[6+9](mem_word[3]))
    instr_rom[29] = 32'h0083_5d83;  // lhu x27, 8(x6)             (x27 <- mem_byte[6+8](mem_word[3]))
    instr_rom[30] = 32'h0093_4e03;  // lbu x28, 9(x6)             (x28 <- mem_byte[6+9](mem_word[3]))

    // B - type
    //
    //instr_rom[31] = 32'hf862_92e3;  // bne x5, x6, -62          (x5 != x6 -> PC = PC - 124)

    // U - type

    instr_rom[32] = 32'h0000_cf37;  // lui x30, 32'h0000_c000     (x30 <- 32'h0000_c000)
    instr_rom[33] = 32'h0000_cf97;  // auipc x31, 32'h0000_c000   (x31 <- PC + 32'h0000_c000)
    //
    // J - type
    instr_rom[31] = 32'h0060_0eef;  // jal x29, 6                 (x29 <- PC, PC <- PC + 12)
    instr_rom[34] = 32'hfc2e_8f67;  // jalr x30, -62(x29)         (x30 <- PC + 4, PC <- x29 -62)

  end
  `endif

  initial begin
    $readmemh("./rtl/rom_code_ex1.mem",instr_rom, 0, 33);
  end

	assign instr_code = instr_rom[instr_addr[31:2]];
endmodule



