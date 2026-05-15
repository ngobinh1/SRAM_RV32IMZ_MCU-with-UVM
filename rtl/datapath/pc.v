module pc (
    input wire clk,
    input wire rst,
    input wire en,
    input wire [31:0] pc_next,
    output reg [31:0] pc
);

    // Initialize pc to zero
    initial begin
        pc = 32'h00000000;
    end

    always @(posedge clk) begin
        if (rst == 1'b0) begin
            pc <= 32'h00000000;
        end
        else begin
            if(en == 1'b1) begin 
                pc <= pc_next;    
            end
            else begin
                pc <= pc;
            end
        end
    end
endmodule