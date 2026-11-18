module rv32i_top (
    input clk,
    input rst_n
);
    logic [31:0] instr_code;
    logic [31:0] instr_addr;
    logic        dwe;
    logic [31:0] daddr;
    logic [31:0] dwdata;
    logic [31:0] drdata;
    logic [ 2:0] itype;

    instruction_rom U_INSTR_ROM (.*);
    rv32i_cpu U_RV32I_CPU (.*);
    data_memory U_DATA_MEM (.*);
endmodule

module rv32i_cpu (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] drdata,
    input  logic [31:0] instr_code,
    output logic [31:0] instr_addr,
    output logic        dwe,
    output logic [31:0] daddr,
    output logic [31:0] dwdata,
    output logic [ 2:0] itype
);
    logic rf_we, alusrc_sel, branch, jal, jalr, pc_en;
    logic [3:0] alu_control;
    logic [2:0] rfsrc_sel;

    control_unit U_CONTROL_UNIT (.*);

    datapath U_DATAPATH (.*);
endmodule
