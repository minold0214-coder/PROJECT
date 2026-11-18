`include "uvm_macros.svh"
import uvm_pkg::*;

// interface
interface fifo_if(input clk);
	logic		rst_n;
	logic		push;
	logic		pop;
	logic [7:0] wdata;
	logic [7:0] rdata;
	logic		full;
	logic		empty;

	clocking drv_cb @(negedge clk);
        default output #1;
        output rst_n, push, pop, wdata;
    endclocking
    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, push, pop, wdata, rdata, full, empty;
    endclocking
endinterface

// sequence item
class fifo_seq_item extends uvm_sequence_item;
		 bit			rst_n;
	rand bit			push;
	rand bit			pop;
	rand bit   [7:0]	wdata;
		 logic [7:0]	rdata;
		 logic			full;
		 logic			empty;

	function new(string name = "fifo_seq_item");
		super.new(name);
	endfunction

	`uvm_object_utils_begin(fifo_seq_item)
		`uvm_field_int(rst_n , UVM_DEFAULT)
		`uvm_field_int(push  , UVM_DEFAULT)
		`uvm_field_int(pop   , UVM_DEFAULT)
		`uvm_field_int(wdata , UVM_DEFAULT)
		`uvm_field_int(rdata , UVM_DEFAULT)
		`uvm_field_int(full  , UVM_DEFAULT)
		`uvm_field_int(empty , UVM_DEFAULT)
	`uvm_object_utils_end

	virtual function string convert2string();
		return $sformatf("rst_n=%d, push=%d, pop=%d, wdata=%d, rdata=%d, full=%d,empty=%d",
						rst_n, push, pop, wdata, rdata, full, empty);
	endfunction
endclass

// sequence
class fifo_sequence extends uvm_sequence #(fifo_seq_item);
	`uvm_object_utils(fifo_sequence)

	function new(string name = "fifo_seq");
		super.new(name);
	endfunction

	virtual task body();
	fifo_seq_item fifo_item;

	 repeat (2) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            fifo_item.rst_n = 0;
            fifo_item.push  = 0;
            fifo_item.pop   = 0;
            fifo_item.wdata = 0;
            finish_item(fifo_item);
        end

        fifo_item = fifo_seq_item::type_id::create("fifo_item");
        start_item(fifo_item);
        fifo_item.rst_n = 1;
        fifo_item.push  = 0;
        fifo_item.pop   = 0;
        fifo_item.wdata = 0;
        finish_item(fifo_item);

        repeat (34) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            fifo_item.rst_n = 1;
            fifo_item.push  = 1;
            fifo_item.pop   = 0;
            fifo_item.wdata = $urandom_range(0, 255);
            finish_item(fifo_item);
        end

        repeat (34) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            fifo_item.rst_n = 1;
            fifo_item.push  = 0;
            fifo_item.pop   = 1;
            fifo_item.wdata = 0;
            finish_item(fifo_item);
        end

        repeat (300) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            if (!fifo_item.randomize()) `uvm_fatal("SEQ", "randomize failed")
            fifo_item.rst_n = 1;
            finish_item(fifo_item);
        end

        repeat (35) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            fifo_item.rst_n = 1;
            fifo_item.push  = 0;
            fifo_item.pop   = 1;
            fifo_item.wdata = 0;
            finish_item(fifo_item);
        end

        repeat (2) begin
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            start_item(fifo_item);
            fifo_item.rst_n = 1;
            fifo_item.push  = 0;
            fifo_item.pop   = 0;
            fifo_item.wdata = 0;
            finish_item(fifo_item);
        end
	endtask 
endclass

// dirver
class fifo_driver extends uvm_driver #(fifo_seq_item);
	`uvm_component_utils(fifo_driver)

	virtual fifo_if	f_if;
	fifo_seq_item fifo_item;

	function new(string name = "fifo_drv", uvm_component c=null);
		super.new(name, c);
	endfunction

	// build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual fifo_if)::get(this, "", "fifo_if", f_if))
			`uvm_fatal("DRV", "unable to access fifo interface")
	endfunction

	// run phase
	virtual task run_phase(uvm_phase phase);
		forever begin
			seq_item_port.get_next_item(fifo_item);
			@(f_if.drv_cb);
			f_if.drv_cb.rst_n <= fifo_item.rst_n;
            f_if.drv_cb.push  <= fifo_item.push;
            f_if.drv_cb.pop   <= fifo_item.pop;
            f_if.drv_cb.wdata <= fifo_item.wdata;
            @(posedge f_if.clk);
            #1;
            seq_item_port.item_done();
		end
	endtask
