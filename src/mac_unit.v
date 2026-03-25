// =============================================================================
// mac_unit.v  –  Multiply-Accumulate unit
// acc = acc + a*b   (registered, one cycle latency)
// reset or clear sets acc = 0
// =============================================================================
module mac_unit (
    input  clk,
    input  reset,
    input  clear,
    input  [7:0]  a,
    input  [7:0]  b,
    output reg [15:0] acc
);
    wire [15:0] product = a * b;

    always @(posedge clk or posedge reset) begin
        if (reset)
            acc <= 16'd0;
        else if (clear)
            acc <= 16'd0;
        else
            acc <= acc + product;
    end
endmodule
