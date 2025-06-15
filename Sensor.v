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
