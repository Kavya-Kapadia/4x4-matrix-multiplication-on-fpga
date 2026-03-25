// =============================================================================
// Both A and B are fully pre-loaded
// press KEY[2] — MAC runs autonomously at 50MHz.
// switch[0:7]=input
// switch[9:8]=row
// switch[11:10]=column
// switch[13:12]=matrix select a=00 b=01 c=10
// KEY[0] = reset
// KEY[1] = store element
// KEY[2] = start computation
// HEX1,HEX0 = SW[7:0] live value
// HEX2      = row selected
// HEX3      = col selected
// HEX7..4   = stored value at selected position
// LEDR[0] = ready (IDLE, waiting for start)
// LEDR[1] = done (all 16 results computed)
// LEDR[2] = C_valid pulse per result
// LEDR[3] = computing
// LEDG[1:0] = C_row of last result
// LEDG[3:2] = C_column of last result
// =============================================================================

module de2_matrix_top(
    input         CLOCK_50,
    input  [17:0] SW,
    input  [3:0]  KEY,
    output [6:0]  HEX0, HEX1, HEX2, HEX3,
    output [6:0]  HEX4, HEX5, HEX6, HEX7,
    output [17:0] LEDR,
    output [7:0]  LEDG
);

wire clk   = CLOCK_50;
wire reset = ~KEY[0];

// ============================================
// SW Mapping
// ============================================
wire [7:0] data_in = SW[7:0];
wire [1:0] row_sel = SW[9:8];
wire [1:0] col_sel = SW[11:10];
wire [1:0] mat_sel = SW[13:12];
wire [3:0] addr    = {row_sel, col_sel};  
// ============================================
// Debounce KEY[1] — store
// ============================================
reg [19:0] deb1_cnt;
reg        key1_prev;
reg        store;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        deb1_cnt <= 0; key1_prev <= 1; store <= 0;
    end else begin
        store <= 0;
        if (~KEY[1] != key1_prev) begin
            deb1_cnt <= 0; key1_prev <= ~KEY[1];
        end else if (deb1_cnt < 20'hFFFFF)
            deb1_cnt <= deb1_cnt + 1;
        else if (key1_prev)
            store <= 1;
    end
end

// ============================================
// Debounce KEY[2] — start
// ============================================
reg [19:0] deb2_cnt;
reg        key2_prev;
reg        start_pulse;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        deb2_cnt <= 0; key2_prev <= 1; start_pulse <= 0;
    end else begin
        start_pulse <= 0;
        if (~KEY[2] != key2_prev) begin
            deb2_cnt <= 0; key2_prev <= ~KEY[2];
        end else if (deb2_cnt < 20'hFFFFF)
            deb2_cnt <= deb2_cnt + 1;
        else if (key2_prev)
            start_pulse <= 1;
    end
end


wire load_a = store && (mat_sel == 2'b00);
wire load_b = store && (mat_sel == 2'b01);


wire [15:0] mac_C;
wire [1:0]  mac_C_row, mac_C_col;
wire        mac_C_valid, mac_done, mac_ready;

matrix4x4_mac MAC_CORE (
    .clk      (clk),
    .reset    (reset),
    .start    (start_pulse),
    .A        (data_in),
    .B        (data_in),
    .load_a   (load_a),
    .load_b   (load_b),
    .load_addr(addr),
    .C        (mac_C),
    .C_row    (mac_C_row),
    .C_column (mac_C_col),
    .C_valid  (mac_C_valid),
    .done     (mac_done),
    .ready    (mac_ready)
);


reg [15:0] mat_c [0:15];
reg        computing;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        mat_c[0] <=0; mat_c[1] <=0; mat_c[2] <=0; mat_c[3] <=0;
        mat_c[4] <=0; mat_c[5] <=0; mat_c[6] <=0; mat_c[7] <=0;
        mat_c[8] <=0; mat_c[9] <=0; mat_c[10]<=0; mat_c[11]<=0;
        mat_c[12]<=0; mat_c[13]<=0; mat_c[14]<=0; mat_c[15]<=0;
        computing <= 0;
    end else begin
        if (start_pulse) computing <= 1;
        if (mac_done)    computing <= 0;
        if (mac_C_valid)
            mat_c[{mac_C_row, mac_C_col}] <= mac_C;
    end
end


reg [7:0] disp_a [0:15];
reg [7:0] disp_b [0:15];

always @(posedge clk or posedge reset) begin
    if (reset) begin : rst_disp
        integer j;
        for (j=0;j<16;j=j+1) begin disp_a[j]<=0; disp_b[j]<=0; end
    end else begin
        if (load_a) disp_a[addr] <= data_in;
        if (load_b) disp_b[addr] <= data_in;
    end
end

reg [15:0] disp_val;
always @(*) begin
    if      (mat_sel == 2'b00) disp_val = {8'd0, disp_a[addr]};
    else if (mat_sel == 2'b01) disp_val = {8'd0, disp_b[addr]};
    else                       disp_val = mat_c[addr];
end

// ============================================
// 7-Segment
// ============================================
function [6:0] seg7;
    input [3:0] d;
    case(d)
        4'd0: seg7=7'b1000000; 4'd1: seg7=7'b1111001;
        4'd2: seg7=7'b0100100; 4'd3: seg7=7'b0110000;
        4'd4: seg7=7'b0011001; 4'd5: seg7=7'b0010010;
        4'd6: seg7=7'b0000010; 4'd7: seg7=7'b1111000;
        4'd8: seg7=7'b0000000; 4'd9: seg7=7'b0010000;
        4'ha: seg7=7'b0001000; 4'hb: seg7=7'b0000011;
        4'hc: seg7=7'b1000110; 4'hd: seg7=7'b0100001;
        4'he: seg7=7'b0000110; 4'hf: seg7=7'b0001110;
        default: seg7=7'b1111111;
    endcase
endfunction

assign HEX0 = seg7(SW[3:0]);
assign HEX1 = seg7(SW[7:4]);
assign HEX2 = seg7({2'b00, row_sel});
assign HEX3 = seg7({2'b00, col_sel});
assign HEX4 = seg7(disp_val[3:0]);
assign HEX5 = seg7(disp_val[7:4]);
assign HEX6 = seg7(disp_val[11:8]);
assign HEX7 = seg7(disp_val[15:12]);

// ============================================
// LEDs
// ============================================
assign LEDR[0]    = mac_ready;
assign LEDR[1]    = mac_done;
assign LEDR[2]    = mac_C_valid;
assign LEDR[3]    = computing;
assign LEDR[17:4] = 0;

assign LEDG[1:0] = mac_C_row;
assign LEDG[3:2] = mac_C_col;
assign LEDG[7:4] = 0;

endmodule