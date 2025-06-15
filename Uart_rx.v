module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 9600
)(
    input clk,
    input reset,
    input rx_in,
    output reg [7:0] data_out,
    output reg data_ready
);

    localparam integer BAUD_TICK_COUNT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BAUD_TICK = BAUD_TICK_COUNT / 2;

    reg [15:0] baud_counter = 0;
    reg [3:0] bit_index = 0;
    reg rx_sync_0 = 1, rx_sync_1 = 1;
    reg rx_sampled = 1;
    reg receiving = 0;
    reg [7:0] data_buffer = 0;

    // Synchronize rx input to clk domain
    always @(posedge clk) begin
        rx_sync_0 <= rx_in;
        rx_sync_1 <= rx_sync_0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_counter <= 0;
            bit_index <= 0;
            receiving <= 0;
            data_ready <= 0;
            data_out <= 0;
        end else begin
            data_ready <= 0;  // clear data ready each clock

            if (!receiving) begin
                // Wait for start bit (falling edge)
                if (rx_sync_1 == 0) begin
                    receiving <= 1;
                    baud_counter <= HALF_BAUD_TICK;  // wait half bit time to sample middle of start bit
                    bit_index <= 0;
                end
            end else begin
                if (baud_counter == BAUD_TICK_COUNT - 1) begin
                    baud_counter <= 0;

                    if (bit_index == 0) begin
                        // Check start bit, should still be 0
                        if (rx_sync_1 == 0) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            // False start bit, abort reception
                            receiving <= 0;
                        end
                    end else if (bit_index >= 1 && bit_index <= 8) begin
                        // Data bits 0-7
                        data_buffer[bit_index - 1] <= rx_sync_1;
                        bit_index <= bit_index + 1;
                    end else if (bit_index == 9) begin
                        // Stop bit, should be 1
                        if (rx_sync_1 == 1) begin
                            data_out <= data_buffer;
                            data_ready <= 1;
                        end
                        receiving <= 0;
                    end
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end
        end
    end

endmodule

