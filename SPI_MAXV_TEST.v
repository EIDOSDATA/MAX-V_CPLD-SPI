
module SPI_MAXV_TEST(

	clk, // 12
	
	SCK, // SCK : PIN 41 >> AD
	MOSI, // RX : PIN 40 >> AD
	MISO, // TX : PIN 81 >> IOL
	SSEL, // SS : PIN 38 >> AD
	
	LED, // CHECK LED : PIN 54,53,52,51
	
	TR_DIR_1, //1 = A to B(input); 0 = B to A(output) >> PIN 100
	TR_OE_1, // PIN 86	
	TR_DIR_2, //1 = A to B(input); 0 = B to A(output) >> PIN 29
	TR_OE_2, // PIN 28	
	TR_DIR_3, //1 = A to B(input); 0 = B to A(output) >> PIN 85
	TR_OE_3 // PIN 74
);
	//input clk;
	//input SCK, SSEL, MOSI;
	//output MISO;
	//output LED;
	
	input wire		clk; // 12
	
	input wire		SCK; // SCK : PIN 41 >> AD
	input wire		MOSI; // RX : PIN 40 >> AD
	output wire		MISO; // TX : PIN 81 >> IOL
	input wire		SSEL; // SS : PIN 38 >> AD
	
	output			LED; // CHECK LED : PIN 54,53,52,51
	
	output wire		TR_DIR_1; //1 = A to B(input); 0 = B to A(output) >> PIN 100
	output wire		TR_OE_1; // PIN 86	
	output wire		TR_DIR_2; //1 = A to B(input); 0 = B to A(output) >> PIN 29
	output wire		TR_OE_2; // PIN 28	
	output wire		TR_DIR_3; //1 = A to B(input); 0 = B to A(output) >> PIN 85
	output wire		TR_OE_3; // PIN 74
	
/* IO CONFIG */
	// IOH
	assign			TR_DIR_1  = 1'b1; //1 = A to B(input); 0 = B to A(output) >> PIN 100
   assign			TR_OE_1  = 1'b0; // PIN 86
	// MOSI (RX)
   assign			TR_DIR_2  = 1'b1; //1 = A to B(input); 0 = B to A(output) >> PIN 29
   assign			TR_OE_2  = 1'b0; // PIN 28
	// MISO (TX)
	assign			TR_DIR_3  = 1'b0; //1 = A to B(input); 0 = B to A(output) >> PIN 85
   assign			TR_OE_3  = 1'b0; // PIN 74	
/* END OF IO CONFIG */
	
/*SYNC*/
	// Sync SCK to the FPGA clock using a 3-bits shift register
	reg [2:0] SCKr;
	
	always @(posedge clk) SCKr <= {SCKr[1:0], SCK};

	wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges	
	wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

	// Same thing for SSEL
	reg [2:0] SSELr;
	always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};	
	
	wire SSEL_active = ~SSELr[1];  // SSEL is active low
	wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
	wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

	// And for MOSI
	reg [1:0] MOSIr;
	
	always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
	
	wire MOSI_data = MOSIr[1];	
/* END OF SYNC */


/* RECEIVE */
	// we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
	reg [2:0] bitcnt;
	reg byte_received;  // high when a byte has been received
	reg [7:0] byte_data_received;

	always @(posedge clk)
	begin
		if(~SSEL_active)
			bitcnt <= 3'b000;
		else
		if(SCK_risingedge)
		begin
			bitcnt <= bitcnt + 3'b001;
			// implement a shift-left register (since we receive the data MSB first)
			byte_data_received <= {byte_data_received[6:0], MOSI_data};
		end
	end
	
	always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);
	// we use the LSB of the data received to control an LED
	reg LED;
	
	always @(posedge clk) if(byte_received) LED <= byte_data_received[0];
/* END OF RECEIVE */


/* TRANSMIT */
	reg [7:0] byte_data_sent;
	reg [7:0] cnt;
	
	always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

	always @(posedge clk)
	if(SSEL_active)
	begin
	
		if(SSEL_startmessage)
			byte_data_sent <= cnt;  // first byte sent in a message is the message count
			
		else if(SCK_fallingedge)
		begin
		
			if(bitcnt==3'b000)
				byte_data_sent <= 8'h00;  // after that, we send 0s
			else
				byte_data_sent <= {byte_data_sent[6:0], 1'b0};
				
		end
	end
	
	assign MISO = byte_data_sent[7];  // send MSB first
	// we assume that there is only one slave on the SPI bus
	// so we don't bother with a tri-state buffer for MISO
	// otherwise we would need to tri-state MISO when SSEL is inactive
/* END OF TRANSMIT */
endmodule