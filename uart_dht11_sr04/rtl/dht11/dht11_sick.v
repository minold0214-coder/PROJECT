`timescale 1ns / 1ps

module dht11_controller (
    input clk,
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output done,
    output valid,
    inout dht11_io

);

    localparam [2:0] IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4, DATA_L = 5, DATA_H = 6,STOP = 7;
    reg [2:0] c_state, n_state;
    reg [$clog2(19000)-1:0] tick_count_reg, tick_count_next;
    reg [39:0] data_reg, data_next;
    reg [5:0] data_count_reg, data_count_next;
    reg run_stop, clear;
    reg done_next, done_reg;
    reg io_control;
    reg dht11_io_reg, dht11_io_nxet;

    
    reg dht11_sync_1;
    reg dht11_sync_2;

    wire [7:0] sum;
    wire w_tick_us;

    tick_us u_TICK_US (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick_us(w_tick_us)
    );



    assign done = done_reg;
    assign dht11_io = (io_control) ? (dht11_io_reg) : 1'bz;
    assign humidity = data_reg[39:24];
    assign temperature = data_reg[23:8];
    assign sum = data_reg[39:32] + data_reg[31:24] + data_reg[23:16] + data_reg[15:8];
    assign valid = (c_state == STOP) && (data_reg[7:0] == sum);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            dht11_io_reg <= 0;
            data_reg <= 0;
            data_count_reg <= 0;
            tick_count_reg <= 0;
            done_reg <= 0;
            dht11_sync_1 <= 1;
            dht11_sync_2 <= 1;
        end else begin
            c_state <= n_state;
            dht11_io_reg <= dht11_io_nxet;
            data_reg <= data_next;
            data_count_reg <= data_count_next;
            tick_count_reg <= tick_count_next;
            done_reg <= done_next;
            dht11_sync_1 <= dht11_io;
            dht11_sync_2 <= dht11_sync_1;
        end
    end


    always @(*) begin
        n_state = c_state;
        dht11_io_nxet = dht11_io_reg;
        data_next = data_reg;
        data_count_next = data_count_reg;
        tick_count_next = tick_count_reg;
        done_next = done_reg;
        io_control = 1;
        run_stop = 0;
        clear = 0;
        case (c_state)
            IDLE: begin
                clear = 0;
                io_control = 1;
                dht11_io_nxet = 1;
                tick_count_next = 0;
                done_next = 0;
                if (start) n_state = START;
            end
            START: begin
                run_stop = 1;
                dht11_io_nxet = 0;
                data_next = 0;
                if (w_tick_us) begin
                    //delay 19msec low 추가
                    if (tick_count_reg == 19_000) begin
                        n_state = WAIT;
                        tick_count_next = 0;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
            WAIT: begin
                dht11_io_nxet = 1; // 있어야하지 않나 ?
                if(tick_count_reg >= 20) begin
                    io_control = 0;
                    dht11_io_nxet = 0;
                end
                run_stop  = 1;
                if (w_tick_us) begin
                    if (tick_count_reg >= 30 & !dht11_sync_2) begin
                        n_state = SYNC_L;
                        tick_count_next = 0;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
            SYNC_L: begin
                run_stop   = 1;
                io_control = 0;
                //dht11_io_nxet = 0;
                if (w_tick_us) begin
                    if (tick_count_reg >= 80 & dht11_sync_2) begin
                        n_state = SYNC_H;
                        tick_count_next = 0;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
            SYNC_H: begin
                run_stop   = 1;
                io_control = 0;
                if (w_tick_us) begin
                    if (tick_count_reg >= 80 & !dht11_sync_2) begin
                        n_state = DATA_L;
                        tick_count_next = 0;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
            DATA_L: begin
                run_stop   = 1;
                io_control = 0;
                if(data_count_reg == 40) n_state = STOP;
                if (w_tick_us) begin
                    if (tick_count_reg >= 50 & dht11_sync_2) begin
                        n_state = DATA_H;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end

            end
            DATA_H: begin
                run_stop   = 1;
                io_control = 0;
                if (w_tick_us) begin
                    if (tick_count_reg <= 50 & !dht11_sync_2) begin
                        data_next[39-(data_count_reg)] = 0;
                        data_count_next = data_count_reg + 1;
                        tick_count_next = 0;
                        n_state = DATA_L;
                    end else if (tick_count_reg >= 50 & !dht11_sync_2) begin
                        data_next[39-(data_count_reg)] = 1;
                        data_count_next = data_count_reg + 1;
                        tick_count_next = 0;
                        n_state = DATA_L;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
                //if (data_count_reg == 39) begin
                //    n_state = STOP;
                //    tick_count_next = 0;
                //end
            end
            STOP: begin
                run_stop = 1;
                io_control = 0;
                data_count_next = 0;
                if (w_tick_us) begin
                    if (tick_count_reg == 50) begin
                        done_next = 0;
                        n_state = IDLE;
                    end
                    else tick_count_next = tick_count_reg + 1;
                end
            end
        endcase
    end

endmodule


module tick_us (
    input      clk,
    input      reset,
    input      run_stop,
    input      clear,
    output reg o_tick_us

);
    parameter F_COUNT = 100_000_000 / 1_000_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin

        if (reset | clear) begin
            counter_reg <= 0;
            o_tick_us   <= 0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick_us   <= 1;
                end else o_tick_us <= 0;
            end else begin
                o_tick_us   <= 0;
                counter_reg <= 0;
            end
        end
    end
endmodule
