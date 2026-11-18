`timescale 1ns / 1ps

module tb_top_module_sw_w ();

    reg         clk;
    reg         reset;
    reg         btn_L;
    reg         btn_U;
    reg         btn_R;
    reg         btn_D;
    reg  [ 2:0] sw;
    wire [ 3:0] fnd_com;
    wire [ 7:0] fnd_data;
    wire [15:0] led;

    top_module_sw_w dut (
        .clk     (clk),
        .reset   (reset),
        .btn_L   (btn_L),
        .btn_U   (btn_U),
        .btn_R   (btn_R),
        .btn_D   (btn_D),
        .sw      (sw),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data),
        .led     (led)
    );

    parameter TICK_DELAY = 1_000_000 * 50;

    always #5 clk = ~clk;

    initial begin
        // 초기값
        clk = 0;
        reset = 1;
        btn_L = 0;
        btn_U = 0;
        btn_R = 0;
        btn_D = 0;
        sw = 0;
        #10;
        reset = 0; #(TICK_DELAY);

        // stopwatch 기능
        // run_stop 상승 run 확인
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        // FND 출력 msec,sec <-> min,hour 변환 확인
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // run_stop 하강 run 확인
        btn_U = 1; #10000; btn_U = 0; #(TICK_DELAY);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY * 2);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        // FND 출력 msec,sec <-> min,hour 변환 확인
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // run 상태일 때 record 동작하고 상승 run
        btn_D = 1; #10000; btn_D = 0; #(TICK_DELAY);
        btn_U = 1; #10000; btn_U = 0; #(TICK_DELAY);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY * 3);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        // stop 상태에서 record 때 저장된 값 확인
        sw[2] = 1;                     #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        sw[2] = 0;                     #(TICK_DELAY);
        // 상승 run하다 run 상태일 때 record 동작
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        btn_D = 1; #10000; btn_D = 0; #(TICK_DELAY);
        // run 상태에서 record 때 저장된 값 확인
        sw[2] = 1;                     #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        sw[2] = 0;                     #(TICK_DELAY);
        // 멈추고 clear 동작 후 비워진 것 확인
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        btn_R = 1; #10000; btn_R = 0; #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        sw[2] = 1;                     #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        sw[2] = 0;                     #(TICK_DELAY);
        // watch 가기 전에 run 돌려두기
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        // watch 기능
        // stopwatch 동안 watch가 btn 입력에 영향받지 않고 동작한 걸 확인
        sw[1] = 1;                     #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // run 상태일 땐 시간이 조정되지 않는 걸 확인
        btn_R = 1; #10000; btn_R = 0; #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        btn_U = 1; #10000; btn_U = 0; #(TICK_DELAY);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // edit 상태일 때 시간이 조정되는 걸 확인
        btn_D = 1; #10000; btn_D = 0; #(TICK_DELAY);
        btn_R = 1; #10000; btn_R = 0; #(TICK_DELAY);
        sw[0] = 1;                     #(TICK_DELAY);
        btn_U = 1; #10000; btn_U = 0; #(TICK_DELAY);
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        btn_D = 1; #10000; btn_D = 0; #(TICK_DELAY);
        // 24시-12시 변환을 확인
        sw[0] = 1;                     #(TICK_DELAY);
        sw[2] = 1;                     #(TICK_DELAY);
        sw[2] = 0;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // watch 멈추고 stopwatch로 이동
        btn_D = 1; #10000; btn_D = 0; #(TICK_DELAY);
        sw[1] = 0;                     #(TICK_DELAY);
        // watch 동안 stopwatch가 btn 입력에 영향받지 않고 동작한 걸 확인
        sw[0] = 1;                     #(TICK_DELAY);
        sw[0] = 0;                     #(TICK_DELAY);
        // stop 후 마무리 reset
        btn_L = 1; #10000; btn_L = 0; #(TICK_DELAY);
        reset = 0;                     #(TICK_DELAY);
        $stop;
    end

endmodule
