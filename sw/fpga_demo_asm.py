import struct
def R(f7,rs2,rs1,f3,rd,op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def I(imm,rs1,f3,rd,op):
    imm&=0xfff; return (imm<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(imm,rs2,rs1,f3,op):
    imm&=0xfff
    return ((imm>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1f)<<7)|op
def B(imm,rs2,rs1,f3,op):
    # imm in bytes, signed
    i=imm&0x1fff
    b12=(i>>12)&1; b11=(i>>11)&1; b10_5=(i>>5)&0x3f; b4_1=(i>>1)&0xf
    return (b12<<31)|(b10_5<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(b4_1<<8)|(b11<<7)|op
def J(imm,rd,op):
    i=imm&0x1fffff
    b20=(i>>20)&1; b10_1=(i>>1)&0x3ff; b11=(i>>11)&1; b19_12=(i>>12)&0xff
    return (b20<<31)|(b10_1<<21)|(b11<<20)|(b19_12<<12)|(rd<<7)|op
OPI,OPR,OPB,OPS,OPJ=0x13,0x33,0x63,0x23,0x6f
prog=[]
# Suma 1..10 = 55, stocata la 0x100, apoi bucla infinita.
# addr 0x00
prog.append(I(0,0,0,1,OPI))      # addi x1,x0,0   ; sum=0
prog.append(I(1,0,0,2,OPI))      # addi x2,x0,1   ; i=1
prog.append(I(11,0,0,3,OPI))     # addi x3,x0,11  ; limit=11
# loop @0x0c : bge x2,x3,done(+16 -> 0x1c)
prog.append(B(16,3,2,5,OPB))     # bge x2,x3,+16
prog.append(R(0,2,1,0,1,OPR))    # add x1,x1,x2  ; sum+=i  @0x10
prog.append(I(1,2,0,2,OPI))      # addi x2,x2,1  ; i++     @0x14
prog.append(J(-12,0,OPJ))        # jal x0,-12 -> loop @0x0c   @0x18
# done @0x1c
prog.append(I(0x100,0,0,4,OPI))  # addi x4,x0,0x100         @0x1c
prog.append(S(0,1,4,2,OPS))      # sw x1,0(x4)              @0x20
prog.append(J(0,0,OPJ))          # jal x0,0 (spin)          @0x24
with open('sw/fpga_demo.mem','w') as f:
    for w in prog: f.write("%08x\n"%(w&0xffffffff))
print("scris sw/fpga_demo.mem  (%d instr, suma asteptata=55=0x37)"%len(prog))
