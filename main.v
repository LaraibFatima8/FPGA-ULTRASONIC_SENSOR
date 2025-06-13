module ultrasonic_sensor(
    input clk,
    input reset,
    input echo,
    output reg trig,
    output reg [7:0] distance_cm,
    output reg transmit_ready
);

    reg [19:0] counter = 0;
    reg [21:0] echo_counter = 0; // more bits for longer count
    reg [3:0] state = 0;

    localparam IDLE      = 0;
    localparam TRIG_HIGH = 1;
    localparam WAIT_ECHO = 2;
    localparam COUNT_ECHO = 3;
    localparam DONE      = 4;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            echo_counter <= 0;
            trig <= 0;
            distance_cm <= 0;
            state <= IDLE;
            transmit_ready <= 0;
        end else begin
            case (state)
                IDLE: begin
                    trig <= 0;
                    transmit_ready <= 0;
                    counter <= counter + 1;
                    if (counter == 20'd500000) begin  // 10 ms at 50 MHz clock
                        counter <= 0;
                        state <= TRIG_HIGH;
                    end
                end

                TRIG_HIGH: begin
                    trig <= 1;
                    counter <= counter + 1;
                    if (counter == 20'd500) begin    // 10 us pulse (50 MHz = 20ns cycles)
                        trig <= 0;
                        counter <= 0;
                        state <= WAIT_ECHO;
                    end
                end
                WAIT_ECHO: begin
                    if (echo == 1) begin
                        echo_counter <= 0;
                        state <= COUNT_ECHO;
                    end
                end

                COUNT_ECHO: begin
                    if (echo == 1) begin
                        echo_counter <= echo_counter + 1;
                    end else begin
                        state <= DONE;
                    end
                end
					DONE: begin
						 distance_cm <= (echo_counter * 22000) >> 26;
						 transmit_ready <= 1;
						 state <= IDLE;
					end


                default: state <= IDLE;
            endcase
        end
    end
endmodule


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


  
module top_module(
    input clk,
    input reset,
    input echo,
    input RS232_DTE_RXD,  // Added UART RX input
    output trig,
    output RS232_DTE_TXD,
    output [7:0] led,
	 output lcd_rs,
output lcd_e,
output [3:0] lcd_data

);

    wire [7:0] raw_distance;
	 reg [7:0] filtered_distance;

    wire transmit_ready;

    wire [7:0] rx_data;
    wire rx_data_ready;

    reg measure_enable = 1;  // Default enabled

    // UART RX Instance
    uart_rx #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(9600)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx_in(RS232_DTE_RXD),
        .data_out(rx_data),
        .data_ready(rx_data_ready)
    );

    // Ultrasonic sensor with enable control (modify to add enable)
    reg usensor_reset;
    always @(posedge clk or posedge reset) begin
        if (reset) 
            usensor_reset <= 1;
        else
            usensor_reset <= ~measure_enable;
    end

    ultrasonic_sensor usensor(
        .clk(clk),
        .reset(usensor_reset),
        .echo(echo),
        .trig(trig),
        .distance_cm(raw_distance),
        .transmit_ready(transmit_ready)
    );

    uart_tx #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(9600)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .data_in(filtered_distance),  
        .data_valid(transmit_ready),
        .tx_out(RS232_DTE_TXD),
        .tx_done()
    );
	 
	 

 always @(posedge clk or posedge reset) begin
    if (reset) begin
        measure_enable <= 1;
    end else if (rx_data_ready) begin
        if (rx_data == 8'h44) // 'D'
            measure_enable <= 0;
        else if (rx_data == 8'h45) // 'E'
            measure_enable <= 1;
    end
end


    
    reg [1:0] dist_index;
    reg [7:0] dist_buffer [0:3];
    reg [9:0] avg_distance;  


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dist_index <= 0;
            dist_buffer[0] <= 0;
            dist_buffer[1] <= 0;
            dist_buffer[2] <= 0;
            dist_buffer[3] <= 0;
            filtered_distance <= 0;
        end else if (transmit_ready) begin
            dist_buffer[dist_index] <= raw_distance;
            dist_index <= dist_index + 1;
            if (dist_index == 2'd3) begin
                avg_distance <= (dist_buffer[0] + dist_buffer[1] + dist_buffer[2] + dist_buffer[3]) >> 2;
                filtered_distance <= avg_distance[7:0];
            end
        end
    end
assign led = filtered_distance;
endmodule
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

