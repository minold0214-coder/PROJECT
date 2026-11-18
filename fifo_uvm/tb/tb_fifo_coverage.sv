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

// Directed coverage closure, followed by the original random workload.
class fifo_sequence extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_sequence)
    function new(string name = "fifo_seq");
        super.new(name);
    endfunction

    task send_one(bit rst, bit push_req, bit pop_req, bit [7:0] data = 0);
        fifo_seq_item item;
        item = fifo_seq_item::type_id::create("item");
        start_item(item);
        item.rst_n = rst;
        item.push = push_req;
        item.pop = pop_req;
        item.wdata = data;
        finish_item(item);
    endtask

    virtual task body();
        fifo_seq_item item;
        // Establish empty state and hit all four empty-state requests.
        repeat (2) send_one(0, 0, 0);
        send_one(1, 0, 0);
        send_one(1, 0, 1); // blocked pop
        send_one(1, 1, 0, 8'h00);
        send_one(1, 0, 1); // back to empty, read 00
        send_one(1, 1, 1, 8'hff); // empty: push accepted, pop blocked

        // Occupied state: idle, push, pop and simultaneous.
        send_one(1, 0, 0);
        send_one(1, 1, 0, 8'haa);
        send_one(1, 1, 1, 8'h55); // read ff, write 55
        send_one(1, 0, 1);       // read aa
        send_one(1, 0, 1);       // read 55, empty

        // Original 34-push / 34-pop boundary test, with full-state idle/both.
        repeat (34) send_one(1, 1, 0, $urandom_range(0, 255));
        send_one(1, 0, 0);       // full idle
        send_one(1, 1, 1, 8'h42); // full: pop accepted, push blocked
        send_one(1, 1, 0, 8'h42); // restore full
        repeat (34) send_one(1, 0, 1);

        // Reset while occupied, then confirm empty with a blocked read.
        repeat (5) send_one(1, 1, 0, 8'h33);
        repeat (2) send_one(0, 0, 0);
        send_one(1, 0, 0);
        send_one(1, 0, 1);

        // Reset while full. All reset requests keep push/pop inactive.
        repeat (32) send_one(1, 1, 0, 8'hcc);
        repeat (2) send_one(0, 0, 0);
        send_one(1, 0, 0);
        send_one(1, 0, 1);

        // Write/read a complete pointer revolution without reset.
        repeat (32) send_one(1, 1, 0, $urandom_range(0, 255));
        repeat (32) send_one(1, 0, 1);

        repeat (300) begin
            item = fifo_seq_item::type_id::create("random_item");
            start_item(item);
            if (!item.randomize()) `uvm_fatal("SEQ", "randomize failed")
            item.rst_n = 1;
            finish_item(item);
        end
        repeat (35) send_one(1, 0, 1);
        repeat (2) send_one(1, 0, 0);
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

// Functional coverage: fixed 8-bit data, depth 32.
// Monitor samples PRE-edge values (#1step). Sample before model update.
class fifo_coverage extends uvm_component;
    `uvm_component_utils(fifo_coverage)
    uvm_analysis_imp #(fifo_seq_item, fifo_coverage) recv;

    int unsigned count = 0;
    int unsigned wr_index = 0;
    int unsigned rd_index = 0;
    bit initialized = 0;
    bit previous_reset = 0;

    covergroup fifo_cg with function sample(
        int unsigned occupancy, bit [1:0] operation,
        bit write_ok, bit read_ok, logic [7:0] wd, logic [7:0] rd,
        bit write_wrap, bit read_wrap);
        option.per_instance = 1;
        cp_state: coverpoint occupancy {
            bins empty = {0};
            bins middle = {[1:31]};
            bins full = {32};
        }
        cp_operation: coverpoint operation {
            bins idle = {2'b00};
            bins pop_only = {2'b01};
            bins push_only = {2'b10};
            bins simultaneous = {2'b11};
        }
        // 3 states x 4 requests = 12 meaningful scenarios, no impossible bins.
        cx_state_operation: cross cp_state, cp_operation;
        cp_occupancy: coverpoint occupancy {
            bins empty = {0};
            bins one = {1};
            bins middle = {[2:30]};
            bins almost_full = {31};
            bins full = {32};
        }
        // Only count payloads on accepted transfers.
        cp_wdata: coverpoint wd iff (write_ok) {
            bins zero = {8'h00};
            bins ones = {8'hff};
            bins alternating_a = {8'haa};
            bins alternating_5 = {8'h55};
            bins other = {[8'h01:8'h54], [8'h56:8'ha9], [8'hab:8'hfe]};
        }
        cp_rdata: coverpoint rd iff (read_ok) {
            bins zero = {8'h00};
            bins ones = {8'hff};
            bins alternating_a = {8'haa};
            bins alternating_5 = {8'h55};
            bins other = {[8'h01:8'h54], [8'h56:8'ha9], [8'hab:8'hfe]};
        }
        // Hit only when an accepted transfer wraps the reference pointer.
        cp_write_wrap: coverpoint write_wrap { bins hit = {1}; }
        cp_read_wrap: coverpoint read_wrap { bins hit = {1}; }
    endgroup

    // Separate group so reset cycles cannot inflate normal-operation coverage.
    covergroup reset_cg with function sample(int unsigned occupancy);
        option.per_instance = 1;
        cp_reset_state: coverpoint occupancy {
            bins empty = {0};
            bins occupied = {[1:31]};
            bins full = {32};
        }
    endgroup

    function new(string name = "fifo_cov", uvm_component c = null);
        super.new(name, c);
        recv = new("recv", this);
        fifo_cg = new();
        reset_cg = new();
    endfunction

    virtual function void write(fifo_seq_item item);
        bit write_ok, read_ok;
        if (!item.rst_n) begin
            // First reset establishes empty state; later resets use model state.
            if (!previous_reset)
                reset_cg.sample(initialized ? count : 0);
            count = 0;
            wr_index = 0;
            rd_index = 0;
            initialized = 1;
            previous_reset = 1;
            return;
        end
        previous_reset = 0;
        if (!initialized) return;

        // Expected acceptance is derived from the model, not DUT flags.
        // Full + both: pop only. Empty + both: push only.
        write_ok = item.push && (count < 32);
        read_ok  = item.pop  && (count > 0);
        fifo_cg.sample(count, {item.push, item.pop},
                       write_ok, read_ok, item.wdata, item.rdata,
                       write_ok && (wr_index == 31),
                       read_ok  && (rd_index == 31));
        if (write_ok) wr_index = (wr_index + 1) % 32;
        if (read_ok)  rd_index = (rd_index + 1) % 32;
        case ({write_ok, read_ok})
            2'b10: count++;
            2'b01: count--;
            default: ;
        endcase
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Functional coverage = %0.2f%%", fifo_cg.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("State x operation   = %0.2f%% (12 bins)", fifo_cg.cx_state_operation.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("Occupancy           = %0.2f%%", fifo_cg.cp_occupancy.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("Accepted write data = %0.2f%%", fifo_cg.cp_wdata.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("Accepted read data  = %0.2f%%", fifo_cg.cp_rdata.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("Write / read wrap   = %0.2f%% / %0.2f%%", fifo_cg.cp_write_wrap.get_inst_coverage(), fifo_cg.cp_read_wrap.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("Reset state         = %0.2f%% (3 bins)", reset_cg.get_inst_coverage()), UVM_NONE)
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
