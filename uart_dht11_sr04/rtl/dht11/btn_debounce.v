`timescale 1ns / 1ps

module btn_debounce(
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    reg [7:0] q_reg; //8bit shift register SIPO
    // 직렬 input 병렬 output
    wire      debounce;   // output of 8 input AND gate
    reg       edge_reg;   

    reg [$clog2(50)-1 : 0] counter_reg;
    reg                    o_1MHz;
    // clock div : 100MHz > 1MHz
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_1MHz      <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == 50-1) begin
                counter_reg <= 0;
                o_1MHz <= ~o_1MHz;
            end
        end
    end

    // shift register 
    //최상위에 넣고 오른쪽 밀던가 / 최하위에 넣고 왼쪽으로 밀던가
    always @(posedge o_1MHz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            // q_reg <= {q_reg[6:0], i_btn};
            q_reg <= {i_btn, q_reg[7:1]};
        end
    end

    // + AND로 묶기
    assign debounce = &q_reg;

    // 1clock delay edge detector
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
        
    end

    assign o_btn = debounce & (~edge_reg);

endmodule