endclass

// monitor
class fifo_monitor extends uvm_monitor;
	`uvm_component_utils(fifo_monitor)
	virtual fifo_if f_if;
	fifo_seq_item fifo_item;
	uvm_analysis_port #(fifo_seq_item) send;

	function new(string name = "fifo_mon", uvm_component c=null);
		super.new(name , c);
	endfunction

	// build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db #(virtual fifo_if)::get(this, "", "fifo_if", f_if)) 
			`uvm_fatal("MON" , "unable to access fifo interface")
		send = new("write" ,this);
	endfunction

	// run phase
	virtual task run_phase(uvm_phase phase);
		forever begin
 			@(f_if.mon_cb);
            fifo_item = fifo_seq_item::type_id::create("fifo_item");
            fifo_item.rst_n = f_if.mon_cb.rst_n;
            fifo_item.push  = f_if.mon_cb.push;
            fifo_item.pop   = f_if.mon_cb.pop;
            fifo_item.wdata = f_if.mon_cb.wdata;
            fifo_item.rdata = f_if.mon_cb.rdata;
            fifo_item.full  = f_if.mon_cb.full;
            fifo_item.empty = f_if.mon_cb.empty;
            send.write(fifo_item);
		end
	endtask
endclass

// agent
class fifo_agent extends uvm_agent;
	`uvm_component_utils(fifo_agent)
	fifo_driver  					drv;
	fifo_monitor 					mon;
	uvm_sequencer#(fifo_seq_item)	sqr;

	function new(string name = "fifo_agt", uvm_component c=null);
		super.new(name, c);
	endfunction

	// build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		drv = fifo_driver::type_id::create("drv", this);
		mon = fifo_monitor::type_id::create("mon", this);
		sqr = uvm_sequencer#(fifo_seq_item)::type_id::create("sqr", this);
	endfunction

	// connect phase
	virtual function void connect_phase(uvm_phase phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass

// scoreboard
class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp #(fifo_seq_item, fifo_scoreboard) recv;

    bit [7:0] expected_fifo [0:31];
    bit [4:0] expected_wptr;
    bit [4:0] expected_rptr;

    int expected_cnt = 0;
    int pass_cnt     = 0;
    int fail_cnt     = 0;
    int push_cnt     = 0;
    int pop_cnt      = 0;
    int skip_cnt     = 0;

    function new(
        string name = "fifo_scb",
        uvm_component c = null
    );
        super.new(name, c);
        recv = new("recv", this);
    endfunction

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(fifo_seq_item fifo_item);
        // reset
        if (!fifo_item.rst_n) begin
            expected_wptr = 0;
            expected_rptr = 0;
            expected_cnt  = 0;
        end

        else begin

            // full 확인
            if (expected_cnt == 32) begin
                if (!fifo_item.full) begin
                    `uvm_error("SCB", "full signal fail")
                    fail_cnt++;
                end
            end else begin
                if (fifo_item.full) begin
                    `uvm_error("SCB", "full signal fail")
                    fail_cnt++;
                end
            end

            // empty 확인
            if (expected_cnt == 0) begin
                if (!fifo_item.empty) begin
                    `uvm_error("SCB", "empty signal fail")
                    fail_cnt++;
                end
            end else begin
                if (fifo_item.empty) begin
                    `uvm_error("SCB", "empty signal fail")
                    fail_cnt++;
                end
            end

            // pop
            if (fifo_item.pop && !fifo_item.empty) begin
                if (fifo_item.rdata == expected_fifo[expected_rptr]) begin
                    `uvm_info("SCB", $sformatf("POP PASS expected=%h, rdata=%h",
                            expected_fifo[expected_rptr], fifo_item.rdata), UVM_HIGH)
                    pass_cnt++;
                end else begin
                    `uvm_error("SCB", $sformatf("POP FAIL expected=%h, rdata=%h",
                            expected_fifo[expected_rptr], fifo_item.rdata))
                    fail_cnt++;
                end
                expected_rptr++;
                pop_cnt++;
            end else if (fifo_item.pop && fifo_item.empty) begin
                `uvm_info("SCB", "POP SKIP : FIFO EMPTY", UVM_HIGH)
                skip_cnt++;
            end

            // push
            if (fifo_item.push && !fifo_item.full) begin
                expected_fifo[expected_wptr] = fifo_item.wdata;
                expected_wptr++;
                push_cnt++;
            end else if (fifo_item.push && fifo_item.full) begin
                `uvm_info("SCB", "PUSH SKIP : FIFO FULL", UVM_HIGH)
                skip_cnt++;
            end

            // data count
            if ((fifo_item.push && !fifo_item.full) && !(fifo_item.pop && !fifo_item.empty))
                expected_cnt++;
            else if ((fifo_item.pop && !fifo_item.empty) && !(fifo_item.push && !fifo_item.full))
				expected_cnt--;
			else expected_cnt = expected_cnt;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SCB", $sformatf("PASS=%0d FAIL=%0d PUSH=%0d POP=%0d SKIP=%0d",
                pass_cnt, fail_cnt, push_cnt, pop_cnt, skip_cnt), UVM_NONE)
    endfunction
endclass

// coverage
class fifo_coverage extends uvm_component;
    `uvm_component_utils(fifo_coverage)

    uvm_analysis_imp #(fifo_seq_item, fifo_coverage) recv;
    fifo_seq_item fifo_item;

    covergroup fifo_cg;
        cp_full : coverpoint fifo_item.full iff (fifo_item.rst_n) {
            bins not_full = {0};
            bins full = {1};
        }
        cp_empty : coverpoint fifo_item.empty iff (fifo_item.rst_n) {
            bins not_empty = {0};
            bins empty = {1};
        }
        cp_push : coverpoint fifo_item.push iff (fifo_item.rst_n) {
            bins no_push = {0};
            bins push = {1};
        }
        cp_pop : coverpoint fifo_item.pop iff (fifo_item.rst_n) {
            bins no_pop = {0};
            bins pop = {1};
        }
        cx_full_push : cross cp_full, cp_push;
        cx_empty_pop : cross cp_empty, cp_pop;
        cx_push_pop : cross cp_push, cp_pop;
    endgroup

    function new(string name = "fifo_cov", uvm_component c = null);
        super.new(name, c);
        recv = new("recv", this);
        fifo_cg = new();
    endfunction

    virtual function void write(fifo_seq_item fifo_item);
        this.fifo_item = fifo_item;
        fifo_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Overall coverage   = %0.2f%%", fifo_cg.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("full coverage      = %0.2f%%", fifo_cg.cp_full.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("empty coverage     = %0.2f%%", fifo_cg.cp_empty.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("push coverage      = %0.2f%%", fifo_cg.cp_push.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("pop coverage       = %0.2f%%", fifo_cg.cp_pop.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("full/push cross    = %0.2f%%", fifo_cg.cx_full_push.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("empty/pop cross    = %0.2f%%", fifo_cg.cx_empty_pop.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("push/pop cross     = %0.2f%%", fifo_cg.cx_push_pop.get_inst_coverage()), UVM_NONE)
    endfunction
