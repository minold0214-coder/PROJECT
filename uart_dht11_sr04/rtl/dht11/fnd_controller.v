`timescale 1ns / 1ps

module fnd_controller (
    input        clk,
    input        reset,
    input  [7:0] fnd_in,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    // 아래는 일의 자리만 킬 거기 때문에
    // assign fnd_com = 4'b1110; 주석처리해야 충돌 안난다
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire [3:0] bcd;
    wire [1:0] w_digit_sel;
    wire       w_1kHz;

    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1kHz(w_1kHz)
    );

    // reset은 공통적으로 같은 reset을 사용
    counter_4 U_COUNTER_4 (
        .clk      (w_1kHz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );


    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_com  (fnd_com)
    );

    digit_spliter U_DS (
        .seg_data  (fnd_in),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_4x1 U_MUX (
        .sel       (w_digit_sel),   // mux selection
        .digit_1   (w_digit_1),     // sel 2'b00
        .digit_10  (w_digit_10),    // sel 2'b01
        .digit_100 (w_digit_100),   // sel 2'b10
        .digit_1000(w_digit_1000),  // sel 2'b11
        .mux_out   (bcd)
    );

    bcd U_BCD (
        .bcd_in (bcd),
        .bcd_out(fnd_data)
    );

endmodule

module clk_div (
    input  clk,
    input  reset,
    output o_1kHz
);

    reg [15:0] counter_reg;
    reg        clk_reg;

    assign o_1kHz = clk_reg;

    // sequencing logic
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_reg     <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == 50000 - 1) begin
                counter_reg <= 0;
                clk_reg     <= ~clk_reg;
            end
        end
    end

endmodule

module counter_4 (
    input        clk,
    input        reset,
    output [1:0] digit_sel
);

    reg [1:0] counter_reg;

    assign digit_sel = counter_reg;
    // 변수 이름이 달아서 assign으로 연결(wire) 그럼 wire가 늘어났나? X
    // wire -> 선은 있는데 길이는 0 : 합성기가 알아서 지워줄 거임
    // 조합논리는 blocking 순차논리는 nonblocking

    // sequential logic : SL : 시간에 따라서 - clk의 변화
    // 상승 엣지가 올 때마다 아래 실행 : counting 
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
        end else begin
            // operation
            counter_reg <= counter_reg + 1;
        end
    end

endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_com
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00:   fnd_com = 4'b1110;  // digit 1
            2'b01:   fnd_com = 4'b1101;  // digit 10
            2'b10:   fnd_com = 4'b1011;  // digit 100
            2'b11:   fnd_com = 4'b0111;  // digit 1000
            default: fnd_com = 4'b1110;  // default value - for full case
        endcase
    end
endmodule


module digit_spliter (
    input  [7:0] seg_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1 = seg_data % 10;
    assign digit_10 = (seg_data / 10) % 10;
    assign digit_100 = (seg_data / 100) % 10;
    assign digit_1000 = (seg_data / 1000) % 10;

endmodule

module mux_4x1 (
    input  [1:0] sel,         // mux selection
    input  [3:0] digit_1,     // sel 2'b00
    input  [3:0] digit_10,    // sel 2'b01
    input  [3:0] digit_100,   // sel 2'b10
    input  [3:0] digit_1000,  // sel 2'b11
    output [3:0] mux_out
);

    // assign 
    assign mux_out = (sel == 2'b00) ? digit_1 :  // true
        (sel == 2'b01) ? digit_10 :
                     (sel == 2'b10) ? digit_100 :
                     (sel == 2'b11) ? digit_1000 : 4'b1111;

endmodule

module bcd (
    input      [3:0] bcd_in,
    output reg [7:0] bcd_out
    // output 하고 기본 설정은 wire기 때문에 reg로 지정해야됨
);

    // always 문에서 출력은 항상 reg여야 함
    always @(bcd_in) begin

        // case 처리는 항상 full case 처리하여라
        // full case가 아닌 경우 동작을 안함 - always이면 항상 latch 확인해야됨
        case (bcd_in)
            4'b0000: bcd_out = 8'hc0;  // 0
            4'b0001: bcd_out = 8'hf9;
            4'b0010: bcd_out = 8'ha4;
            4'b0011: bcd_out = 8'hb0;
            4'b0100: bcd_out = 8'h99;
            4'b0101: bcd_out = 8'h92;
            4'b0110: bcd_out = 8'h82;
            4'b0111: bcd_out = 8'hf8;
            4'b1000: bcd_out = 8'h80;
            4'b1001: bcd_out = 8'h90;
            4'b1010: bcd_out = 8'h88;  // a  
            4'b1011: bcd_out = 8'h83;  // b
            4'b1100: bcd_out = 8'hc6;  // c
            4'b1101: bcd_out = 8'ha1;  // d
            4'b1110: bcd_out = 8'h86;  // e 
            4'b1111: bcd_out = 8'h8e;  // f
        endcase
    end

endmodule
