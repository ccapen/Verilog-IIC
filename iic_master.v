/*
	IIC主机驱动模块
	不进行仲裁处理
	使用dc(data/cmd)，rw(read/write)，data(1/0)控制模块动作
	真值表如下：
	action	DC	RW	DATA	time
	NOP		0	0	0		1
	S		0	0	1		3
	P		0	1	0		3
	SR		0	1	1		4
	SEND0	1	0	0		4
	SEND1	1	0	1		4
	RECV	1	1	X		4
*/

module iic_master(
	input			I_clk,
	input			I_rstn,
	
	input			I_dc,
	input			I_rw,
	input			I_data,
	output			O_data,
	output			O_next,
		
	output			O_scl,
	input			I_sda,
	output			O_sda
);

	wire [2:0] W_cmd;
	
	reg R_next;
	
	reg [1:0] R_cnt;
	wire W_idle;
	
	reg [3:0] R_scl;
	reg [3:0] R_sda;
	reg R_data;
	
	
	assign W_cmd = {I_dc,I_rw,I_data};
	
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_next <= 1'b1;
	else if((R_cnt == 2'b1) || ((R_cnt == 2'b0) && (W_cmd == 3'b000))) R_next <= 1'b1;
	else R_next <= 1'b0;
	
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_cnt <= 2'b0;
	else if(!W_idle) R_cnt <= R_cnt - 1'b1;
	else if(W_cmd > 3'd2) R_cnt <= 2'd3;
	else if(W_cmd != 3'd0) R_cnt <= 2'd2;
	else R_cnt <= 2'd0;
	
	assign W_idle = (R_cnt == 2'b0);
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_scl <= 4'b1111;
	else if(!W_idle) R_scl <= {R_scl[2:0],R_scl[3]};
	else case(W_cmd)
		3'b000:R_scl <= R_scl;//NOP
		3'b001:R_scl <= 4'b1100;//S
		default:R_scl <= 4'b0110;
	endcase
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_sda <= 4'b1111;
	else if(!W_idle) R_sda <= {R_sda[2:0],R_sda[3]};
	else case(W_cmd)
		3'b000:R_sda <= R_sda;//NOP
		3'b001:R_sda <= 4'b1001;//S
		3'b010:R_sda <= 4'b0011;//P
		3'b011:R_sda <= 4'b1100;//SR
		3'b100:R_sda <= 4'b0000;//SEND0
		default:R_sda <= 4'b1111;
	endcase
	
	always@(posedge I_clk or negedge I_rstn)
	if(!I_rstn) R_data <= 1'b0;
	else if(R_cnt == 2'd2) R_data <= I_sda;
	else R_data <= R_data;
	
	
	assign O_scl = R_scl[3];
	assign O_sda = R_sda[3];
	
	assign O_data = R_data;
	assign O_next = R_next;


endmodule
