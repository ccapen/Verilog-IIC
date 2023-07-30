
//`define TEST_RESOURCE_USAGE
//define it to get the real resource usage
//comment it to run the eeprom r/w test

module top(
	input		I_inclk,
	input		I_key_rstn,

`ifdef TEST_RESOURCE_USAGE

	input	[6:0]	I_device,
	input	[7:0]	I_data,
	input	[15:0]	I_addr,
	input	[5:0]	I_num,
	
`endif

	output		O_scl,
	inout		IO_sda
);


	wire W_mclk;
	wire W_locked;
	

	alt_pll pll_u(
		.areset		(!I_key_rstn),
		.inclk0		(I_inclk),
		.c0			(W_mclk),	//100MHz
		.locked		(W_locked)
	);
	
	//divide W_mclk to 100kHz IIC clock
	reg [7:0] R_cnt;
	wire W_edge;
	reg R_clk_400k;
	
	always@(posedge W_mclk or negedge W_locked)
	if(!W_locked) R_cnt <= 8'b0;
	else if(W_edge) R_cnt <= 8'b0;
	else R_cnt <= R_cnt + 1'b1;
	
	assign W_edge = (R_cnt == 8'd124);
	
	always@(posedge W_mclk or negedge W_locked)
	if(!W_locked) R_clk_400k <= 1'b0;
	else if(W_edge) R_clk_400k <= !R_clk_400k;
	else R_clk_400k <= R_clk_400k;
	
	//generate write-read cycle
	reg [11:0] R_cnt_work;
	reg R_rw;
	reg R_start;
	
	always@(posedge R_clk_400k or negedge W_locked)
	if(!W_locked) R_cnt_work <= 12'b0;
	else R_cnt_work <= R_cnt_work + 1'b1;
	
	always@(posedge R_clk_400k or negedge W_locked)
	if(!W_locked) R_rw <= 1'b0;
	else R_rw <= (R_cnt_work > 12'h7f);
	
	always@(posedge R_clk_400k or negedge W_locked)
	if(!W_locked) R_start <= 1'b0;
	else R_start <= (R_cnt_work == 12'h01) || (R_cnt_work == 12'h801);
	
	
	iic_rw #(
		.ADDRWIDTH		(16),
		.NUMWIDTH		(6)
	) iic_rw_u(
		.I_clk			(R_clk_400k),
		.I_rstn			(W_locked),
		
`ifdef TEST_RESOURCE_USAGE

		.I_device		(I_device),
		.I_addr			(I_addr),
		.I_num			(I_num),
		.I_databyte		(I_data),
		
`else

		.I_device		(7'b1010_000),
		.I_addr			(16'h0000),
		.I_num			(6'd4),
		.I_databyte		(8'h4c),
		
`endif
	
		.I_rw			(R_rw),
		.I_start		(R_start),
		.O_busy			(),
		.O_nextdata		(),
		.O_databyte		(),
		.O_datavalid	(),
		.O_error		(),
		
		.I_next			(W_next),
		.I_data			(W_data_recv),
		.O_dc			(W_dc),
		.O_rw			(W_rw),
		.O_data			(W_data)
	);

	iic_master iic_master_u(
		.I_clk			(R_clk_400k),
		.I_rstn			(W_locked),
		
		.I_dc			(W_dc),
		.I_rw			(W_rw),
		.I_data			(W_data),
		.O_data			(W_data_recv),
		.O_next			(W_next),
		
		.O_scl			(W_scl),
		.I_sda			(W_sdain),
		.O_sda			(W_sdaout)
	);
	
	assign IO_sda = W_sdaout ? 1'bz : 1'b0;
	assign O_scl = W_scl ? 1'bz : 1'b0;
	assign W_sdain = IO_sda;


endmodule
