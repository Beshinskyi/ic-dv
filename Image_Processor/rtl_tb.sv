module image_processor_tb;
    parameter DATA_WIDTH = 8;
    
    logic clk, rst_n;
    logic [1:0] config_select;
    logic [DATA_WIDTH*9-1:0] in_data;
    logic in_valid, in_ready;
    logic [DATA_WIDTH-1:0] out_data;
    logic out_valid, out_ready;
    
    int tests_passed, tests_failed;
    logic [DATA_WIDTH-1:0] result;
    string current_filter;
    logic [DATA_WIDTH*9-1:0] test_matrix;
  
    // Real image storage
    logic [7:0] input_image [0:4095];  // 64x64 image
    logic [7:0] output_image [0:4095];
    integer input_fd, output_fd;
    
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
        wait(in_ready);
        @(posedge clk);
        in_data = window_data;
        in_valid = 1'b1;
        @(posedge clk);
        wait(in_ready);
        in_valid = 1'b0;
    endtask
    
    task automatic receive_result(output logic [DATA_WIDTH-1:0] result);
        out_ready = 1'b1;
        wait(out_valid);
        @(posedge clk);
        result = out_data;
        out_ready = 1'b0;
    endtask

    // Getting 3x3 window from the input image
    function automatic void get_window(
        input int x, 
        input int y, 
        output logic [7:0] window [0:8]
    );
        int idx = 0;
        for (int dy = -1; dy <= 1; dy++) begin
            for (int dx = -1; dx <= 1; dx++) begin
                int nx = x + dx;
                int ny = y + dy;
                
                // Handle image boundary conditions (clamp)
                nx = (nx < 0) ? 0 : ((nx >= 64) ? 63 : nx);
                ny = (ny < 0) ? 0 : ((ny >= 64) ? 63 : ny);
                
                window[idx] = input_image[nx*64 + ny];
                idx++;
            end
        end
    endfunction

    //TODO Logic to prepare 3x3 window based on the specified edge handling method
    /*
    function automatic pix_window_data_t prepare_window(input int row, col, input string method);
    case (method)
        "padding": // Add padding logic
        "mirroring": // Add mirroring logic
        "zeroing": // Add zeroing logic
    endcase
    endfunction
    */

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

        // Test Case 2: Filtering the real image
        $display("\nStarting filtering the real image...");
        rst_n = 1'b0;
        config_select = 2'b00; // Laplacian Kernel 1 
        in_valid = 0;
        out_ready = 0;
        
        // Read input image
        $display("\nOpen grayscale image in hex:");
        input_fd = $fopen("test_image.hex", "r");
        if (input_fd) begin
            $display("Success! File test_image.hex is opened.");
        end else if (!input_fd) begin
          $display("Error: test_image.hex is missing.");
          $finish;
        end 
        for (int i = 0; i < 4096; i++)
            void' ($fscanf(input_fd, "%h\n", input_image[i]));
        $fclose(input_fd);
        
        // Reset sequence
        #100 rst_n = 1;
        #100;
        
        // Process image with chosen filter
        for (int x = 0; x < 64; x++) begin
            for (int y = 0; y < 64; y++) begin
                logic [7:0] window [0:8];
                logic [DATA_WIDTH*9-1:0] packed_window; // New packed window variable
                logic [7:0] result;
                
                // Get 3x3 window
                get_window(x, y, window);
                
                // Convert unpacked window to packed window
                for (int i = 0; i < 9; i++) begin
                    packed_window[DATA_WIDTH*i +: DATA_WIDTH] = window[i];
                end
                
                // Process window
                send_window(packed_window);
                receive_result(result);
                
                // Store result
                output_image[x*64 + y] = result;
            end
        end
        
        // Write output image
        output_fd = $fopen("filtered_test_image.hex", "w");
        $display("Success: Saving filtered_test_image.hex");
      if (!output_fd) begin
            $display("Error: Could not open output file");
            $finish;
        end
        for (int i = 0; i < 4096; i++)
            $fwrite(output_fd, "%h\n", output_image[i]);
        $fclose(output_fd);

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
        #100000000;
        $display("Error: Testbench timeout at time %0t!", $time);
        $display("in_valid=%b, in_ready=%b, out_valid=%b, out_ready=%b", 
                 in_valid, in_ready, out_valid, out_ready);
        $finish;
    end

endmodule
