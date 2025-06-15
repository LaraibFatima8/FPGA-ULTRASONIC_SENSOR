

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

   
      
