`timescale 1ns / 1ps
//--------------------------------------------------------------------------------
// Engineer: Li Jianing
// Create Date: 2021/07/13 
// Design Name: Asynchronized fifo design
// Module Name: fifo_async
// Description: for git version 2 for branch dev here
// 
// Dependencies: dualport_ram_async, push_interface, pop_interface
// 
// Revision: 
//          Revision 0.01 - File Created
// Additional Comments:
// 
//--------------------------------------------------------------------------------
module async_fifo #(
        //--------parameter define----------------//
		parameter	DATA_WIDTH          = 8,
		parameter	FIFO_DEPTH          = 16,
		parameter	FIFO_ALMOST_FULL    = FIFO_DEPTH-1,
		parameter	FIFO_ALMOST_EMPTY   = 1
		)(
        //----------ports define------------------//
		input                       write_clk,         // asynchronized read and write has separate clk
		input                       write_rst_n,
		input                       write_en,
		input  [DATA_WIDTH-1:0]     write_data,
		input                       read_clk,
		input                       read_rst_n,
		input                       read_en,
		output [DATA_WIDTH-1:0]     read_data,
		output reg                  full,
		output reg                  almost_full,
        output reg                  empty,
		output reg                  almost_empty
	);
	
        //-------local parameter define-----------//
        //localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
        localparam ADDR_WIDTH = 4;

        //-------signal  define------------------//
        //the extra bits in MSB is used for check overloop
        reg  [ADDR_WIDTH:0] read_addr;
        reg  [ADDR_WIDTH:0] read_addr_next;

        reg  [ADDR_WIDTH:0] write_addr;
        reg  [ADDR_WIDTH:0] write_addr_next;

        wire [ADDR_WIDTH:0] write_addr_gray_next;
        reg  [ADDR_WIDTH:0] write_addr_gray;
        reg  [ADDR_WIDTH:0] write_addr_gray_rsyn1;
        reg  [ADDR_WIDTH:0] write_addr_gray_rsyn2;
        wire [ADDR_WIDTH:0] write_addr_gray_rsyn;

        wire [ADDR_WIDTH:0] read_addr_gray_next;
        reg  [ADDR_WIDTH:0] read_addr_gray;
        reg  [ADDR_WIDTH:0] read_addr_gray_wsyn1;
        reg  [ADDR_WIDTH:0] read_addr_gray_wsyn2;
        wire [ADDR_WIDTH:0] read_addr_gray_wsyn;

        wire [ADDR_WIDTH:0] read_addr_gray_wsyn_bin;
        wire [ADDR_WIDTH:0] fifo_used_write;
        wire [ADDR_WIDTH:0] fifo_used_read;
        wire [ADDR_WIDTH:0] write_addr_gray_rsyn_bin;

        wire                write_valid;
        wire                read_valid;

        wire                full_comb;
        wire                empty_comb;

        wire                almost_full_comb ;
        wire                almost_empty_comb;  

        //---combinaional logic for valid signal--//
        // these signal does not impact by clk, then comb logic
        assign write_valid = (write_en & (! full ));
        assign read_valid  = (read_en  & (! empty));


        //-----instination of dual-port ram------//
        dualport_ram_async # (
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH)
            )dualport_ram_async_inst
            (
            //----------ports define------------------//
            .write_clk      (write_clk),
            .write_rst_n    (write_rst_n),
            .write_en       (write_en),
            .write_addr     (write_addr),
            .write_data     (write_data),
            .read_clk       (read_clk),
            .read_rst_n     (read_rst_n),
            .read_en        (read_en),
            .read_addr      (read_addr),
            .read_data      (read_data)
            );

        //----------logic for write/read curr & next logic-----------//
        //next addr is controled by valid signal, independet from clk
        //curr addr is activated by clk signal, at posedge curr <= next
        //Good practice to separate signal in different always block

        always @(*) begin
            if(write_valid)
                write_addr_next = write_addr + 1'b1;
            else
                write_addr_next = write_addr;
        end

        always @(posedge write_clk or negedge write_rst_n) begin
            if(!write_rst_n)
                write_addr <= {{ADDR_WIDTH + 1} {1'b0}};
            else
                write_addr <= write_addr_next;
        end

        always @(*) begin
            if(read_valid)
                read_addr_next = read_addr + 1'b1;
            else
                read_addr_next = read_addr;
        end

        always @(posedge read_clk or negedge read_rst_n) begin
            if(!read_rst_n)
                read_addr <= {{ADDR_WIDTH + 1} {1'b0}};
            else
                read_addr <= read_addr_next;
        end


    //-----------generate gray code for write/read addr--------------//
    //gray code: signal right shift 1bit and xor with origin
    //next gray code is control by combinational logic
    //curr gray code is updated by clk signal, at posedge curr <= next

    assign write_addr_gray_next = (write_addr_next >> 1) ^ write_addr_next;

    always @(posedge write_clk or negedge write_rst_n) begin
        if(!write_rst_n)
            write_addr_gray <= {{ADDR_WIDTH + 1} {1'b0}};
        else
            write_addr_gray <= write_addr_gray_next;
    end

    assign read_addr_gray_next = (read_addr_next >> 1) ^ read_addr_next;

    always @(posedge read_clk or negedge read_rst_n) begin
        if(!read_rst_n)
            read_addr_gray <= {{ADDR_WIDTH + 1} {1'b0}};
        else
            read_addr_gray <= read_addr_gray_next;
    end


    //--------------cross clk field process(read/write)---------------//
    // use write clock sync read addr, two clip

    //use write clock to sync read addr
    always @(posedge write_clk or negedge write_rst_n) begin
        if(!write_rst_n) begin
            read_addr_gray_wsyn1 <= {(ADDR_WIDTH+1){1'b0}};
            read_addr_gray_wsyn2 <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            read_addr_gray_wsyn1 <= read_addr_gray;
            read_addr_gray_wsyn2 <= read_addr_gray_wsyn1;
        end
    end
    assign read_addr_gray_wsyn = read_addr_gray_wsyn2;

    //use read clock to sync write addr
    always @(posedge read_clk or negedge read_rst_n) begin
        if(!read_rst_n) begin
            write_addr_gray_rsyn1 <= {(ADDR_WIDTH+1){1'b0}};
            write_addr_gray_rsyn2 <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            write_addr_gray_rsyn1 <= write_addr_gray;
            write_addr_gray_rsyn2 <= write_addr_gray_rsyn1;
        end
    end
    assign write_addr_gray_rsyn = write_addr_gray_rsyn2;


    //------------------generate full/empty signal--------------------//
    always @(posedge write_clk or negedge write_rst_n) begin
        if (!write_rst_n) 
            full <= 1'b0;
        else 
            full <= full_comb;
    end
    assign full_comb = (write_addr_gray == {~read_addr_gray_wsyn[ADDR_WIDTH :ADDR_WIDTH - 1], read_addr_gray_wsyn[ADDR_WIDTH-2:0]});

    always @(posedge read_clk or negedge read_rst_n) begin
        if(!read_rst_n)
            empty <= 1'b0;
        else
            empty <= empty_comb;
    end

    assign empty_comb = read_addr_gray_next[ADDR_WIDTH : 0] == write_addr_gray_rsyn[ADDR_WIDTH : 0];

    
    //----------------generate almost full/empty signal---------------//
    // fifo_used_write is used to record the space used by writing
    // fifo_used_write is calculate by write addr - read addr (both in binary)
    
    generate
        genvar i;
            for (i = ADDR_WIDTH; i>=0; i = i - 1) begin:loop1
                if (i == ADDR_WIDTH) begin
                    assign read_addr_gray_wsyn_bin[i] = read_addr_gray_wsyn[i];
                end
                else begin
                    assign read_addr_gray_wsyn_bin[i] = read_addr_gray_wsyn[i] ^ read_addr_gray_wsyn_bin[i + 1];
                end
            end
    endgenerate

    assign fifo_used_write = write_addr_next - read_addr_gray_wsyn_bin;
    assign almost_full_comb = (fifo_used_write >= FIFO_ALMOST_FULL);

    // sequential logic to output almost full signal
    always @(posedge write_clk or negedge write_rst_n) begin
        if (!write_rst_n) begin
            almost_full <=1'b0;
        end
        else begin
            almost_full <= almost_full_comb;
        end
    end

    generate
        genvar j;
            for (j = ADDR_WIDTH; j>=0; j = j - 1) begin:loop2
                if (j == ADDR_WIDTH) begin
                    assign write_addr_gray_rsyn_bin[j] = write_addr_gray_rsyn[j];
                end
                else begin
                    assign write_addr_gray_rsyn_bin[j] = write_addr_gray_rsyn[j] ^ write_addr_gray_rsyn_bin[j + 1];
                end
            end
    endgenerate 

    assign fifo_used_read = write_addr_gray_rsyn_bin - read_addr_gray_next;
    assign almost_empty_comb = (fifo_used_read<=FIFO_ALMOST_EMPTY);

    always @(posedge read_clk or negedge read_rst_n) begin
        if(!read_rst_n)
            almost_empty <= 1'b0;
        else
            almost_empty <= almost_empty_comb;
    end

endmodule
