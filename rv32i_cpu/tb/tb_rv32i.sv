`include "uvm_macros.svh"
import uvm_pkg::*;

interface cpu_if (
    input clk
);
    logic rst_n;
    logic [31:0] drdata, daddr, dwdata;
    logic [31:0] instr_code, instr_addr;
    logic       dwe;
    logic [2:0] itype;

    // read only
    wire        rf_we;
    wire  [3:0] alu_control;
    wire  [4:0] wb_rd;
    wire [31:0] wb_data, rs1_data, rs2_data;
    wire [31:0] regs[0:31];

    assign drdata = 32'd0;

    clocking drv_cb @(negedge clk);
        default output #1;
        output rst_n, instr_code;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, instr_code, instr_addr, dwe;
        input rf_we, alu_control, wb_rd, wb_data, rs1_data, rs2_data;
    endclocking
endinterface

typedef enum int {
    R_ADD,
    R_SUB,
    R_SLL,
    R_SLT,
    R_SLTU,
    R_XOR,
    R_SRL,
    R_SRA,
    R_OR,
    R_AND,
    I_ADDI,
    I_SLTI,
    I_SLTIU,
    I_XORI,
    I_ORI,
    I_ANDI,
    I_SLLI,
    I_SRLI,
    I_SRAI
} cpu_op_e;

typedef enum int {
    VALUE_ZERO, VALUE_ONE, VALUE_MINUS_ONE, VALUE_MIN, VALUE_MAX,
    VALUE_POSITIVE, VALUE_NEGATIVE
} cpu_value_kind_e;
typedef enum int {REL_LESS, REL_EQUAL, REL_GREATER} cpu_relation_e;

// sequence item to drive
class cpu_seq_item extends uvm_sequence_item;
    rand cpu_op_e          op;
    rand bit        [ 4:0] rd,         rs1, rs2;
    rand bit signed [11:0] imm;
    rand bit        [ 4:0] shamt;
    bit             [31:0] instr_code;
    logic [31:0] src1_value, src2_value;  // coverage용 관측값, drive하지 않음

    constraint legal_op {op inside {[R_ADD : I_SRAI]};}
    constraint cornor_imm {
        imm dist {
            -2048          := 4,
            -1             := 4,
            0              := 4,
            1              := 4,
            2047           := 4,
            [-2047 :   -2] :/ 20,
            [    2 : 2046] :/ 20
        };
        shamt dist {
            0        := 3,
            1        := 3,
            31       := 3,
            [2 : 30] :/ 20
        };
    }

    function new(string name = "cpu_seq_item");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(cpu_seq_item)
        `uvm_field_enum(cpu_op_e, op, UVM_DEFAULT)
        `uvm_field_int(rd, UVM_DEFAULT)
        `uvm_field_int(rs1, UVM_DEFAULT)
        `uvm_field_int(rs2, UVM_DEFAULT)
        `uvm_field_int(imm, UVM_DEFAULT)
        `uvm_field_int(shamt, UVM_DEFAULT)
        `uvm_field_int(instr_code, UVM_DEFAULT)
        `uvm_field_int(src1_value, UVM_DEFAULT)
        `uvm_field_int(src2_value, UVM_DEFAULT)
    `uvm_object_utils_end

    function void encode();
        bit [ 2:0] funct3;
        bit [ 6:0] funct7;
        bit [11:0] immediate;
        funct7 = 0;
        case (op)
            R_ADD, R_SUB, I_ADDI:         funct3 = 3'b000;
            R_SLL, I_SLLI:                funct3 = 3'b001;
            R_SLT, I_SLTI:                funct3 = 3'b010;
            R_SLTU, I_SLTIU:              funct3 = 3'b011;
            R_XOR, I_XORI:                funct3 = 3'b100;
            R_SRL, R_SRA, I_SRLI, I_SRAI: funct3 = 3'b101;
            R_OR, I_ORI:                  funct3 = 3'b110;
            R_AND, I_ANDI:                funct3 = 3'b111;
            default:                      `uvm_fatal("ENCODE", "is not encoded")
        endcase
        if (op inside {R_SUB, R_SRA, I_SRAI}) funct7 = 7'b010_0000;
        if (op inside {R_ADD, R_SUB, R_SLL, R_SLT, R_SLTU, R_XOR, R_SRL, R_SRA, R_OR, R_AND})
            instr_code = {funct7, rs2, rs1, funct3, rd, 7'b011_0011};
        else begin
            immediate = imm;
            if (op inside {I_SLLI, I_SRLI, I_SRAI}) immediate = {funct7, shamt};
            instr_code = {immediate, rs1, funct3, rd, 7'b001_0011};
        end
    endfunction

    function void post_randomize();
        encode();
    endfunction

    virtual function string convert2string;
        return $sformatf(
            "%s rd=x%0d rs1=x%0d rs2=x%0d imm=%0d shamt=%0d insn=%08h",
            op.name(),
            rd,
            rs1,
            rs2,
            imm,
            shamt,
            instr_code
        );
    endfunction
endclass

// sequence // have to edit
class cpu_sequence extends uvm_sequence #(cpu_seq_item);
    `uvm_object_utils(cpu_sequence)

    function new(string name = "cpu_seq");
        super.new(name);
    endfunction

    // task
    // save item 1 time
    task emit(cpu_op_e op, int rd, int rs1, int rs2 = 0, int imm = 0,
              int shamt = 0);
        cpu_seq_item cpu_item;
        cpu_item = cpu_seq_item::type_id::create("directed_item");
        start_item(cpu_item);
        cpu_item.op    = op;
        cpu_item.rd    = rd;
        cpu_item.rs1   = rs1;
        cpu_item.rs2   = rs2;
        cpu_item.imm   = imm;
        cpu_item.shamt = shamt;
        cpu_item.encode();
        finish_item(cpu_item);
    endtask

    // prepare test
    task prepare_register();
        // xr, x0, 0 for xr = r
        for (int r = 1; r < 32; r++) begin
            emit(I_ADDI, r, 0, 0, r);
        end

        // set for neg num, bigger than 31
        emit(I_ADDI, 1, 0, 0, -1);  // x1 = 0xffff_ffff (-1)
        emit(I_ADDI, 2, 0, 0, 32);  // x2 = 32 : for R-type shift check

        emit(I_ADDI, 3, 0, 0, 1);  // x3 = 1
        emit(I_SLLI, 3, 3, 0, 0, 31);  // x3 = 0x8000_0000 : signed at least

        emit(I_ADDI, 4, 3, 0, -1);  // x4 = 0x7fff_ffff : signed at most
    endtask

    // directed test
    task directed_tests();
        // R type 10time save at x20
        emit(R_ADD, 20, 5, 6);  // 5 + 6 = 11
        emit(R_SUB, 20, 5, 6);  // 5 - 6 = -1
        emit(R_SLL, 20, 5, 1);  // 5 << 31 = 0x8000_0000
        emit(R_SLT, 20, 1, 5);  // signed : -1 < 5 = 1
        emit(R_SLTU, 20, 1, 5);  // unsigned : 0xffff_ffff < 5 = 0
        emit(R_XOR, 20, 5, 6);  // 5 ^ 6 = 3
        emit(R_SRL, 20, 3, 1);  // 0x8000_0000 >> 31 = 1
        emit(R_SRA, 20, 3, 1);  // shift right 0xffff_ffff
        emit(R_OR, 20, 5, 6);  // 5 | 6 = 7
        emit(R_AND, 20, 5, 6);  // 5 & 6 = 4

        // R type shift : rs2 = 32 move x
        emit(R_SLL, 20, 5, 2);  // expected 5
        emit(R_SRL, 20, 3, 2);  // expected 0x8000_0000
        emit(R_SRA, 20, 3, 2);  // expected 0x8000_0000

        // I type ALU 9time
        emit(I_ADDI, 20, 5, 0, -1);  // 5 + (-1) = 4
        emit(I_SLTI, 20, 1, 0, 1);  // signed (-1) < 1 = 1
        emit(I_SLTIU, 20, 5, 0, -1);  // unsigned: 5 < 0xffff_ffff = 1
        emit(I_XORI, 20, 5, 0, -1);  // bit inversion
        emit(I_ORI, 20, 5, 0, 2);  // 5 | 2 = 7
        emit(I_ANDI, 20, 5, 0, 3);  // 5 & 3 = 10
        emit(I_SLLI, 20, 5, 0, 0, 1);  // 5 << 1 = 1
        emit(I_SRLI, 20, 3, 0, 0, 31);  // logical right shift : 1
        emit(I_SRAI, 20, 3, 0, 0, 31);  // arithmetic right shift : -1

        // max, min edge
        emit(I_ADDI, 20, 0, 0, -2048);  // 12bit signed at least
        emit(I_ADDI, 20, 0, 0, 2047);  // 12bit signed at most
        emit(I_ADDI, 20, 4, 0, 1);  // 0x7fff_ffff + 1 = 0x8000_0000
        emit(I_ADDI, 20, 3, 0, -1);  // 0x8000_0000 - 1 = 0x7fff_ffff
    endtask

    // random test item
    // mode = 0 : r type, 1 : i type, 2: both
    task random_tests(int count, int mode);
        cpu_seq_item cpu_item;

        repeat (count) begin
            cpu_item = cpu_seq_item::type_id::create("random_item");
            start_item(cpu_item);

            if (!cpu_item.randomize() with {
                    if (local:: mode == 0) op inside {[R_ADD : R_AND]};

                    if (local:: mode == 1) op inside {[I_ADDI : I_SRAI]};
                })
                `uvm_fatal("SEQ", "randomize failed")

            finish_item(cpu_item);
        end
    endtask
    virtual task body();
        `uvm_info("SEQ", "prepare for directed test", UVM_LOW)
        prepare_register();
        `uvm_info("SEQ", "start directed test", UVM_LOW)
        directed_tests();

        `uvm_info("SEQ", "prepare for random test R type", UVM_LOW)
        prepare_register();
        `uvm_info("SEQ", "start random test R type", UVM_LOW)
        random_tests(30000, 0);  // only R type

        `uvm_info("SEQ", "prepare for random test I type", UVM_LOW)
        prepare_register();
        `uvm_info("SEQ", "start random test I type", UVM_LOW)
        random_tests(30000, 1);  // only I type

        `uvm_info("SEQ", "prepare for random test BOTH", UVM_LOW)
        prepare_register();
        `uvm_info("SEQ", "start random test BOTH", UVM_LOW)
        random_tests(30000, 2);  // both

    endtask
endclass

// sequnce item to observe
class cpu_observation extends uvm_sequence_item;
    `uvm_object_utils(cpu_observation)
    logic        rst_n,              rf_we,      dwe;
    logic [ 3:0] alu_control;
    logic [31:0] instr_code,         instr_addr;
    logic [ 4:0] wb_rd;
    logic [31:0] wb_data,            rs1_data,   rs2_data;
    logic [31:0] regs        [0:31];

    function new(string name = "cpu_obs");
        super.new(name);
    endfunction
endclass

// driver
class cpu_driver extends uvm_driver #(cpu_seq_item);
    `uvm_component_utils(cpu_driver)

    virtual cpu_if cpu_if;
    cpu_seq_item   cpu_item;
    int unsigned   issued_cnt;  // driver가 처리한 명령 수

    function new(string name = "cpu_drv", uvm_component c = null);
        super.new(name, c);
    endfunction

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_if)::get(this, "", "cpu_if", cpu_if))
            `uvm_fatal("DRV", "unable to access cpu interface")
    endfunction

    // run phase
    virtual task run_phase(uvm_phase phase);
        // reset
        repeat (3) begin
            @(cpu_if.drv_cb);
            cpu_if.drv_cb.rst_n      <= 1'b0;
            cpu_if.drv_cb.instr_code <= 32'h0000_0013;
            // ADDI x0, x0, 0 = NOP
        end

        forever begin
            seq_item_port.get_next_item(cpu_item);

            @(cpu_if.drv_cb);
            cpu_if.drv_cb.rst_n      <= 1'b1;
            cpu_if.drv_cb.instr_code <= cpu_item.instr_code;

            `uvm_info("DRV", $sformatf(
                      "drive item : %s", cpu_item.convert2string()), UVM_LOW)

            repeat (3) @(posedge cpu_if.clk);
            #1;
            issued_cnt++;
            seq_item_port.item_done();
        end
    endtask
