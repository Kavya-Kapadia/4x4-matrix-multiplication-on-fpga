// =============================================================================
// load both matrix A and B and compute using mac unit
// =============================================================================
module matrix4x4_mac(
    input wire  clk,
    input wire reset,
    input wire start,
    input wire  [7:0] A,
    input wire  [7:0] B,
    input wire load_a,
    input wire load_b,
    input wire  [3:0] load_addr,
    output reg [15:0] C,
    output reg  [1:0] C_row,
    output reg  [1:0] C_column,
    output reg  C_valid,
    output reg   done,
    output wire ready
);
 
reg [7:0]  mat_a [0:15];
reg [7:0]  mat_b [0:15];
reg [15:0] mat_c [0:15];
 
reg [2:0] state;
reg [1:0] row, column, k;
reg       mac_clear;
reg [7:0] mac_a, mac_b;
wire [15:0] mac_acc;
 
mac_unit MAC (
    .clk(clk), .reset(reset),
    .clear(mac_clear),
    .a(mac_a), .b(mac_b),
    .acc(mac_acc)
);
 
localparam IDLE      = 3'd0;
localparam LOAD      = 3'd1;
localparam WAIT      = 3'd2;
localparam CAPTURE   = 3'd3;
localparam CLEARWAIT = 3'd4;
localparam DONE      = 3'd5;
 
assign ready = (state == IDLE);

integer i;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (i=0;i<16;i=i+1) mat_a[i] <= 0;
        for (i=0;i<16;i=i+1) mat_b[i] <= 0;
    end else begin
        if (load_a) mat_a[load_addr] <= A;
        if (load_b) mat_b[load_addr] <= B;
    end
end
 

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state     <= IDLE;
        mac_clear <= 1;
        C_valid   <= 0;
        k         <= 0;
        done      <= 0;
        row       <= 0;
        column    <= 0;
        mac_a     <= 0;
        mac_b     <= 0;
    end else begin
        done      <= 0;
        mac_clear <= 0;
        C_valid   <= 0;
 
        case(state)
            IDLE: begin
                row    <= 0;
                column <= 0;
                k      <= 0;
                if (start) begin
                    mac_clear <= 1;
                    state     <= LOAD;
                end
            end
 
            LOAD: begin
                mac_a <= mat_a[{row, k}];
                mac_b <= mat_b[{k, column}];
                if (k == 3) begin
                    k     <= 0;
                    state <= WAIT;
                end else
                    k <= k + 1;
            end
 
            WAIT: begin
                state <= CAPTURE;
            end
 
            CAPTURE: begin
                mat_c[{row,column}] <= mac_acc;
                C        <= mac_acc;
                C_row    <= row;
                C_column <= column;
                C_valid  <= 1;
                mac_clear <= 1;
                state    <= CLEARWAIT;
            end
 
            CLEARWAIT: begin
                mac_clear <= 1;
                if (column < 3) begin
                    column <= column + 1;
                    state  <= LOAD;
                end else begin
                    column <= 0;
                    if (row < 3) begin
                        row   <= row + 1;
                        state <= LOAD;
                    end else
                        state <= DONE;
                end
            end
 
            DONE: begin
                done  <= 1;
                state <= IDLE;
            end
        endcase
    end
end
endmodule
