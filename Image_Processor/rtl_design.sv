// RTL Design Task: Image Processor with 3x3 Kernel Filters
module image_processor (
  input logic clk,
  input logic rst_n,
  input logic [1:0] config_select,
  
// DXI handshake
  input logic [7:0] input_data [0:2][0:2],
  input logic input_valid,
  output logic input_ready,
    
  output logic [15:0] output_data,
  output logic output_valid,
  input  logic output_ready
);
 
  logic signed [7:0]  filter [0:2][0:2];
  logic signed [15:0] acc; // to avoid overflow during multiplying
  logic processing;
  logic [3:0] divisor; // coefficient for normalization stage

// filter selection
   always_comb begin
       case (config_select)
           2'b00: begin // Laplacian Kernel 1 - edge cases
               filter = '{
                   '{0,  -1,  0},
                   '{-1,  4, -1},
                   '{0,  -1,  0}
               };
               divisor = 1;
           end
            
           2'b01: begin // Laplacian Kernel 2 - edge cases
               filter = '{
                   '{-1, -1, -1},
                   '{-1,  8, -1},
                   '{-1, -1, -1}
               };
               divisor = 1;
           end
            
           2'b10: begin // Gaussian Filter (3x3) - blurring/smoothing
               filter = '{
                   '{1, 2, 1},
                   '{2, 4, 2},
                   '{1, 2, 1}
               };
               divisor = 16;
           end
            
           2'b11: begin // Average Filter (3x3) - noise reduction
               filter = '{
                   '{1, 1, 1},
                   '{1, 1, 1},
                   '{1, 1, 1}
               };
               divisor = 9;
           end
       endcase
   end

// stages sequence management
   enum logic [1:0] {
       IDLE,    // waiting for new data
       COMPUTE, // calculating
       OUTPUT   // result
   } state, next_state;

   always_ff @(posedge clk or negedge rst_n) begin
       if (!rst_n)
           state <= IDLE;
       else
           state <= next_state;
   end

   always_comb begin
       next_state = state;
       case (state)
           IDLE: 
               if (input_valid)
                   next_state = COMPUTE;
            
           COMPUTE:
               next_state = OUTPUT;
            
           OUTPUT:
               if (output_ready)
                   next_state = IDLE;
       endcase
   end

// calculation
   always_ff @(posedge clk) begin
       if (state == COMPUTE) begin
           acc <= '0;
           for (int i = 0; i < 3; i++) begin
               for (int j = 0; j < 3; j++) begin
                   acc <= acc + (input_data[i][j] * filter[i][j]);
               end
           end
       end
   end

// states synchronization
   always_comb begin
       input_ready = (state == IDLE);
       output_valid = (state == OUTPUT);
        
       output_data = acc / divisor; // normalization to avoid overflow
   end

endmodule
