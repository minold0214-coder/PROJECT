
module control_unit
  import rv32i_pkg::*; (
  input   logic         clk,
  input   logic         rst_n,
	input		logic [31:0]	instr_code,
  output  logic         pc_en,
	output	logic					rf_we,
  output  logic         alusrc_sel,
  output  logic         dwe,
  output  logic [ 2:0]  rfsrc_sel,
  output  logic         branch,
	output	logic	[ 3:0]	alu_control,
  output  logic         jal,
  output  logic         jalr,
  output  logic [ 2:0]  itype // instruction type : funct3
);
  typedef enum logic [3:0] {
    FETCH   = 4'd0,
    DECODE  = 4'd1,
    EXE_R   = 4'd2,
    EXE_I   = 4'd3,
    EXE_B   = 4'd4,
    EXE_J   = 4'd5,
    EXE_JL  = 4'd6,
    EXE_U   = 4'd7,
    EXE_UA  = 4'd8,
    EXE_IL  = 4'd9,
    EXE_S   = 4'd10,
    MEM_IL  = 4'd11,
    MEM_S   = 4'd12,
    WB      = 4'd13
  } state_e;

  state_e c_state, n_state;

  logic [2:0] funct3;
  assign funct3 = instr_code[14:12];

  opcode_e opcode;

  rv32i_btype_instr_e instr_b;
  rv32i_rtype_instr_e instr_r;

  always_ff @(posedge clk) begin
    if(!rst_n) begin
      c_state <= FETCH;
    end else begin
      c_state <= n_state;
    end
  end

  always_comb begin
    n_state = c_state;
    
    rfsrc_sel = 3'b000;
    alu_control = 4'b0000;
    case(c_state)
      FETCH: n_state = DECODE;
      DECODE: begin
        opcode = opcode_e'(instr_code[6:0]);
        instr_b = rv32i_btype_instr_e'(funct3);
        instr_r = rv32i_rtype_instr_e'({instr_code[30], funct3});
        case(opcode)
          OP_RTYPE:   n_state = EXE_R;
          OP_ITYPE:   n_state = EXE_I;
          OP_BTYPE:   n_state = EXE_B;
          OP_JTYPE:   n_state = EXE_J;
          OP_JLTYPE:  n_state = EXE_JL;
          OP_UTYPE:   n_state = EXE_U;
          OP_UATYPE:  n_state = EXE_UA;
          OP_ILTYPE:  n_state = EXE_IL;
          OP_STYPE:   n_state = EXE_S;
        endcase
      end
      EXE_R: begin
        n_state = FETCH;
				alu_control	= {instr_code[30], funct3};
      end
      EXE_I: begin
        n_state = FETCH;
        if (funct3 == 3'b101) alu_control	= {instr_code[30], funct3};
        else alu_control	= {1'b0, funct3};
      end
      EXE_B: begin
        n_state = FETCH;
        alu_control = {1'b0 ,funct3};
      end
      EXE_J: begin
        n_state = FETCH;
        rfsrc_sel = 3'b100;
      end
      EXE_JL: begin
        n_state = FETCH;
        rfsrc_sel = 3'b100;
      end
      EXE_U: begin
        n_state = FETCH;
        rfsrc_sel = 3'b010;
      end
      EXE_UA: begin
        n_state = FETCH;
        rfsrc_sel = 3'b011;
      end
      EXE_IL: n_state = MEM_IL;
      EXE_S: n_state = MEM_S;
      MEM_IL: n_state = WB;
      MEM_S: n_state = FETCH;
      WB: begin
        n_state = FETCH;
        rfsrc_sel = 3'b001;
      end
    endcase
  end

  assign alusrc_sel = ((c_state == EXE_S) || (c_state == EXE_I) || (c_state == EXE_IL)) ? 1'b1 : 1'b0;
  assign dwe = (c_state == MEM_S) ? 1'b1 : 1'b0;
  assign rf_we = ((c_state == EXE_R) || (c_state == EXE_I) || (c_state == EXE_J) || (c_state == EXE_JL) ||
                  (c_state == EXE_U) || (c_state == EXE_UA) || (c_state == WB)) ? 1'b1 : 1'b0;
  assign branch = (c_state == EXE_B) ? 1'b1 : 1'b0;
  assign itype = ((c_state == MEM_S) || (c_state == MEM_IL)) ? funct3 : 3'b111;
  assign jal = ((c_state == EXE_J) || (c_state == EXE_JL)) ? 1'b1 : 1'b0;
  assign jalr = (c_state == EXE_JL) ? 1'b1 : 1'b0;
  assign pc_en = (c_state == FETCH) ? 1'b1 : 1'b0;

endmodule

