`timescale 1ns / 1ps

module tb_top_dht11 ();

    reg clk, reset, btn_R;
    reg  [1:0] sw;
    wire [15:0] led;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire dht11_io;

    reg dht11_sensor_io, dht11_sensor_io_control;
    assign dht11_io = (dht11_sensor_io_control) ? dht11_sensor_io : 1'bz;

    reg [39:0] sensor_data;

    TOP_DHT11 dut (
        .clk     (clk),
        .reset   (reset),
        .btn_R   (btn_R),
        .sw      (sw),         //0
        .led     (led),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data),
        .dht11_io(dht11_io)
    );

    integer i = 0;

    always #5 clk = ~clk;
    
    initial begin
        clk                     = 0;
        reset                   = 1;
        btn_R                   = 0;
        sw[0]                   = 0;
        sw[1]                   = 0;
        dht11_sensor_io         = 1;
        dht11_sensor_io_control = 0;
        #10;
        reset = 0;

        btn_R = 1;
        #(10_000);
        btn_R = 0;
        #(19_000_000);  // 19ms delay for wait to sync

        #(30_000);  // 30usec
        dht11_sensor_io = 1'b0;
        dht11_sensor_io_control = 1;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);
        // data
         sensor_data = 40'h33_67_26_50_10; // yes valid
        // sensor_data = 40'h33_67_26_50_32; // not valid

        for (i = 0; i < 40; i = i + 1) begin
            // 50usec low
            dht11_sensor_io = 1'b0;
            #(50_000);
            dht11_sensor_io = 1'b1;
            if (sensor_data[39-i]) begin
                #(70_000);
            end else begin
                #(27_000);
            end 
        end
        #(50_000);
        dht11_sensor_io_control = 1'b0;
        #(1_000_000 * 5);
                
        sw[1] = 1;
        #(1_000_000 * 5);


        sw[1] = 0;
        sw[0] = 1;
        #(1_000_000 * 5);
        
        sw[1] = 1;
        #(1_000_000 * 5);

        $finish;
    end
endmodule
