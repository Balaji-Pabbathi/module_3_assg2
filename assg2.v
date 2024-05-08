module tricky(
  	
  	input clk,
    input en,
  	
  input [15:0] config_input,
  
  input [7:0]  s_axis_data,
  input s_axis_valid,
  input s_axis_last,
  
  output s_axis_ready,
  
  
  input m_axis_ready,
  
  output [7:0] m_axis_data,
  output m_axis_valid,
  output m_axis_last,
  
  output [7:0] small_fifo_data_out,
  
  output full,
  output empty
  
);
  

  
  
  //rd_en1 delay and wr_en1 delay
  
 
  reg [1:0] a;
  reg [1:0] b;
          	
  
  

    	
  
  
  
  
  //wire [7:0] small_fifo_data_out;
  
  //fsm 1 parameters and memory for storing k bytes
  
   
  
  
  reg [7:0] count;
  
 // reg [8:0] wr_ptr;
  
  reg wr_en1;
  
 // wire wr_en1_delay;
  
  parameter IDLE=2'b00,DISCARD=2'b01,STORE=2'b10;
  
  reg [1:0] pss,nss;
  
  //fsm2 parameters
  
  reg present_state,next_state;
  
  parameter IDL=1'b0,ADD=1'b1;
  
  reg rd_en1;
  
  wire rd_en1_delay;
  
  reg [7:0] counter;
  
  
  
  
  
   always@(posedge clk)
    	begin
          a<={rd_en1,a[1]};
         // b<={wr_en1,b[1]};
        end
  
  assign rd_en1_delay=a[0];
 // assign wr_en1_delay=b[0];
  
  
  
  
  
  
  
  //getting seperate length and k value
  
  reg [7:0] k;
  reg [7:0] len;
  
  assign {len,k}=config_input;
  
  //making interface for  main fifo for input and output 
  
  reg [8:0] data_in;
  
  wire  [8:0] data_out;
  
  always@(*)
    	begin
          if(s_axis_valid && s_axis_ready)
            data_in={s_axis_last,s_axis_data};
          else
            data_in=0;
        end
  
  assign m_axis_last=data_out[8];
  
  assign m_axis_data=(m_axis_ready)?data_out+small_fifo_data_out:0;
  
  
  fifo uut(clk,en,m_axis_ready,s_axis_valid && s_axis_ready,data_in,data_out,full,empty);
  
  //small fifo insatantion
  
  small_fifo dut(clk,en,rd_en1_delay,wr_en1,s_axis_data,small_fifo_data_out);
  
  
  //fsm for wr_en logic for last k bytes of the packet
  
  always@(posedge clk)
    	begin
          if(~en)
            	pss<=IDLE;
          else
            	pss<=nss;
        end
  
  
  always@(*)
    	begin
          case(pss)
         		IDLE: begin
                  if(s_axis_valid && s_axis_ready)
                    	nss=DISCARD;
                  else 
                    	nss=IDLE;
                end
            	DISCARD: begin
                  if(count<len-k)
                    nss=DISCARD;
                  else
                   	nss=STORE;
                end
            	STORE:begin
                  if(s_axis_last==1)
                    	nss=IDLE;
                  else
                    	nss=STORE;
                end
            default : nss=IDLE;
          endcase
        end
  
  always@(posedge clk)
    	begin
           if(pss==STORE && s_axis_last==1)
            	count<=0;
          else if(pss ==IDLE && (~s_axis_valid | ~s_axis_ready))
            	count<=0;
          else if(pss==IDLE && s_axis_valid && s_axis_ready)
            	count<=count+1;
          else if(pss==IDLE)
            	count<=0;
          else
            	count<=count+1;
        end  
  
  always@(*)
    	begin
          if(pss==DISCARD && count==len-k)
            	wr_en1=1;
          else if(pss==STORE && s_axis_last)
            	wr_en1=1;
          else if(pss==STORE)
            	wr_en1=1;
          else 
            	wr_en1=0;
        end   
          
  
  
 
  
  
 /* always@(posedge clk)
    	begin
          if(~en)
            	wr_ptr<=0;
          else if(wr_en1 && s_axis_valid && s_axis_ready)
            	wr_ptr<=wr_ptr+1;
          else 
            	wr_ptr<=wr_ptr;
        end
  */
  
  //fsm for rd_en logic
	
  always@(posedge clk)
    	begin 
          if(~en)
            	present_state<=IDL;
          else 
            	present_state=next_state;
        end
  
  always@(*)
    	begin
          case(present_state)
            	IDL: begin
                  if(s_axis_last)
                   		next_state<=ADD;
                 else
                   	next_state<=IDL;
                end
            	ADD:begin
                  if(counter<k)
                    	next_state<=ADD;
                  else
                    	next_state<=IDL;
                end
          endcase
        end
  
  always@(posedge clk)
    	begin
          if(present_state==IDL && s_axis_last)
            	counter<=counter+1;
          else if(present_state==ADD)
            	counter<=counter+1;
          else if(present_state==ADD && counter >=k)
            	counter<=0;
          else if(present_state==IDL)
            	counter<=0;
          else 
            	counter<=counter;
        end
  
  always@(*)
    	begin
         if((present_state==ADD && counter<(k))|(present_state==IDL && s_axis_last))
      	rd_en1=1;
  	else
      	rd_en1=0;
  
        end
  
                    	
  
  
  
  assign s_axis_ready=m_axis_ready;
  
  
  
  
  
  
  
  
  
  
  