endclass

// environment
class fifo_environment extends uvm_env;
	`uvm_component_utils(fifo_environment)
	fifo_agent agt;
	fifo_scoreboard scb;
	fifo_coverage cov;

	function new(string name = "fifo_env", uvm_component c=null);
		super.new(name, c);
	endfunction

	// build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agt = fifo_agent::type_id::create("agt", this);
		scb = fifo_scoreboard::type_id::create("scb", this);
		cov = fifo_coverage::type_id::create("cov", this);
	endfunction

	// connect phase
	virtual function void connect_phase(uvm_phase phase);
		agt.mon.send.connect(scb.recv);
		agt.mon.send.connect(cov.recv);
	endfunction	
endclass

// test
class fifo_test extends uvm_test;
	`uvm_component_utils(fifo_test)
	fifo_sequence seq;
	fifo_environment env;
	
	function new(string name = "fifo_test", uvm_component c=null);
		super.new(name, c);
	endfunction
	
	// build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		seq = fifo_sequence::type_id::create("seq", this);
		env = fifo_environment::type_id::create("env", this);
	endfunction
		
	// run phase
	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		seq.start(env.agt.sqr);
		@(negedge env.agt.drv.f_if.clk);
		phase.drop_objection(this);
	endtask
endclass

// module
module tb_fifo();

    logic clk = 0;
    always #5 clk = ~clk;

    fifo_if fifo_if(clk);

    fifo dut (
        .clk   (clk),
        .rst_n (fifo_if.rst_n),
        .push  (fifo_if.push),
        .pop   (fifo_if.pop),
        .wdata (fifo_if.wdata),
        .rdata (fifo_if.rdata),
        .full  (fifo_if.full),
        .empty (fifo_if.empty)
    );

    initial begin
        $fsdbDumpfile("./build/wave.fsdb");
        $fsdbDumpvars(0);
    end

    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "fifo_if", fifo_if);
        run_test("fifo_test");
    end

endmodule
