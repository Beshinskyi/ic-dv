module image_processor_tb;
    parameter DATA_WIDTH = 8;
    
    logic clk, rst_n;
    logic [1:0] config_select;
    logic [DATA_WIDTH*9-1:0] in_data;
    logic in_valid, in_ready;
    logic [DATA_WIDTH-1:0] out_data;
    logic out_valid, out_ready;
    integer test_file = 0;
    
    int tests_passed, tests_failed;
    logic [DATA_WIDTH-1:0] result;
    string current_filter;
    logic [DATA_WIDTH*9-1:0] test_matrix;
    
    // DUT
    image_processor #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Tasks
    task automatic init_signals();
        rst_n = 1'b0;
        config_select = 2'b00;
        in_data = '0;
        in_valid = 1'b0;
        out_ready = 1'b1;
        tests_passed = 0;
        tests_failed = 0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
    endtask
    
    task automatic send_window(input logic [DATA_WIDTH*9-1:0] window_data);
        $display("Sending window data at time %0t", $time);
        wait(in_ready);
        @(posedge clk);
        in_data = window_data;
        in_valid = 1'b1;
        @(posedge clk);
        wait(in_ready);
        in_valid = 1'b0;
        $display("Window data sent at time %0t", $time);
    endtask
    
    task automatic receive_result(output logic [DATA_WIDTH-1:0] result);
        $display("Waiting for result at time %0t", $time);
        out_ready = 1'b1;
        wait(out_valid);
        @(posedge clk);
        result = out_data;
        out_ready = 1'b0;
        $display("Result received: %0d at time %0t", result, $time);
    endtask

    // Test execution
    initial begin
        // Initialize
        init_signals();
        $display("\nStarting tests at time %0t", $time);
        
        // Setup test matrix
        test_matrix = {8'd90, 8'd80, 8'd70, 
                       8'd60, 8'd50, 8'd40, 
                       8'd30, 8'd20, 8'd10};

        // Test Case 1.1: Laplacian Filter 1
        $display("\nTesting Laplacian Filter 1:");
        config_select = 2'b00;
        current_filter = "Laplacian 1";
        send_window(test_matrix);
        receive_result(result);
        check_result(result, 0, current_filter);
        repeat(5) @(posedge clk);

        // Test Case 1.2: Laplacian Filter 2
        $display("\nTesting Laplacian Filter 2:");
        config_select = 2'b01;
        current_filter = "Laplacian 2";
        send_window(test_matrix);
        receive_result(result);
        check_result(result, 0, current_filter);
        repeat(5) @(posedge clk);
        
        // Test Case 1.3: Gaussian Filter
        $display("\nTesting Gaussian Filter:");
        config_select = 2'b10;
        current_filter = "Gaussian (3x3)";
        send_window(test_matrix);
        receive_result(result);
        check_result(result, 50, current_filter);
        repeat(5) @(posedge clk);
        
        // Test Case 1.4: Average Filter
        $display("\nTesting Average Filter:");
        config_select = 2'b11;
        current_filter = "Average (3x3)";
        send_window(test_matrix);
        receive_result(result);
        check_result(result, 50, current_filter);
        repeat(5) @(posedge clk);

        // Test Case 2.1: Open grayscale image
      $display("\nOpen grayscale image in hex:");
        config_select = 2'b01;
        current_filter = "Laplacian 1";
      // TODO: $readmemh or $fopen ?
      test_file = $fopen ("test_image.hex", "r");
      	if (test_file) begin
      	$display("Success! File test_image.hex is opened.");
        $finish;
        end
      
     // Test Case 2.2: Result of filtering the image
  	//TODO - image processing with choosen filter and output as result
      
        // Test Summary
        $display("\nTest Summary:");
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);
        $finish;
    end
    
    // Result checking function
    function automatic void check_result(
        input logic signed [DATA_WIDTH-1:0] actual,
        input logic signed [DATA_WIDTH-1:0] expected,
        input string filter_name,
        input int tolerance = 1
    );
        if ($signed(actual) < $signed(expected) - tolerance || 
            $signed(actual) > $signed(expected) + tolerance) begin
            $display("ERROR: %s filter - Expected: %0d (±%0d), Got: %0d at time %0t", 
                    filter_name, $signed(expected), tolerance, $signed(actual), $time);
            tests_failed++;
        end else begin
            $display("PASS: %s filter result matches expected value %0d (±%0d) with actual %0d at time %0t", 
                    filter_name, $signed(expected), tolerance, $signed(actual), $time);
            tests_passed++;
        end
    endfunction

  // Timeout watchdog (to avoid unresponsive simulation)
    initial begin
        #10000;
        $display("ERROR: Testbench timeout at time %0t!", $time);
        $display("in_valid=%b, in_ready=%b, out_valid=%b, out_ready=%b", 
                 in_valid, in_ready, out_valid, out_ready);
        $finish;
    end

endmodule
