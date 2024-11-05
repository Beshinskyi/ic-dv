`timescale 1us / 1ns
// quick tb to test if rtl_design.sv works fine
// TODO: Testbench Creation Task: Image Processor with 3x3 Kernel Filters

module image_processor_tb();
    logic clk;
    logic rst_n;
    logic [1:0] config_select;
    logic [7:0] input_data [0:2][0:2];
    logic input_valid;
    logic input_ready;
    logic [15:0] output_data;
    logic output_valid;
    logic output_ready;

    image_processor DUT (
        .clk (clk),
        .rst_n (rst_n),
        .config_select(config_select),
        .input_data (input_data),
        .input_valid (input_valid),
        .input_ready (input_ready),
        .output_data (output_data),
        .output_valid (output_valid),
        .output_ready (output_ready)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        config_select = 0;
        input_valid = 0;
        output_ready = 1;
        
        for(int i = 0; i < 3; i++) begin
            for(int j = 0; j < 3; j++) begin
                input_data[i][j] = 0;
            end
        end

        $display("Start test");
        #20 rst_n = 1;
        
        for(int test = 0; test < 4; test++) begin
            #20;
            
            config_select = test[1:0];
            
            for(int i = 0; i < 3; i++) begin
                for(int j = 0; j < 3; j++) begin
                    input_data[i][j] = (i*3 + j + 1) * 10;
                end
            end
            
            input_valid = 1;
            @(posedge output_valid);
            input_valid = 0;
            #20;
        end
        
        #100;
        $display("Test completed!");
        $finish;
    end

    always @(posedge clk) begin
        if(output_valid && output_ready) begin
            $display("Output data = %d", output_data);
        end
    end

endmodule
