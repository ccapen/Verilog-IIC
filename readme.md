# 使用Verilog HDL编写的IIC主机读写模块（EEPROM协议） #
## 一、特性 ##
1. 使用DC、RW、DATA控制总线动作波形，所有的总线动作波形完全相同，如下所示,其中SDA、SCL两行的“1”代表输出高电平，“0”代表输出低电平。
	<table>
	<tr>
		<th>命令</th>
	    <th>NOP</th>
		<th>START</th>
		<th>STOP</th>
		<th>RESTART</th>
		<th>WRITE0</th>
		<th>WRITE1</th>
		<th>READ</th>
	</tr>
	<tr>
		<td>SDA</td>
		<td>KEEP</td>
		<td>100</td>
		<td>001</td>
		<td>1100</td>
		<td>0000</td>
		<td>1111</td>
		<td>1111</td>
	</tr>
	<tr>
		<td>SCL</td>
		<td>KEEP</td>
		<td>110</td>
		<td>011</td>
		<td>0110</td>
		<td>0110</td>
		<td>0110</td>
		<td>0110</td>
	</tr>
	<tr>
		<td>时间</td>
		<td>1</td>
		<td>3</td>
		<td>3</td>
		<td>4</td>
		<td>4</td>
		<td>4</td>
		<td>4</td>
	</tr>
	<tr>
		<td>DC</td>
		<td>0</td>
		<td>0</td>
		<td>0</td>
		<td>0</td>
		<td>1</td>
		<td>1</td>
		<td>1</td>
	</tr>
	<tr>
		<td>RW</td>
		<td>0</td>
		<td>0</td>
		<td>1</td>
		<td>1</td>
		<td>0</td>
		<td>0</td>
		<td>1</td>
	</tr>
	<tr>
		<td>DATA</td>
		<td>0</td>
		<td>1</td>
		<td>0</td>
		<td>1</td>
		<td>0</td>
		<td>1</td>
		<td>X</td>
	</tr>
	</table>
2. 使用输入时钟直接驱动模块工作，产生总线波形。因此总线SCL频率固定为输入时钟的四分之一。
3. 在iic\_rw.v文件中完成EEPROM的读写时序逻辑，结合iic\_master.v文件中的IIC主机模块完成对EEPROM的读写功能。<br>
	写数据：起始条件 -> 写设备地址 -> 写数据地址 -> 写数据 -> 停止条件<br>
	读数据：起始条件 -> 写设备地址 -> 写数据地址 -> 重复起始条件 -> 写设备地址 -> 读数据 -> 停止条件
4. 参数化数据地址宽度且必须为8的整数倍，不足补0。参数化读写数据个数位宽。
5. 设备地址宽度固定为7bit，不支持10bit地址。读写数据宽度固定为8bit。
6. 设备地址、数据地址、读写数据个数可在运行过程中修改。每次模块启动一次读写操作时将保存相关参数，并在下一次启动读写操作时重新接收相关参数。
7. 资源消耗
	<table>
	<tr>
		<th>模块</th>
		<th>资源消耗</th>
	</tr>
	<tr>
		<td>iic_master</td>
		<td>21 LCC + 12 LCR</td>
	</tr>
	<tr>
		<td>iic_rw</td>
		<td>120 LCC + 55 LCR</td>
	</tr>
	</table>
## 二、注意事项 ##
1. 考虑到IIC时序要求低，顶层模块直接使用一个计数器分频产生400kHz时钟驱动IIC相关模块，并循环启动IIC写和读完成对模块的板级验证。
2. O\_busy信号在整个数据读写流程中保持为高，用于指示模块工作状态，且该信号为高时模块忽略启动信号和参数配置的变化。
3. I\_databyte和O\_nextdata需连接外部的showahead模式下的FIFO，模块每次O\_nextdata拉高的前一个时钟周期接收I\_databyte的数据，因此O\_nextdata为高时I\_databyte需切换至下一个数据。若每次仅写入一个数据，则可以忽略O\_nextdata信号。
4. 每接收到一个数据，O\_datavalid将拉高一个时钟周期，同时可在O\_databyte端口获取接收到的数据。
5. IIC总线无数据校验功能，O\_error仅对所有IIC写操作的应答信号进行响应。若从机返回ACK，O\_error保持为低，读写流程正常进行；若从机返回NAK，O\_error将置为高电平并保持到下一次应答判断，同时读写流程停止，模块进入空闲状态。