endclass

// monitor
class cpu_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_monitor)

    virtual cpu_if                       cpu_if;
    cpu_seq_item                         cpu_item;
    cpu_observation                      cpu_obs;
    uvm_analysis_port #(cpu_observation) send;

    function new(string name = "cpu_mon", uvm_component c = null);
        super.new(name, c);
    endfunction

    // build phaes
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        send = new("write", this);
        if (!uvm_config_db#(virtual cpu_if)::get(this, "", "cpu_if", cpu_if))
            `uvm_fatal("MON", "unable to access cpu interface")
    endfunction

    // run phase
    virtual task run_phase(uvm_phase phase);
        forever begin
            @(cpu_if.mon_cb);
            cpu_obs             = cpu_observation::type_id::create("cpu_obs");

            cpu_obs.rst_n       = cpu_if.mon_cb.rst_n;
            cpu_obs.instr_code  = cpu_if.mon_cb.instr_code;
            cpu_obs.instr_addr  = cpu_if.mon_cb.instr_addr;
            cpu_obs.rf_we       = cpu_if.mon_cb.rf_we;
            cpu_obs.alu_control = cpu_if.mon_cb.alu_control;
            cpu_obs.wb_rd       = cpu_if.mon_cb.wb_rd;
            cpu_obs.wb_data     = cpu_if.mon_cb.wb_data;
            cpu_obs.rs1_data    = cpu_if.mon_cb.rs1_data;
            cpu_obs.rs2_data    = cpu_if.mon_cb.rs2_data;
            cpu_obs.dwe         = cpu_if.mon_cb.dwe;

            #1;
            foreach (cpu_obs.regs[r]) cpu_obs.regs[r] = cpu_if.regs[r];

            `uvm_info("MON", $sformatf(
                      "PC=%08h instr=%08h rf_we=%0b rd=x%0d data=%08h",
                      cpu_obs.instr_addr,
                      cpu_obs.instr_code,
                      cpu_obs.rf_we,
                      cpu_obs.wb_rd,
                      cpu_obs.wb_data
                      ), UVM_HIGH)

            send.write(cpu_obs);
        end
    endtask
endclass

// agent
class cpu_agent extends uvm_agent;
    `uvm_component_utils(cpu_agent)

    cpu_driver                    drv;
    cpu_monitor                   mon;
    uvm_sequencer #(cpu_seq_item) sqr;

    function new(string name = "cpu_agt", uvm_component c = null);
        super.new(name, c);
    endfunction

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = cpu_driver::type_id::create("drv", this);
        mon = cpu_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(cpu_seq_item)::type_id::create("sqr", this);
    endfunction

    // connect phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// scoreboard
class cpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_scoreboard)

    uvm_analysis_imp #(cpu_observation, cpu_scoreboard) recv;
    uvm_analysis_port #(cpu_seq_item) send; // send to coverage 
    bit [31:0] expected_reg[0:31];
    bit known[0:31]; 
    int unsigned slot, checked_cnt, pass_cnt, fail_cnt;
    bit current_failed;

    function new(string name = "cpu_scb", uvm_component c = null);
        super.new(name, c);
        recv = new("recv", this);
        send = new("send", this);
        known[0] = 1;
    endfunction

    // encode & calculate
    function bit [31:0] calculate(logic [31:0] instr, output cpu_op_e op);
        bit [31:0] a, b;
        bit [4:0] rs1, rs2;
        if ($isunknown(instr)) `uvm_fatal("SCB", "instruction contains X/Z")
        rs1 = instr[19:15];
        rs2 = instr[24:20];
        if (!known[rs1] || ((instr[6:0] == 7'h33) && !known[rs2]))
            `uvm_fatal("SCB", "source register is not initialized")
        a = expected_reg[rs1];
        if (instr[6:0] == 7'h33)
            b = expected_reg[rs2];  // R: 레지스터 데이터
        else
            b = {{20{instr[31]}}, instr[31:20]};  // I: 부호 확장한 즉시값

        // 순서: {opcode, funct7, funct3}
        // 일반 I-type의 ???????는 funct7 자리가 즉시값이므로 무시한다는 뜻
        casez ({instr[6:0], instr[31:25], instr[14:12]})
            {7'h33, 7'h00, 3'h0} : begin
                op = R_ADD;
                return a + b;
            end
            {7'h33, 7'h20, 3'h0} : begin
                op = R_SUB;
                return a - b;
            end
            {7'h33, 7'h00, 3'h1} : begin
                op = R_SLL;
                return a << b[4:0];
            end
            {7'h33, 7'h00, 3'h2} : begin
                op = R_SLT;
                return ($signed(a) < $signed(b));
            end
            {7'h33, 7'h00, 3'h3} : begin
                op = R_SLTU;
                return (a < b);
            end
            {7'h33, 7'h00, 3'h4} : begin
                op = R_XOR;
                return a ^ b;
            end
            {7'h33, 7'h00, 3'h5} : begin
                op = R_SRL;
                return a >> b[4:0];
            end
            {7'h33, 7'h20, 3'h5} : begin
                op = R_SRA;
                return $signed(a) >>> b[4:0];
            end
            {7'h33, 7'h00, 3'h6} : begin
                op = R_OR;
                return a | b;
            end
            {7'h33, 7'h00, 3'h7} : begin
                op = R_AND;
                return a & b;
            end
            {7'h13, 7'b???????, 3'h0} : begin
                op = I_ADDI;
                return a + b;
            end
            {7'h13, 7'b???????, 3'h2} : begin
                op = I_SLTI;
                return ($signed(a) < $signed(b));
            end
            {7'h13, 7'b???????, 3'h3} : begin
                op = I_SLTIU;
                return (a < b);
            end
            {7'h13, 7'b???????, 3'h4} : begin
                op = I_XORI;
                return a ^ b;
            end
            {7'h13, 7'b???????, 3'h6} : begin
                op = I_ORI;
                return a | b;
            end
            {7'h13, 7'b???????, 3'h7} : begin
                op = I_ANDI;
                return a & b;
            end
            {7'h13, 7'h00, 3'h1} : begin
                op = I_SLLI;
                return a << b[4:0];
            end
            {7'h13, 7'h00, 3'h5} : begin
                op = I_SRLI;
                return a >> b[4:0];
            end
            {7'h13, 7'h20, 3'h5} : begin
                op = I_SRAI;
                return $signed(a) >>> b[4:0];
            end
            default: begin
                `uvm_fatal("SCB", $sformatf(
                           "unsupported instruction=%08h", instr))
                return 0;
            end
        endcase
    endfunction

    virtual function void write(cpu_observation cpu_obs);
        cpu_seq_item cpu_item;
        cpu_op_e op;
        bit [4:0] rd;
        bit [31:0] expected;

        if (cpu_obs.rst_n !== 1'b1) begin
            slot = 0;
            current_failed = 0;
            foreach (known[r]) begin
                known[r] = (r == 0);
                expected_reg[r] = 0;
            end
            return;
        end

        if (slot == 0) current_failed = 0;
        // rf_we가 누락돼도 세 번째 클럭의 검사를 건너뛰지 않음
        if (cpu_obs.rf_we !== (slot == 2)) begin
            current_failed = 1;
            `uvm_error("SCB", $sformatf("slot=%0d rf_we=%b expected=%b", slot,
                                        cpu_obs.rf_we, (slot == 2)))
        end
        slot = (slot + 1) % 3;
        if (slot != 0) return;  // FETCH/DECODE에서는 여기서 끝냄

        rd = cpu_obs.instr_code[11:7];
        expected = calculate(cpu_obs.instr_code, op);
        if (cpu_obs.wb_rd !== rd) begin
            current_failed = 1;
            `uvm_error("SCB", $sformatf("write address=x%0d expected=x%0d",
                                        cpu_obs.wb_rd, rd))
        end
        // x0의 내부 셀 대신 x0를 사용하는 read port의 0을 검사
        if (((cpu_obs.instr_code[19:15] == 0) && (cpu_obs.rs1_data !== 32'd0)) ||
            ((op <= R_AND) && (cpu_obs.instr_code[24:20] == 0) &&
             (cpu_obs.rs2_data !== 32'd0))) begin
            current_failed = 1;
            `uvm_error("SCB", "x0 read is not zero")
        end
        if ((rd != 0) && (cpu_obs.regs[rd] !== expected)) begin
            current_failed = 1;
            `uvm_error("SCB", $sformatf("%s x%0d actual=%08h expected=%08h",
                                        op.name(), rd, cpu_obs.regs[rd],
                                        expected))
        end

        // coverage에 완료한 명령과 쓰기 에지 직전 피연산자를 전달 (PASS/FAIL과 별개)
        cpu_item = cpu_seq_item::type_id::create("coverage_item");
        cpu_item.op = op;
        cpu_item.rd = rd;
        cpu_item.rs1 = cpu_obs.instr_code[19:15];
        cpu_item.rs2 = cpu_obs.instr_code[24:20];
        cpu_item.imm = cpu_obs.instr_code[31:20];
        cpu_item.src1_value = cpu_obs.rs1_data;
        cpu_item.src2_value = (op <= R_AND) ? cpu_obs.rs2_data :
            {{20{cpu_obs.instr_code[31]}}, cpu_obs.instr_code[31:20]};
        cpu_item.shamt = (op <= R_AND) ?
            cpu_item.src2_value[4:0] : cpu_obs.instr_code[24:20];
        cpu_item.instr_code = cpu_obs.instr_code;
        send.write(cpu_item);

        // DUT가 틀려도 정답 모델에는 예상값을 저장
        if (rd != 0) begin
            expected_reg[rd] = expected;
            known[rd] = 1;
        end
        checked_cnt++;
        if (current_failed) fail_cnt++;
        else pass_cnt++;
        `uvm_info("SCB", $sformatf(
                  "%s %s rd=x%0d expected=%08h",
                  current_failed ? "FAIL" : "PASS",
                  op.name(),
                  rd,
                  expected
                  ), UVM_LOW)
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (checked_cnt == 0) `uvm_error("SCB", "no instruction checked")
        if (slot != 0) `uvm_error("SCB", "test ended during an instruction")
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(
            "SCB_RESULT", $sformatf(
            "CHECKED=%0d PASS=%0d FAIL=%0d", checked_cnt, pass_cnt, fail_cnt),
            UVM_NONE)
    endfunction
endclass

// coverage
class cpu_coverage extends uvm_component;
    `uvm_component_utils(cpu_coverage)
    uvm_analysis_imp #(cpu_seq_item, cpu_coverage) recv;
    cpu_seq_item cpu_item;
    cpu_value_kind_e src1_kind, src2_kind;
    cpu_relation_e relation;
    bit data_valid;

    covergroup cpu_cg;
        option.per_instance = 1;
        cp_op: coverpoint cpu_item.op {bins operations[] = {[R_ADD : I_SRAI]};}
        cp_rd: coverpoint cpu_item.rd {bins registers[] = {[0 : 31]};}
        cp_rs1: coverpoint cpu_item.rs1 {bins registers[] = {[0 : 31]};}
        cp_rs2: coverpoint cpu_item.rs2 iff (cpu_item.op <= R_AND) {
            bins registers[] = {[0 : 31]};
        }
        cp_shift: coverpoint cpu_item.shamt
            iff (data_valid && cpu_item.op inside {R_SLL, R_SRL, R_SRA, I_SLLI, I_SRLI, I_SRAI}) {
            bins zero = {0};
            bins one = {1};
            bins middle[] = {[2 : 30]};
            bins max_value = {31};
        }
        cp_imm: coverpoint cpu_item.imm iff (cpu_item.op inside {[I_ADDI:I_ANDI]}) {
            bins min_value = {-2048};
            bins negative = {[-2047 : -2]};
            bins minus_one = {-1};
            bins zero = {0};
            bins one = {1};
            bins positive = {[2 : 2046]};
            bins max_value = {2047};
        }

        // cross 재료용 coverpoint는 weight=0: Overall에 중복 반영하지 않음.
        cp_shift_op: coverpoint cpu_item.op {
            option.weight = 0;
            bins ops[] = {R_SLL, R_SRL, R_SRA, I_SLLI, I_SRLI, I_SRAI};
        }
        cx_shift: cross cp_shift_op, cp_shift
            iff (data_valid && cpu_item.op inside {R_SLL, R_SRL, R_SRA, I_SLLI, I_SRLI, I_SRAI});

        cp_compare_op: coverpoint cpu_item.op {
            option.weight = 0;
            bins ops[] = {R_SLT, R_SLTU, I_SLTI, I_SLTIU};
        }
        cp_relation: coverpoint relation {
            option.weight = 0;
            bins relations[] = {REL_LESS, REL_EQUAL, REL_GREATER};
        }
        cx_compare: cross cp_compare_op, cp_relation
            iff (data_valid && cpu_item.op inside {R_SLT, R_SLTU, I_SLTI, I_SLTIU});

        // 첫 번째 피연산자: 모든 연산에서 32비트 데이터 특성 확인.
        cp_src1_kind: coverpoint src1_kind {
            option.weight = 0;
            bins kinds[] = {[VALUE_ZERO:VALUE_NEGATIVE]};
        }
        cx_operand1: cross cp_op, cp_src1_kind iff (data_valid);

        // 두 번째 피연산자: R형 비shift의 32비트 데이터 특성 확인.
        cp_r_alu_op: coverpoint cpu_item.op {
            option.weight = 0;
            bins ops[] = {R_ADD, R_SUB, R_SLT, R_SLTU, R_XOR, R_OR, R_AND};
        }
        cp_src2_kind: coverpoint src2_kind {
            option.weight = 0;
            bins kinds[] = {[VALUE_ZERO:VALUE_NEGATIVE]};
        }
        cx_operand2: cross cp_r_alu_op, cp_src2_kind
            iff (data_valid && cpu_item.op inside {R_ADD, R_SUB, R_SLT, R_SLTU, R_XOR, R_OR, R_AND});

        // I형 비shift는 기존 즉시값 bin(-2048~2047의 7범주)을 재사용.
        cp_i_alu_op: coverpoint cpu_item.op {
            option.weight = 0;
            bins ops[] = {[I_ADDI:I_ANDI]};
        }
        cx_immediate: cross cp_i_alu_op, cp_imm
            iff (data_valid && cpu_item.op inside {[I_ADDI:I_ANDI]});
    endgroup

    function cpu_value_kind_e value_kind(bit [31:0] value);
        case (value)
            32'h0000_0000: return VALUE_ZERO;
            32'h0000_0001: return VALUE_ONE;
            32'hffff_ffff: return VALUE_MINUS_ONE;
            32'h8000_0000: return VALUE_MIN;
            32'h7fff_ffff: return VALUE_MAX;
            default: return value[31] ? VALUE_NEGATIVE : VALUE_POSITIVE;
        endcase
    endfunction

    function new(string name = "cpu_cov", uvm_component c = null);
        super.new(name, c);
        recv   = new("recv", this);
        cpu_cg = new();
    endfunction

    virtual function void write(cpu_seq_item cpu_item);
        this.cpu_item = cpu_item;
        // X/Z를 0으로 바꿔 데이터 coverage를 채우지 않도록 sample 조건에 사용.
        data_valid = !$isunknown({cpu_item.src1_value, cpu_item.src2_value});
        if (data_valid) begin
            src1_kind = value_kind(cpu_item.src1_value);
            src2_kind = value_kind(cpu_item.src2_value);
            if (cpu_item.src1_value == cpu_item.src2_value) relation = REL_EQUAL;
            else if (cpu_item.op inside {R_SLT, I_SLTI})
                relation = ($signed(cpu_item.src1_value) < $signed(cpu_item.src2_value)) ?
                           REL_LESS : REL_GREATER;
            else
                relation = (cpu_item.src1_value < cpu_item.src2_value) ?
                           REL_LESS : REL_GREATER;
        end
        cpu_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf({
                  "\n",
                  "[COV] Overall   = %0.2f%%\n",
                  "[COV] Operation = %0.2f%%\n",
                  "[COV] rd        = %0.2f%%\n",
                  "[COV] rs1       = %0.2f%%\n",
                  "[COV] rs2       = %0.2f%%\n",
                  "[COV] Shift     = %0.2f%%\n",
                  "[COV] Immediate = %0.2f%%\n",
                  "[COV] Shift op x amount    = %0.2f%%\n",
                  "[COV] Compare op x relation = %0.2f%%\n",
                  "[COV] Operation x src1 kind = %0.2f%%\n",
                  "[COV] R-ALU op x src2 kind  = %0.2f%%\n",
                  "[COV] I-ALU op x immediate  = %0.2f%%\n"
                  },
                  cpu_cg.get_inst_coverage(),
                  cpu_cg.cp_op.get_inst_coverage(),
                  cpu_cg.cp_rd.get_inst_coverage(),
                  cpu_cg.cp_rs1.get_inst_coverage(),
                  cpu_cg.cp_rs2.get_inst_coverage(),
                  cpu_cg.cp_shift.get_inst_coverage(),
                  cpu_cg.cp_imm.get_inst_coverage(),
                  cpu_cg.cx_shift.get_inst_coverage(),
                  cpu_cg.cx_compare.get_inst_coverage(),
                  cpu_cg.cx_operand1.get_inst_coverage(),
                  cpu_cg.cx_operand2.get_inst_coverage(),
                  cpu_cg.cx_immediate.get_inst_coverage()
                  ), UVM_NONE)
    endfunction
endclass

// environment 
class cpu_environment extends uvm_env;
    `uvm_component_utils(cpu_environment)

    cpu_agent      agt;
    cpu_scoreboard scb;
    cpu_coverage   cov;

    function new(string name = "cpu_env", uvm_component c = null);
        super.new(name, c);
    endfunction

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = cpu_agent::type_id::create("agt", this);
        scb = cpu_scoreboard::type_id::create("scb", this);
        cov = cpu_coverage::type_id::create("cov", this);
    endfunction

    // connect phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.send.connect(scb.recv);
        scb.send.connect(cov.recv);
    endfunction
endclass

// test
class cpu_test extends uvm_test;
    `uvm_component_utils(cpu_test)
    cpu_sequence seq;
    cpu_environment env;

    function new(string name = "cpu_test", uvm_component c = null);
        super.new(name, c);
    endfunction

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seq = cpu_sequence::type_id::create("seq", this);
        env = cpu_environment::type_id::create("env", this);
    endfunction

    // run phase
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "start CPU R/I test", UVM_LOW)
        seq.start(env.agt.sqr);

        // wait last test 
        @(negedge env.agt.drv.cpu_if.clk);
        if (env.agt.drv.issued_cnt != env.scb.checked_cnt)
            `uvm_error("TEST", $sformatf(
                       "issued=%0d checked=%0d mismatch",
                       env.agt.drv.issued_cnt,
                       env.scb.checked_cnt
                       ))
        `uvm_info("TEST", $sformatf("finished: issued=%0d checked=%0d",
                                    env.agt.drv.issued_cnt,
                                    env.scb.checked_cnt), UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass


// module
module tb_rv32i ();

    logic clk = 0;
    always #5 clk = ~clk;

    cpu_if cpu_if (clk);

    rv32i_cpu dut (
        .clk       (clk),
        .rst_n     (cpu_if.rst_n),
        .instr_code(cpu_if.instr_code),
        .instr_addr(cpu_if.instr_addr),
        .drdata    (cpu_if.drdata),
        .dwe       (cpu_if.dwe),
        .daddr     (cpu_if.daddr),
        .dwdata    (cpu_if.dwdata),
        .itype     (cpu_if.itype)
    );

    assign cpu_if.rf_we = dut.U_DATAPATH.U_REG_FILE.we;
    assign cpu_if.alu_control = dut.alu_control;
    assign cpu_if.wb_rd = dut.U_DATAPATH.U_REG_FILE.wa;
    assign cpu_if.wb_data = dut.U_DATAPATH.U_REG_FILE.wd;
    assign cpu_if.rs1_data = dut.U_DATAPATH.U_REG_FILE.rd1;
    assign cpu_if.rs2_data = dut.U_DATAPATH.U_REG_FILE.rd2;
    for (genvar r = 0; r < 32; r++) begin : g_probe
        assign cpu_if.regs[r] = dut.U_DATAPATH.U_REG_FILE.ram_file[r];
    end

    initial begin
        uvm_config_db#(virtual cpu_if)::set(null, "*", "cpu_if", cpu_if);
        run_test("cpu_test");
    end

    initial begin
        #10ms;
        `uvm_fatal("TIMEOUT", "CPU test did not finish within 10ms")
    end

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_rv32i, "+all");
    end
endmodule
