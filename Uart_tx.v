module uart_tx #(
    parameter CLK_FREQ = 50000000, // 50 MHz clock
    parameter BAUD_RATE = 9600
)(
    input clk,
    input reset,
    input [7:0] data_in,
    input data_valid,
    output reg tx_out,
    output reg tx_done
);

    localparam integer BAUD_TICK_COUNT = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_rate_counter = 0;
    reg [3:0] state = 0;
    reg [7:0] data_buffer = 0;
    reg [2:0] bit_index = 0;

    localparam IDLE = 0;
    localparam START_BIT = 1;
    localparam DATA_BITS = 2;
    localparam STOP_BIT = 3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_rate_counter <= 0;
            state <= IDLE;
            tx_out <= 1; // Idle is high
            tx_done <= 0;
            data_buffer <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_done <= 0;
                    baud_rate_counter <= 0;
                    if (data_valid) begin
                        data_buffer <= data_in;
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    if (baud_rate_counter == BAUD_TICK_COUNT - 1) begin
                        baud_rate_counter <= 0;
                        tx_out <= 0; // Start bit low
                        state <= DATA_BITS;
                        bit_index <= 0;
                    end else begin
                        baud_rate_counter <= baud_rate_counter + 1;
                    end
                end

                DATA_BITS: begin
                    if (baud_rate_counter == BAUD_TICK_COUNT - 1) begin
                        baud_rate_counter <= 0;
                        tx_out <= data_buffer[bit_index];
                        if (bit_index == 7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        baud_rate_counter <= baud_rate_counter + 1;
                    end
                end

                STOP_BIT: begin
                    if (baud_rate_counter == BAUD_TICK_COUNT - 1) begin
                        baud_rate_counter <= 0;
                        tx_out <= 1; // Stop bit high
                        state <= IDLE;
                        tx_done <= 1;
                    end else begin
                        baud_rate_counter <= baud_rate_counter + 1;
                    end
                end
            endcase
        end
    end
endmodule
