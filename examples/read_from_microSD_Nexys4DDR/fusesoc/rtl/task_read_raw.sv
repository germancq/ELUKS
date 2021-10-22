/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-10-14 13:59:31
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-10-22 12:58:44
 * @ Description:
 */

//read all the raw data

module task_read_raw #(
    parameter BYTES_TO_READ = 256,
    parameter FIRST_BLOCK = 50
    )
(
    input clk,
    input rst,
    output spi_ctl,


    output rst_eluks,
    
    
    output logic rst_spi,
    output r_block,
    output logic r_multi_block,
    output logic r_byte,
    output [31:0] block_addr,
    input spi_err,
    input [7:0] spi_data,
    input spi_busy,

    output logic end_signal,
    output [63:0] exec_time
);
    assign spi_ctl = 0;
    assign rst_eluks = 1;
    assign block_addr = FIRST_BLOCK;
    assign r_block = 0;


    logic [63:0] counter_bytes_out;
    logic up_bytes;
    logic rst_counter_bytes;
    counter #(.DATA_WIDTH(64)) counter_bytes_impl(
        .clk(clk),
        .rst(rst_counter_bytes),
        .up(up_bytes),
        .down(1'b0),
        .din(64'h0),
        .dout(counter_bytes_out)
    );

    logic up_exec_time;
    logic rst_exec_time;
    counter #(.DATA_WIDTH(64)) counter_timer_exec(
        .clk(clk),
        .rst(rst_exec_time),
        .up(up_exec_time),
        .down(1'b0),
        .din(32'b0),
        .dout(exec_time)
    );

    localparam IDLE = 0;
    localparam RST_SPI = 1;
    localparam READ_FIRST_BLOCK = 2;
    localparam WAIT_BLOCK = 3;
    localparam READ_DATA = 4;
    localparam WAIT_BYTE = 5;
    localparam END_STATE = 6;

    logic [2:0] current_state;
    logic [2:0] next_state;


    always_comb begin
        
        next_state = current_state;
        rst_spi = 0;
        r_multi_block = 0;
        r_byte = 0;
        end_signal = 0;
        
        rst_counter_bytes = 1'b0;
        up_bytes = 1'b0;

        rst_exec_time = 0;
        up_exec_time = 1;

        case (current_state)
            IDLE:   
                begin
                    rst_counter_bytes = 1;
                    rst_exec_time = 1;
                    next_state = RST_SPI;
                end
            RST_SPI:
                begin
                    rst_exec_time = 1;
                    rst_spi = 1;
                    next_state = READ_FIRST_BLOCK;
                end
            READ_FIRST_BLOCK:
                begin
                    rst_exec_time = 1;
                    if(spi_busy == 0) begin
                        r_multi_block = 1;
                        next_state = WAIT_BLOCK;
                    end
                end
            WAIT_BLOCK:
                begin
                    r_multi_block = 1;
                    if(spi_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            READ_DATA:
                begin
                    r_multi_block = 1;
                    if(counter_bytes_out == BYTES_TO_READ-1) begin
                        next_state = END_STATE;
                    end
                    else begin
                        up_bytes = 1;
                        r_byte = 1;
                        next_state = WAIT_BYTE;
                    end
                end
            WAIT_BYTE:
                begin
                    r_multi_block = 1;
                    if(spi_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            END_STATE:
                begin
                    up_exec_time = 0;
                    end_signal = 1;
                end
            default:
                begin
                    
                end
        endcase
    end
    

    always_ff @( posedge clk ) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

endmodule:task_read_raw