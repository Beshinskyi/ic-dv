// RTL Design Task: Image Processor with 3x3 Kernel Filters
module image_processor #(
    parameter DATA_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [1:0] config_select, // configuration
    // DXI input
    input  logic [DATA_WIDTH*9-1:0] in_data,  // 3x3 window
    input  logic in_valid,
    output logic in_ready,
    // DXI  output
    output logic [DATA_WIDTH-1:0] out_data,
    output logic out_valid,
    input  logic out_ready
);

    // Signals for kernel coefficients
    logic signed [3:0] kernel [0:3][0:8];  // 4 filters
    logic signed [DATA_WIDTH-1:0] window [0:8];
  logic signed [DATA_WIDTH+4:0] result;  // extra bits for multiplication and addition
    
    // Filters
    always_comb begin
      kernel[0] = '{0, -1, 0, -1, 4, -1, 0, -1, 0};     // Laplacian Kernel 1  (2'b00)
      kernel[1] = '{-1, -1, -1, -1, 8, -1, -1, -1, -1}; // Laplacian Kernel 2  (2'b01)
      kernel[2] = '{1, 2, 1, 2, 4, 2, 1, 2, 1};         // Gaussian Filter     (2'b10)
      kernel[3] = '{1, 1, 1, 1, 1, 1, 1, 1, 1};         // Average Filter      (2'b11)
    end

    // Unpack input data into window array
    always_comb begin
        for (int i = 0; i < 9; i++) begin
            window[i] = in_data[DATA_WIDTH*i +: DATA_WIDTH];
        end
    end

    // Convolution process with normalization
    always_comb begin
        result = '0;
        for (int i = 0; i < 9; i++) begin  
            result += window[i] * kernel[config_select][i];
            $display("Intermediate result (before normalization) = %0d", result);
        end
        
        // Normalize based on filter type with rounding
        case (config_select)
          2'b00, 2'b01: begin  // Laplacian filters (no divide)
        // add proper bit truncation and sign extension
        out_data = result[DATA_WIDTH+4:0] > $signed({DATA_WIDTH{1'b0}}) ? 
                   $signed({DATA_WIDTH{1'b0}}) :
                   result[DATA_WIDTH+4:0] < -$signed({DATA_WIDTH{1'b0}}) ? 
                   -$signed({DATA_WIDTH{1'b0}}) :
                   result[DATA_WIDTH-1:0];
            end
            2'b10: begin         // Gaussian (divide by 16)
                out_data = (result + 8) >>> 4;  // Add 8 for proper rounding
            end
            2'b11: begin         // Average (divide by 9)
            /*
            For division by 9, multiply by 7281 (65536/9 = 7281.777...)
            and shift right by 16 bits for fixed-point division
            */
                logic signed [DATA_WIDTH+20:0] temp;
                temp = (result * 7281 + 32768) >>> 16;  // Add 32768 for proper rounding
                out_data = temp;
            end
        endcase
    end

    // Handshaking logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            in_ready <= 1'b1;
        end else begin
            if (in_valid && in_ready) begin
                out_valid <= 1'b1;
            end else if (out_valid && out_ready) begin
                out_valid <= 1'b0;
            end

            in_ready <= !out_valid || out_ready;
        end
    end

endmodule
