`timescale 1ns / 1ps
//--------------------------------------------------------------------------------
// Engineer: Li Jianing
// Create Date: 2021/07/13 
// Design Name: Asynchronized fifo design
// Module Name: dualport_ram_async.v
// Description: 
// 
// Dependencies: 
// 
// Revision: 
//          Revision 0.01 - File Created
// Additional Comments:
// 
//--------------------------------------------------------------------------------

module dualport_ram_async #(
        //--------parameter define----------------//
		parameter	DATA_WIDTH = 8,
		parameter	ADDR_WIDTH = 4  //ram depth is equal to 2^(ADDR_WIDTH)
		)(
        //----------ports define------------------//
		input                       write_clk,
		input                       write_rst_n,
		input                       write_en,
		input  [ADDR_WIDTH-1:0]     write_addr,
		input  [DATA_WIDTH-1:0]     write_data,
		input                       read_clk,
		input                       read_rst_n,
		input                       read_en,
		input  [ADDR_WIDTH-1:0]     read_addr,
		output [DATA_WIDTH-1:0]     read_data
    );

    //----------localparam define-----------------//
    //left shift 1 with 4(ADDR_WIDTH) bits = 2^(ADDR_WIDTH)
    localparam RAM_DEPTH = 1 << ADDR_WIDTH; 

    //----------ram define------------------------//
    reg [DATA_WIDTH - 1 : 0] mem [RAM_DEPTH - 1 : 0];

    //----------loop variable define--------------//
    integer II;

    //------sequential logic for data write-------//
    always @(posedge write_clk or negedge write_rst_n) begin
        if (!write_rst_n) begin
            for (II = 0; II < RAM_DEPTH; II = II + 1) begin
                mem[II] <= {DATA_WIDTH{1'b0}};
            end
        end
        else if(write_en)
            mem[write_addr] <= write_data;
    end
    //------combinaional logic for data write-----//
    assign read_data = mem[read_addr];

endmodule




module Sync_Pulse (
                  clk_a,        
                  clk_b,   
                  rst_n,            
                  pulse_a_in,   
                 
                  pulse_b_out,  
                  b_out 
                  );
/****************************************************/

    input               clk_a;
    input               clk_b;
    input               rst_n;
    input               pulse_a;
    
    output              pulse_b_out;
    output              b_out;      
    
/****************************************************/  

    reg                 signal_a;
    reg                 signal_b;
    reg                 signal_b_r1;
    reg                 signal_b_r2;
    reg                 signal_b_a1;
    reg                 signal_b_a2;
    
/****************************************************/
    //在时钟域clk_a下，生成展宽信号signal_a
    always @ (posedge clk_a or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                signal_a <= 1'b0;
            else if (pulse_a_in)            //检测到到输入信号pulse_a_in被拉高，则拉高signal_a
                signal_a <= 1'b1;
            else if (signal_b_a2)           //检测到signal_b1_a2被拉高，则拉低signal_a
                signal_a <= 1'b0;
            else;
        end
    
    //在时钟域clk_b下，采集signal_a，生成signal_b
    always @ (posedge clk_b or negedge rst_n)
        begin
            if (rst_n == 1'b0)
                signal_b <= 1'b0;
            else
                signal_b <= signal_a;
        end
    //多级触发器处理
    always @ (posedge clk_b or negedge rst_n)
        begin
            if (rst_n == 1'b0) 
                begin
                    signal_b_r1 <= 1'b0;
                    signal_b_r2 <= 1'b0;
                end
            else 
                begin
                    signal_b_r1 <= signal_b;        //对signal_b打两拍
                    signal_b_r2 <= signal_b_r1;
                end
        end
    //在时钟域clk_a下，采集signal_b_r1，用于反馈来拉低展宽信号signal_a
    always @ (posedge clk_a or negedge rst_n)
        begin
            if (rst_n == 1'b0) 
                begin
                    signal_b_a1 <= 1'b0;
                    signal_b_a2 <= 1'b0;
                end
            else 
                begin
                    signal_b_a1 <= signal_b_r1;     //对signal_b_r1打两拍，因为同样涉及到跨时钟域   
                    signal_b_a2 <= signal_b_a1;
                end
        end

    assign  pulse_b_out =   signal_b_r1 & (~signal_b_r2);
    assign  b_out       =   signal_b_r1;

endmodule
