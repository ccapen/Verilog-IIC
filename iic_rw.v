module iic_rw #(
	parameter	ADDRWIDTH	= 16,	//address width of data, must be 8*n
	parameter	NUMWIDTH	= 2		//number width of data in a r/w transfer
) (
	input						I_clk,
	input						I_rstn,
	
	input	[6:0]				I_device,
	input						I_rw,
	input	[ADDRWIDTH-1:0]		I_addr,
	input	[NUMWIDTH-1:0]		I_num,
	input						I_start,
	output						O_busy,
	input	[7:0]				I_databyte,
	output						O_nextdata,
	output	[7:0]				O_databyte,
	output						O_datavalid,
	output						O_error,
	
	input						I_next,
	input						I_data,
	output						O_dc,
	output						O_rw,
	output						O_data
);

	localparam ADDRBYTENUM	= ADDRWIDTH/8;
	localparam ADDRNUMWIDTH	= $clog2(ADDRBYTENUM);
	
	localparam IDLE			= 5'b00001;
	localparam DEVICE		= 5'b00010;
	localparam ADDR			= 5'b00100;
	localparam DEVICE_RD	= 5'b01000;
	localparam DATA			= 5'b10000;
	
	localparam IDLE_IND			= 5'd0;
	localparam DEVICE_IND		= 5'd1;
	localparam ADDR_IND			= 5'd2;
	localparam DEVICE_RD_IND	= 5'd3;
	localparam DATA_IND			= 5'd4;

	reg [7:0] R_device_rw;
	reg [ADDRWIDTH-1:0] R_addr;
	reg [NUMWIDTH-1:0] R_num;
	
	reg [ADDRNUMWIDTH-1:0] R_addrnum;
	
	reg [4:0] R_state;
	
	reg [3:0] R_cnt;
	
	wire W_cnt_end;
	wire W_long_end;
	wire W_byte_end;
	wire W_addr_end;
	
	reg R_dc;
	reg R_rw;
	reg R_next;
	reg [9:0] R_data;
	
	reg R_nextdata;
	reg R_readdata;
	reg [7:0] R_databyte;
	reg [2:0] R_cnt_read;
	reg R_datavalid;
	reg R_error;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_state <= IDLE;
	else if(R_error) R_state <= IDLE;
	else case(R_state)
		IDLE:if(I_start) R_state <= DEVICE;
				else R_state <= IDLE;
		DEVICE:if(W_long_end) R_state <= ADDR;
				else R_state <= DEVICE;
		ADDR:if(W_addr_end) R_state <= (R_device_rw[0] ? DEVICE_RD : DATA);
				else R_state <= ADDR;
		DEVICE_RD:if(W_long_end) R_state <= DATA;
				else R_state <= DEVICE_RD;
		DATA:if(W_long_end) R_state <=IDLE;
				else R_state <= DATA;
		default:R_state <= IDLE;
	endcase
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_cnt <= 4'b0;
	else if(W_cnt_end) R_cnt <= 4'b0;
	else if(I_next && ({R_dc,R_rw,R_data} != 3'b000)) R_cnt <= R_cnt + 1'b1;
	else R_cnt <= R_cnt;
	
	assign W_cnt_end = R_state[IDLE_IND] || W_long_end || (R_state[ADDR_IND] && W_byte_end)
						|| (R_state[DATA_IND] && W_byte_end && (R_num != {NUMWIDTH{1'b0}}));
	assign W_long_end = (R_cnt == 4'd9) && I_next;
	assign W_byte_end = (R_cnt == 4'd8) && I_next;
	assign W_addr_end = (R_addrnum == {ADDRNUMWIDTH{1'b0}}) && W_byte_end;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_addrnum <= {ADDRNUMWIDTH{1'b0}};
	else if(I_start) R_addrnum <= ADDRBYTENUM - 1'b1;
	else if(R_state[ADDR_IND] && W_byte_end) R_addrnum <= R_addrnum - 1'b1;
	else R_addrnum <= R_addrnum;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_num <= {NUMWIDTH{1'b0}};
	else if(I_start) R_num <= I_num - 1'b1;
	else if(R_state[DATA_IND] && W_byte_end) R_num <= R_num - 1'b1;
	else R_num <= R_num;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_addr <= {ADDRWIDTH{1'b0}};
	else if(I_start) R_addr <= I_addr;
	else if(R_state[ADDR_IND] && W_byte_end) R_addr <= {R_addr[ADDRWIDTH-9:0],8'b0};
	else R_addr <= R_addr;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_device_rw <= 8'b0;
	else if(I_start) R_device_rw <= {I_device,I_rw};
	else R_device_rw <= R_device_rw;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_dc <= 1'b0;
	else case(R_state)
		DEVICE,DEVICE_RD:if(R_cnt == 4'b0) R_dc <= 1'b0;
				else R_dc <= 1'b1;
		ADDR:R_dc <= 1'b1;
		DATA:if(R_cnt == 4'd9) R_dc <= 1'b0;
				else R_dc <= 1'b1;
		default:R_dc <= 1'b0;
	endcase
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_rw <= 1'b0;
	else case(R_state)
		DEVICE:if(R_cnt == 4'd9) R_rw <= 1'b1;
				else R_rw <= 1'b0;
		ADDR:if(R_cnt == 4'd8) R_rw <= 1'b1;
				else R_rw <= 1'b0;
		DEVICE_RD:if((R_cnt == 4'd0) || (R_cnt == 4'd9)) R_rw <= 1'b1;
				else R_rw <= 1'b0;
		DATA:if(R_cnt == 4'd9) R_rw <= 1'b1;
				else if(R_cnt == 4'd8) R_rw <= !R_device_rw[0];
				else R_rw <= R_device_rw[0];
		default:R_rw <= 1'b0;
	endcase
	
	wire W_nack = (R_num == {NUMWIDTH{1'b0}});
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_next <= 1'b1;
	else R_next <= I_next;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_data <= 10'b0;
	else if(!R_next) R_data <= R_data;
	else case(R_state)
		DEVICE:if(R_cnt == 4'b0) R_data <= {1'b1,R_device_rw[7:1],2'b01};
				else R_data <= {R_data[8:0],1'b1};
		ADDR:if(R_cnt == 4'b0) R_data <= {R_addr[ADDRWIDTH-1:ADDRWIDTH-8],2'b11};
				else R_data <= {R_data[8:0],1'b1};
		DEVICE_RD:if(R_cnt == 4'b0) R_data <= {1'b1,R_device_rw[7:1],2'b11};
				else R_data <= {R_data[8:0],1'b1};
		DATA:if(R_cnt == 4'b0) R_data <= {I_databyte,W_nack,1'b0};
				else R_data <= {R_data[8:0],1'b1};
		default:R_data <= 10'b0;
	endcase
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_nextdata <= 1'b0;
	else if(R_state[DATA_IND] && (R_cnt == 4'b0) && I_next && (!R_device_rw[0])) R_nextdata <= 1'b1;
	else R_nextdata <= 1'b0;
	
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_readdata <= 1'b0;
	else if(I_next) R_readdata <= (R_dc && R_rw);
	else R_readdata <= R_readdata;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_databyte <= 8'b0;
	else if(R_readdata && I_next && (R_cnt != 4'b0)) R_databyte <= {R_databyte[6:0],I_data};
	else R_databyte <= R_databyte;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_cnt_read <= 3'b0;
	else if((!R_state[DATA_IND]) || (!R_device_rw[0])) R_cnt_read <= 3'b0;
	else if(R_readdata && I_next && (R_cnt != 4'b0)) R_cnt_read <= R_cnt_read + 1'b1;
	else R_cnt_read <= R_cnt_read;
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_datavalid <= 1'b0;
	else R_datavalid <= (R_cnt_read == 3'd7) && (R_readdata && I_next && (R_cnt != 4'b0));
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_error <= 1'b0;
	else if(I_start) R_error <= 1'b0;
	else if(R_readdata && I_next && (R_cnt == 4'b0)) R_error <= I_data;
	else R_error <= R_error;
	
	
	assign O_busy = (!R_state[IDLE_IND]);
	assign O_nextdata = R_nextdata;
	assign O_databyte = R_databyte;
	assign O_datavalid = R_datavalid;
	assign O_error = R_error;
	
	assign O_dc = R_dc;
	assign O_rw = R_rw;
	assign O_data = R_data[9];
	
	

endmodule
	