`timescale 1ns / 1ps


// testbench of stopwatch control unit
module tb_stopwatch_control_unit ();
    reg  clk;
    reg  reset;
    reg  i_run_stop;
    reg  i_clear;
    reg  i_mode;
    reg  i_record;
    wire o_run_stop;
    wire o_clear;
    wire o_mode;
    wire o_record;


    stopwatch_control_unit dut (
        .clk       (clk),
        .reset     (reset),
        .i_run_stop(i_run_stop),
        .i_clear   (i_clear),
        .i_mode    (i_mode),
        .i_record  (i_record),
        .o_run_stop(o_run_stop),
        .o_clear   (o_clear),
        .o_mode    (o_mode),
        .o_record  (o_record)
    );

    always #5 clk = ~clk;

    initial begin
        clk        = 0;
        reset      = 0;
        i_run_stop = 0;
        i_clear    = 0;
        i_mode     = 0;
        i_record   = 0;
    #10;
    
    end


endmodule


/*
// testbench of watch control unit
module tb_watch_control_unit ();
    reg  clk;
    reg  reset;
    reg  i_h_up;
    reg  i_m_up;
    reg  i_s_up;
    reg  opt;
    wire o_run_enable;
    wire o_h_up;
    wire o_m_up;
    wire o_s_up;

    watch_control_unit dut (
        .clk         (clk),
        .reset       (reset),
        .i_h_up      (i_h_up),
        .i_m_up      (i_m_up),
        .i_s_up      (i_s_up),
        .opt         (opt),
        .o_run_enable(o_run_enable),
        .o_h_up      (o_h_up),
        .o_m_up      (o_m_up),
        .o_s_up      (o_s_up)
    );


endmodule
*/
