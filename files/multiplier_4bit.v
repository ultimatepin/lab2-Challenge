// 4-bit multiplier module in Verilog
module multiplier_4bit(
    input bit [3:0] a,         // 4-bit input A
    input bit [3:0] b,         // 4-bit input B
    output bit [7:0] product   // 8-bit product output
);
// The multiplication operator '*' performs a combinational multiplication
assign product = a * b;
endmodule