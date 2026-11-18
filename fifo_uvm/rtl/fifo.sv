module fifo#(
	parameter WIDTH = 5
)(
	input  logic		clk,
	input  logic		rst_n,
	input  logic		push,
	input  logic		pop,
	input  logic [7:0]	wdata,
	output logic [7:0]	rdata,
	output logic		full,
	output logic		empty
);

	logic [WIDTH-1:0] w_wptr, w_rptr;
	
	control_unit #(
		.WIDTH(5)
	) U_CONTROL_UNIT (
		.clk	(clk),
		.rst_n	(rst_n),
		.push	(push),
		.pop	(pop),
		.wptr	(w_wptr),
		.rptr	(w_rptr),
		.full	(full),
		.empty	(empty)
		);
	
	register_file #(
		.WIDTH(5)
	) U_REGISTER_FILE(
		.clk	(clk),
		.we		(push&!full),
		.waddr	(w_wptr),
		.raddr	(w_rptr),
		.wdata	(wdata),
		.rdata	(rdata)
		);
	
endmodule


module register_file #(
	parameter WIDTH = 5 
)(
	input  logic				clk,
	input  logic				we,
	input  logic [WIDTH-1:0]	waddr,
	input  logic [WIDTH-1:0]	raddr,
	input  logic [		7:0]	wdata,
	output logic [		7:0]	rdata
	);

	parameter DEPTH = 2 ** WIDTH;

	reg [7:0] register[0:DEPTH-1];

	always_ff @(posedge clk) begin
		if (we) begin
			register[waddr] <= wdata;
		end
	end 

	assign rdata = register[raddr];
endmodule


module control_unit #(
	parameter WIDTH = 5
)(
	input  logic				clk,
	input  logic				rst_n,
	input  logic				push,
	input  logic				pop,
	output logic [WIDTH-1:0]	wptr,
	output logic [WIDTH-1:0]	rptr,
	output logic				full,
	output logic				empty
	);

	reg [WIDTH-1:0] wptr_reg , wptr_next;
	reg [WIDTH-1:0] rptr_reg , rptr_next;
	reg				full_reg , full_next;
	reg				empty_reg , empty_next;
	
	assign wptr  = wptr_reg;
	assign rptr  = rptr_reg;
	assign full  = full_reg;
	assign empty = empty_reg;

	always_ff @(posedge clk) begin
		if (!rst_n) begin
			wptr_reg  <= 0;
			rptr_reg  <= 0;
			full_reg  <= 0;
			empty_reg <= 1;
		end else begin
			wptr_reg  <= wptr_next;
			rptr_reg  <= rptr_next;
			full_reg  <= full_next;
			empty_reg <= empty_next;;
		end
	end

	always_comb begin
		wptr_next  = wptr_reg;
		rptr_next  = rptr_reg;
		full_next  = full_reg;
		empty_next = empty_reg;
		case({push, pop})
			2'b00 : begin
			end
			2'b01 : begin
				if (!empty_reg) begin
					rptr_next = rptr_reg + 1;
					full_next = 1'b0;
					if (wptr_reg == rptr_next) empty_next = 1'b1;
				end
			end
			2'b10 : begin
				if (!full_reg) begin
					wptr_next = wptr_reg + 1;
					empty_next = 1'b0;
					if (rptr_reg == wptr_next) full_next = 1'b1;
				end 
			end
			2'b11 : begin
				if (full_reg) begin
					rptr_next = rptr_reg + 1;
					full_next = 1'b0;
				end else if (empty_reg) begin
					wptr_next = wptr_reg + 1;
					empty_next = 1'b0;
				end else begin
					rptr_next = rptr_reg + 1;
					wptr_next = wptr_reg + 1;
				end 
			end
		endcase
	end
endmodule

