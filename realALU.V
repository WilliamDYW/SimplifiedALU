module alu(i_datain,gr1,gr2,c,branch,load,store);

output signed[31:0] c;
output branch, load, store;
input [31:0] i_datain;
input signed[31:0] gr1,gr2;

reg unsigned [5:0] opcode, func;
reg[15:0] crudeimm;
reg zf, nf, vf, bc, lc, sc, SignExt,ALUsrcA,ALUsrcB,unsign;
reg signed [31:0] reg_A, reg_B, reg_C;
reg[31:0] hi, lo, imm;
reg[63:0] mul;
reg[3:0] ALUop;
reg[1:0] FlagEn;


parameter gr0 = 16'h0000;
parameter grm = 16'hFFFF;

always @(i_datain,gr1,gr2)
begin

    opcode = i_datain[31:26];
    func = i_datain[5:0];
    sc = (opcode == 6'b101011) ? 1'b1 : 1'b0;
    lc = (opcode == 6'b100011) ? 1'b1 : 1'b0;
    bc = 1'b0;
    if(opcode!=6'b000000)
    begin
        crudeimm = i_datain[15:0];
        if (opcode[5]==1'b1) ALUop=4'b0000;
        else
        begin
            ALUop[0]=(opcode[5:1]==5'b00010||(opcode[3]==1'b1&&opcode[0]==1'b0&&opcode[2]|opcode[1]==1'b1))?1'b1:1'b0;
            ALUop[1]=(opcode==6'b001011||opcode==6'b001110)?1'b1:1'b0;
            ALUop[2]=(opcode[3:2]==2'b11)?1'b1:1'b0;
            ALUop[3]=(opcode==6'b001011)?1'b1:1'b0;
        end
        SignExt=(opcode[5]==1'b1||opcode==6'b001010||opcode[5:3]==3'b000)?1'b1:1'b0;
        ALUsrcA=1'b0;
        ALUsrcB=(opcode[5:3]!=3'b000)?1'b1:1'b0;
        FlagEn[0]=(opcode==6'b000100||opcode==6'b001010)?1'b1:1'b0;
        FlagEn[1]=(opcode[5:1]==5'b00010)?1'b1:1'b0;
        unsign=(opcode==6'b001001)?1'b1:1'b0;
    end
    else
    begin
        ALUop[0]=((func[1]==1'b1&&func!=6'b100111&&func!=6'b101011)||func==6'b100100)?1'b1:1'b0;
        ALUop[1]=(func[4:3]==2'b11||func[5:1]==5'b10011||func==6'b101011)?1'b1:1'b0;
        ALUop[2]=(func[5:2]==4'b1001)?1'b1:1'b0;
        ALUop[3]=(func[5:3]==4'b000||func==6'b101011)?1'b1:1'b0;
        SignExt=1'b0;
        ALUsrcA=(func[5:2]==4'b0000)?1'b1:1'b0;
        ALUsrcB=1'b0;
        FlagEn[1]=1'b0;
        FlagEn[0]=(func==6'b101010)?1'b1:1'b0;
        unsign=(func==6'b000010||func==6'b000110||func==6'b011001||func==6'b011011||func==6'b100001||func==6'b100011)?1:0;
    end

    imm[31:16]=(SignExt&crudeimm[15])?grm:gr0;
    imm[15:0]=crudeimm;
    reg_A=(ALUsrcA==1'b0)?gr1:32'h0000_0000+i_datain[10:6];//rs
    reg_B=(ALUsrcB==1'b0)?gr2:imm;//rt
    case(ALUop)
        4'b0000:
        begin
        reg_C = (FlagEn[1]==1'b1||opcode[5]==1'b1)? reg_A + (reg_B<<2) : reg_A + reg_B;
        vf=((reg_A>0 && reg_B>0 && reg_C<0) || (reg_A<0 && reg_B<0 && reg_C>0))?~unsign:1'b0;
        end
        4'b0001:
        begin
        reg_C = reg_A - reg_B;
        vf=((reg_A>0 && reg_B<0 && reg_C<0) || (reg_A<0 && reg_B>0 && reg_C>0))?~unsign:1'b0;
        end
        4'b0010:
        begin
        mul = (unsign)? $unsigned(reg_A) * $unsigned(reg_B) : (reg_A[31]*64'hFFFF_FFFF_0000_0000+(reg_A)) * (reg_B[31]*64'hFFFF_FFFF_0000_0000+(reg_B));
        hi = mul[63:32];
        lo = mul[31:0];
        end
        4'b0011:
        begin
        lo = (unsign)? $unsigned(reg_A) / $unsigned(reg_B) : (reg_A[31]*64'hFFFF_FFFF_0000_0000+(reg_A)) / (reg_B[31]*64'hFFFF_FFFF_0000_0000+(reg_B));
        hi = (unsign)? $unsigned(reg_A) % $unsigned(reg_B) : (reg_A[31]*64'hFFFF_FFFF_0000_0000+(reg_A)) % (reg_B[31]*64'hFFFF_FFFF_0000_0000+(reg_B));
        end
        4'b0100:
        begin
        reg_C = reg_A | reg_B;
        end
        4'b0101:
        begin
        reg_C = reg_A & reg_B;
        end
        4'b0110:
        begin
        reg_C = ~(reg_A | reg_B);
        end
        4'b0111:
        begin
        reg_C = reg_A ^ reg_B;
        end
        4'b1000:
        begin
        reg_C = reg_B << reg_A;
        end
        4'b1001:
        begin
        reg_C = (unsign)? reg_B >> reg_A : reg_B >>> reg_A;
        end
        4'b1010:
        begin
        reg_C = ($unsigned(reg_A) < $unsigned(reg_B))?1:0;
        end
    endcase
    zf=(reg_C==0&&ALUop!=4'b0010&&ALUop!=4'b0011)?1'b1:1'b0;
    nf=(reg_C[31]==1'b1&&ALUop!=4'b0010&&ALUop!=4'b0011)?1'b1:1'b0;
    if(FlagEn==2'b01)
    begin
        reg_C=nf;
        zf=(reg_C==0)?1'b1:1'b0;
        nf=1'b0;
    end
    if(FlagEn[1]==1'b1) 
    begin
        if(FlagEn[0]==zf)
        begin
            bc=1'b1;
            reg_C=imm;
        end
        else reg_C=0;
    end

end

assign c = reg_C[31:0];
assign load = lc;
assign branch = bc;
assign store = sc;

endmodule