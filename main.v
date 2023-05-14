`timescale 1ns / 1ps

module main(input clock, input reset, input resetclk, input [1:0] gameMode, input [3:0] userGuess, input ready,
output [7:0] AN, output [6:0] C, output audioOut, output aud_sd);

wire outsignalOne, outsignalTwo, outsignalThree, playSound, val;
wire [2:0] select;
wire [3:0] randValue, userCorrect, userIncorrect;
wire [6:0] ssegIncorrectOne, ssegIncorrectTwo, ssegCorrectOne, ssegCorrectTwo, ssegRandOne, ssegRandTwo;

slowerClkGen stage0(clock, resetclk, outsignalOne, outsignalTwo, outsignalThree);
fsm stage1(clock, reset, userGuess, gameMode, ready, randValue, userCorrect, userIncorrect, playSound, val);
LFSR stage2(outsignalThree, ready, 3'b100, randValue);
threeBitCounter stage3(outsignalTwo, select, 1'b1, 1'b1);
ssegGuess stage4part1(userCorrect, ssegCorrectOne, ssegCorrectTwo);
ssegGuess stage4part2(userIncorrect, ssegIncorrectOne, ssegIncorrectTwo);
ssegRand stage4part3(randValue, gameMode, ssegRandOne, ssegRandTwo);
mux8to1 stage5(select, ssegCorrectOne, ssegCorrectTwo, ssegIncorrectOne, 
ssegIncorrectTwo, 7'b111_1110, 7'b111_1110, ssegRandTwo, ssegRandOne, C, AN, ready);

SongPlayer stage8(clock, 1'b0, playSound, val, audioOut, aud_sd);

endmodule

module fsm(input clock, input reset, input [3:0] userGuess, input [1:0] gameMode, input ready, input [3:0] randValue,
output reg [3:0] userCorrect, output reg [3:0] userIncorrect, output reg playSound, output reg val);

reg[31:0] clk_next, clk_reg;
reg[2:0] state_next, state_reg;
reg[3:0] userCorrectNext, userIncorrectNext, roundsNext, roundsReg;

localparam[2:0] start = 3'b000, hex = 3'b001, octal = 3'b010, dec = 3'b011, done = 3'b100;

always@(posedge clock, posedge reset) begin
    if(reset)begin
        roundsReg <= 0;
        state_reg <= start;
        userCorrect <= 0;
        userIncorrect <= 0;
        clk_reg <= 0;
    end
    else begin
        roundsReg <= roundsNext;
        state_reg <= state_next;
        userCorrect <= userCorrectNext;
        userIncorrect <= userIncorrectNext;
        clk_reg <= clk_next;
    end 
end

always@(*) begin

state_next = state_reg;
userIncorrectNext = userIncorrect;
userCorrectNext = userCorrect;
clk_next = clk_reg;
roundsNext = roundsReg;

case(state_reg)
    start:begin
        playSound = 1'b0;
        if(ready)begin
            if(gameMode == 2'b01)
                state_next = dec;
            else if (gameMode == 2'b10)
                state_next = hex;
            else if (gameMode == 2'b11)
                state_next = octal;
            else
                state_next = dec;
        end
        else 
            state_next = start;
    end
    hex: begin
        if(roundsReg == 10)
            state_next = done;
        else begin
            if(clk_reg == 500_000_000)begin
                clk_next = 0;
                roundsNext = roundsReg + 1;
                if(userGuess == randValue) begin
                    playSound = 1'b1;
                    val = 1'b0;
                    userCorrectNext = userCorrect + 1;
                    end
                else begin
                    userIncorrectNext = userIncorrect + 1;
                    playSound = 1'b1;
                    val = 1'b1;
                    end
            end 
            else 
                clk_next = clk_reg + 1;
        end
    end
    octal: begin
        if(roundsReg == 10)
            state_next = done;
        else begin
            if(clk_reg == 500_000_000)begin
                clk_next = 0;
                roundsNext = roundsReg + 1;
                //if(userGuess[3] == randValue[3] && userGuess[2] == randValue[2] && userGuess[1] == randValue[1] &&
                //userGuess[0] == randValue[0])
                if(userGuess == randValue)begin
                    userCorrectNext = userCorrect + 1;
                    playSound = 1'b1;
                    val = 1'b0;
                    end
                else begin
                    userIncorrectNext = userIncorrect + 1;
                    playSound = 1'b1;
                    val = 1'b1;
                    end
            end 
            else 
                clk_next = clk_reg + 1;
        end
    end
    dec: begin
        if(roundsReg == 10)
            state_next = done;
        else begin
            if(clk_reg == 500_000_000)begin
                clk_next = 0;
                roundsNext = roundsReg + 1;
                if(userGuess == randValue)begin
                    userCorrectNext = userCorrect + 1;
                    playSound = 1'b1;
                    val = 1'b0;
                    end
                else begin
                    userIncorrectNext = userIncorrect + 1;
                    playSound = 1'b1;
                    val = 1'b1;
                    end 
            end 
            else 
                clk_next = clk_reg + 1;
        end
    end
    done: begin
        playSound = 1'b0;
        if(ready == 1'b0)
            state_next = start;
        else
            state_next = done;
    end
    default: 
         state_next = start;
endcase
end

endmodule

module LFSR(input clock, l, input [3:0] R, output reg [3:0] Q);
always@(posedge clock, negedge l)
    if(!l)
        Q <= R;
    else 
        Q <= {Q[2:0],Q[3]^Q[2]};
endmodule

module threeBitCounter(input clk, output reg [2:0] select, input resetn, enable);
always@(posedge clk, negedge resetn)begin
if(!resetn)
    select <= 3'b000;
else if(enable)
    select <= select + 3'b001;
end
endmodule

module mux8to1(input [2:0] select, input [6:0] m1, m2, m3, m4, m5, m6, m7, m8, output reg [6:0] sseg, output reg [7:0] AN, input ready);
always@(select)begin
case(select)
    3'b000:begin
        sseg = m1;
        AN = 8'b0111_1111;
    end
    3'b001:begin
        sseg = m2;
        AN = 8'b1011_1111;
    end
    3'b010:begin
        sseg = m3;
        AN = 8'b1101_1111;
    end
    3'b011:begin
        sseg = m4;
        AN = 8'b1110_1111;
    end
    3'b100:begin
        sseg = m5;
        AN = 8'b1111_0111;
    end
    3'b101:begin
        sseg = m6;
        AN = 8'b1111_1011;
    end
    3'b110:begin
        if(!ready)
            sseg = 7'b000_0001;
        else               
            sseg = m7;
        AN = 8'b1111_1101;
    end
    3'b111:begin
        if(!ready)
            sseg = 7'b000_0001;
        else    
            sseg = m8;
        AN = 8'b1111_1110;
    end
endcase
end
endmodule

module ssegGuess(input [3:0] userGuess, output reg [6:0] ssegFirst, output reg [6:0] ssegSecond);
always@(userGuess)
case(userGuess)
    4'b0000:begin
       ssegFirst = 7'b000_0001; //0
       ssegSecond = 7'b000_0001; //0
    end
    4'b0001:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b100_1111; //1
    end
    4'b0010:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b001_0010; //2
    end
    4'b0011:begin
        ssegFirst = 7'b000_0001; //0 
        ssegSecond = 7'b000_0110; //3
    end
    4'b0100:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b100_1100; //4
    end
    4'b0101:begin
        ssegFirst = 7'b000_0001;  //0 
        ssegSecond = 7'b010_0100; //5
    end
    4'b0110:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b010_0000; //6
    end
    4'b0111:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b000_1111; //7
    end
    4'b1000:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b000_0000; //8
    end
    4'b1001:begin
        ssegFirst = 7'b000_0001; //0
        ssegSecond = 7'b000_1100; //9
    end
    4'b1010:begin
        ssegFirst = 7'b100_1111; //1
        ssegSecond = 7'b000_0001; //0
    end
endcase
endmodule

module ssegRand(input [3:0] randValue, input [1:0] gameMode, output reg [6:0] sseg, output reg [6:0] sseg2);
always@(randValue)begin
    case(randValue)
        4'b0000:begin //0
            sseg = 7'b000_0001;
            sseg2 = 7'b000_0001;
        end
        4'b0001:begin //1
            sseg = 7'b100_1111;
            sseg2 = 7'b000_0001;
        end
        4'b0010:begin //2
            sseg = 7'b001_0010;
            sseg2 = 7'b000_0001;
        end
        4'b0011:begin //3
            sseg = 7'b000_0110;
            sseg2 = 7'b000_0001;
        end
        4'b0100:begin //4
            sseg = 7'b100_1100;
            sseg2 = 7'b000_0001;
        end 
        4'b0101:begin //5
            sseg = 7'b010_0100;
            sseg2 = 7'b000_0001;
        end
        4'b0110:begin //6
            sseg = 7'b010_0000;
            sseg2 = 7'b000_0001;
        end
        4'b0111:begin //7
            sseg = 7'b000_1111;
            sseg2 = 7'b000_0001;
        end
        4'b1000:begin 
            if(gameMode == 2'b11) begin //10
                sseg = 7'b000_0001;
                sseg2 = 7'b100_1111;
            end else begin //8
                sseg = 7'b000_0000;
                sseg2 = 7'b000_0001;
            end
        end
        4'b1001:begin 
            if(gameMode == 2'b11) begin //11
                sseg = 7'b100_1111; 
                sseg2 = 7'b100_1111;
            end else begin //9
                sseg = 7'b000_1100;
                sseg2 = 7'b000_0001;  
            end            
        end 
        4'b1010:begin
            if(gameMode == 2'b11)begin //12
                sseg = 7'b001_0010;
                sseg2 = 7'b100_1111;           
            end else if (gameMode == 2'b10) begin //0A
                sseg = 7'b000_1000;
                sseg2 = 7'b000_0001;
            end else begin //10
                sseg = 7'b000_0001;
                sseg2 = 7'b100_1111;
            end
        end
        4'b1011:begin 
            if(gameMode == 2'b11)begin //13
                sseg = 7'b000_0110;
                sseg2 = 7'b100_1111;            
            end else if (gameMode == 2'b10) begin //0B
                sseg = 7'b110_0000;
                sseg2 = 7'b000_0001;
            end else begin //11
                sseg = 7'b100_1111;
                sseg2 = 7'b100_1111;
            end        
        end
        4'b1100:begin 
            if(gameMode == 2'b11)begin //14
                sseg = 7'b100_1100;
                sseg2 = 7'b100_1111;            
            end else if (gameMode == 2'b10) begin //0C
                sseg = 7'b011_0001;
                sseg2 = 7'b000_0001;
            end else begin //12
                sseg = 7'b001_0010;
                sseg2 = 7'b100_1111;
            end          
        end
        4'b1101:begin 
            if(gameMode == 2'b11)begin //15
                sseg = 7'b010_0100;
                sseg2 = 7'b100_1111;            
            end else if (gameMode == 2'b10) begin //0D
                sseg = 7'b100_0010;
                sseg2 = 7'b000_0001;
            end else begin //13
                sseg = 7'b000_0110;
                sseg2 = 7'b100_1111;
            end           
        end
        4'b1110:begin 
            if(gameMode == 2'b11)begin //16
                sseg = 7'b010_0100;
                sseg2 = 7'b100_1111;            
            end else if (gameMode == 2'b10) begin //0E
                sseg = 7'b100_0010;
                sseg2 = 7'b000_0001;
            end else begin //14
                sseg = 7'b000_0110;
                sseg2 = 7'b100_1111;
            end          
        end
        4'b1111:begin 
            if(gameMode == 2'b11)begin //17
                sseg = 7'b000_1111;
                sseg2 = 7'b100_1111;            
            end else if (gameMode == 2'b10) begin //0F
                sseg = 7'b011_1000;
                sseg2 = 7'b000_0001;
            end else begin //15
                sseg = 7'b010_0100;
                sseg2 = 7'b100_1111;
            end          
        end
        default: begin
            sseg = 7'b000_0001;
            sseg2 = 7'b000_0001;
        end
    endcase
end
endmodule



module slowerClkGen(clk, resetSW, outsignal1, outsignal2, outsignal3);
input clk;   
input resetSW;
output reg outsignal1, outsignal2, outsignal3;
reg [27:0] counter, counter2, counter3;
always @ (posedge clk, posedge resetSW)begin
    if (resetSW) begin
        counter=0;
        counter2=0;
        counter3=0;
        outsignal1=0;
        outsignal2=0;
        outsignal3=0;
    end
    else begin
        counter = counter + 1;
        counter2 = counter2 + 1;
        counter3 = counter3 + 1;
            if (counter == 50_000_000) begin //1 Hz ---> 1 sec 
               outsignal1=~outsignal1;
               counter=0;
            end
            if (counter2 == 125_000) begin //400 Hz ---> 1/400 sec
                outsignal2=~outsignal2;
                counter2=0;
            end
            if (counter3 == 250_000_000) begin // 1/5hz --> 5 sec
                outsignal3=~outsignal3;
                counter3=0;
            end 
   end
end
endmodule

module MusicSheet(input [9:0] number, 
output reg [19:0] note,//what is the max frequency  
output reg [4:0] duration, input val);
parameter   QUARTER = 5'b00010; 
parameter HALF = 5'b00100;
parameter ONE = 2* HALF;
parameter TWO = 2* ONE;
parameter FOUR = 2* TWO;
parameter A4=113598.8,B4=101198,G4S=120357.9,E4=151662.6,C4=191109.6,C4S=180377.1,SP=1;
parameter D4=170247.4, C5S=90150.88, D5=85088.14, E5=75799.63, D5S=80309.71, C5=95514.86;
always @ (number) begin
case(number) 
0: begin note = SP; duration = HALF; end
1: begin note = SP; duration = HALF; end
2: begin note = SP; duration = HALF; end
3: begin note = SP; duration = HALF; end
4: begin note = SP; duration = HALF; end
5: begin note = SP; duration = HALF; end
6: begin note = SP; duration = HALF; end
7: begin note = SP; duration = HALF; end
8: begin note = SP; duration = HALF; end
9: begin if(val) note = A4; else note = B4; duration = QUARTER; end
10: begin if (val) note = A4; else note = E5; duration = QUARTER; end
default: begin note = SP; duration = FOUR; end
endcase
end
endmodule



module SongPlayer(input clock, input reset, input playSound, input val, output reg 
audioOut, output wire aud_sd);
reg [19:0] counter;
reg [31:0] time1, noteTime;
reg [9:0] msec, number; //millisecond counter, and sequence number of musical note.
wire [4:0] note, duration;
wire [19:0] notePeriod;
parameter clockFrequency = 100_000_000; 
assign aud_sd = 1'b1;

MusicSheet mysong(number, notePeriod, duration, val);

always @ (posedge clock, posedge reset) begin
if(reset | ~playSound) begin 
          counter <=0;  
          time1<=0;  
          number <=0;  
          audioOut <=1;
end
else begin
counter <= counter + 1; 
time1<= time1+1;
    if( counter >= notePeriod) begin
        counter <=0;  
        audioOut <= ~audioOut ; 
        end //toggle audio output 
    if( time1 >= noteTime) begin
    time1 <=0;  
    number <= number + 1; 
    end  //play next note
    if(number == 10) begin 
    number <=0; // Make the number reset at the end of the song
    end
end
end
              
always @(duration) 
noteTime = duration * clockFrequency/8;
       //number of   FPGA clock periods in one note.
endmodule