endmodule  
  	








module fifo(
    input clk,
    input en,
    input read_n,
    input write_n,
    
    input [8:0] datain,
    
    output reg [8:0] dataout,
  
    output full,
    output empty

    );
    
    
    
    reg [8:0] mem[2047:0];
    
    reg [11:0] rd_ptr;
    reg [11:0] wr_ptr;
    
    always@(posedge clk)
        begin
            if(~en)
                begin
                    wr_ptr<=0;
                    rd_ptr<=0;
                 end
            else if((write_n &&~full) && (read_n && ~empty))
                begin
                    wr_ptr<=wr_ptr+1;
                    rd_ptr<=rd_ptr+1;
                 end
           else if(write_n && ~full)
                begin
                    wr_ptr<=wr_ptr+1;
                    rd_ptr<=rd_ptr;
                 end
           else if(read_n && ~empty)
                begin
                    wr_ptr<=wr_ptr;
                    rd_ptr<=rd_ptr+1;
                end
           else 
                begin
                    wr_ptr<=wr_ptr;
                    rd_ptr<=rd_ptr;
                end
                  
      end      
                         
                                   
    
    
    
    always@(posedge clk)
        begin
            if(en)
                begin
                    if(write_n && ~full)
                        mem[wr_ptr]<=datain;
                end
            
        end
         
    always@(posedge clk)
        begin
            if(en)
                begin   
                    if(read_n && ~empty )
                         dataout<= mem[rd_ptr];
                end
        
        end  
  
  
  assign full=(rd_ptr == {~wr_ptr[11],wr_ptr[10:0]});
  
  assign empty=(wr_ptr==rd_ptr);
        
        
          
 endmodule


module small_fifo(
    input clk,
    input en,
    input read_n,
    input write_n,
    
  input [7:0] datain,
    
  output reg [7:0] dataout
 

    );
    
    
    
  reg [7:0] mem[255:0];
    
  	reg [7:0] rd_ptr;
    reg [7:0] wr_ptr;
    
    always@(posedge clk)
        begin
            if(~en)
                begin
                    wr_ptr<=0;
                    rd_ptr<=0;
                 end
            else if((write_n) && (read_n))
                begin
                    wr_ptr<=wr_ptr+1;
                    rd_ptr<=rd_ptr+1;
                 end
          else if(write_n)
                begin
                    wr_ptr<=wr_ptr+1;
                    rd_ptr<=rd_ptr;
                 end
           else if(read_n )
                begin
                    wr_ptr<=wr_ptr;
                    rd_ptr<=rd_ptr+1;
                end
           else 
                begin
                    wr_ptr<=wr_ptr;
                    rd_ptr<=rd_ptr;
                end
                  
      end      
                         
                                   
    
    
    
    always@(posedge clk)
        begin
            if(en)
                begin
                    if(write_n)
                        mem[wr_ptr]<=datain;
                end
            
        end
         
    always@(posedge clk)
        begin
            if(en)
                begin   
                    if(read_n)
                         dataout<= mem[rd_ptr];
                    else 
                      	dataout<=0;
                end
        
        end  
  
  
  
        
          
 endmodule


//test bench

// Code your testbench here
// or browse Examples
module tb;
  
  reg clk;
  
  reg en;
  
  reg [15:0] config_input;
  
  reg s_axis_valid;
  
  wire s_axis_ready;
  
  reg s_axis_last;
  
  reg [7:0] s_axis_data;
  
  reg m_axis_ready;
  
  wire [7:0] m_axis_data;
  
  wire m_axis_valid;
  
  wire m_axis_last;
  
  wire [7:0] small_fifo_data_out;
  
  wire full;
  
  wire empty;
  
  tricky uuut(clk,en,config_input,s_axis_data,s_axis_valid,s_axis_last,s_axis_ready,m_axis_ready,m_axis_data,m_axis_valid,m_axis_last,small_fifo_data_out,full,empty);
  
  initial begin
    clk=0;
    forever #1 clk=~clk;
  end
  
  initial begin
    config_input[7:0]=5;
    config_input[15:8]=10;
    en=0;
    #10;
    en=1;
    m_axis_ready=1;
    repeat(9)
      	begin
          @(posedge clk)
          s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=0;
        end
    @(posedge clk)
    		s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=1;
     repeat(9)
      	begin
          @(posedge clk)
          s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=0;
        end
    @(posedge clk)
    		s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=1;
     repeat(9)
      	begin
          @(posedge clk)
          s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=0;
        end
    @(posedge clk)
    		s_axis_data<={$random}%10;
            s_axis_valid<=1;
            s_axis_last<=1;
    
     @(posedge clk)
          	s_axis_data<=0;
            s_axis_valid<=0;
            s_axis_last<=0;
    		m_axis_ready=0;
    
    
    
    
    
  end
  
  initial begin:bala
  
    	
		integer i;
      #500;
    for(i=0;i<256;i++)
      	begin
          $display("mem[%d]=%h",i,uuut.dut.mem[i]);
        end
    
  end  
  
  
   initial begin:balaaa
  
    	
	integer i;
      #500;
     for(i=0;i<100;i++)
      	begin
          $display("mem[%d]=%h",i,uuut.uut.mem[i][7:0]);
        end
    $finish;
  end 
  
  initial begin
    $dumpfile("a.vcd");
    $dumpvars;
  end  
  
  
  
  
  initial begin
    $dumpfile("a.vcd");
    $dumpvars;
  end  
  
  
  
endmodule
  
    

