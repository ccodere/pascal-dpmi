Unit DPMI;

{$IFNDEF DPMI}
 ERROR: THIS PROGRAM REQUIRES A DPMI SERVER
{$ENDIF}


{$IFNDEF CPU86}
 ERROR: THIS PROGRAM USES x86 SPECIFIC CODE
{$ENDIF}

{ DOCUMENTED BIOS CALLS AS WELL DOCUMENTED ARE SUPPORTED BY THE  }
{ DPMI SERVER. THIS INCLUDES BUFFERS AND POINTERS, THESE ARE THE }
{ ONLY INTERRUPTS WHICH SEEM TO BE SUPPORTED.                    }

{ How to call a real mode interrupt }
{ If the interrupt does NOT use Segment: Offset pairs }
{ use the normal Intr or ASM directive procedure      }

{ If the interrupt USES Segment:Offset and requires a        }
{ buffer, then Fill the TDPMIRegisters variable with 0's     }
{ Allocate some DOS Memory for the buffer. XGlobalDosAlloc   }
{ Pass the parameters, just like in real mode, except offset }
{ is always zero. Call RealModeInt with the passed registers }
{ then DeAllocateDOS Memory.                                 }

{ If the Interrupt Returns some information in a buffer, it  }
{ is a bit more complicated.                                 }

INTERFACE

TYPE
     LongRec = record
       Selector, Segment : word;
     end;

     DoubleWord = record
       Lo, Hi : word;
     end;

     QuadrupleByte = record
       Lo, Hi, sLo, sHi : byte;
     end;

     TDPMIRegisters = record
       EDI, ESI, EBP, Reserved, EBX, EDX, ECX, EAX : longint;
       Flags, ES, DS, FS, GS, IP, CS, SP, SS : word;
     end;



Procedure RealModeInt(IntNo : word; var Regs : TDPMIRegisters);
function XGlobalDosAlloc(Size : longint; var P : Pointer) : word;
Procedure XGlobalDOSFree(Var P: Pointer);

Function SetSelectorLimit(Selector: Word; Limit: Longint): Word;

{ VECTOR IS A REAL MODE SEGMENT:OFFSET POINTER }
Procedure GetRealIntVec(IntNo: Byte; Var Vector: Pointer);
{ VECTOR IS A PROTECTED MODE SELECTOR:OFFSET POINTER }
Procedure GetProtIntVec(IntNo: Byte; Var Vector: Pointer);




IMPLEMENTATION

Uses WinAPI;


  function XGlobalDosAlloc(Size : longint; var P : Pointer) : word;
  { Allocates memory in an area that DOS can access properly }
  { Returns the real segment to the allocated memory         }
  { P points to the allocated selector                       }
  var Long : longint;
  begin
    Long := GlobalDosAlloc(Size);
    P := Ptr(LongRec(Long).Selector, 0);
    XGlobalDosAlloc := LongRec(Long).Segment;
  end;

Procedure RealModeInt(IntNo : word; var Regs:TDPMIRegisters); assembler;
  { Simulates a real mode interrupt }
asm
    PUSH BP                                          { Save BP, just in case }
    MOV BX,IntNo                         { Move the Interrupt number into BX }
    XOR CX,CX                                                     { Clear CX }
    LES DI,Regs                              { Load the registers into ES:DI }
    MOV AX,$300                                { Set function number to 300h }
    INT $31                             { Call Interrupt 31h - DPMI Services }
    JC @Exit                                         { Jump to exit on carry }
    XOR AX,AX                                                     { Clear AX }
    @Exit:                                                      { Exit label }
    POP BP                                                      { Restore BP }
  end;

Procedure XGlobalDOSFree(Var P: Pointer);
Begin
 DoubleWord(P).Hi := GlobalDOSFree(DoubleWord(P).Hi);
end;

Procedure GetRealIntVec(IntNo: Byte; Var Vector: Pointer); Assembler;
ASM
 MOV AX, 0200h
 MOV BL, [IntNo]
 INT 31h
 LES DI, [Vector]
 MOV ES:[DI+2], CX
 MOV ES:[DI], DX
end;

Function SetSelectorLimit(Selector: Word; Limit: Longint): Word;Assembler;
ASM
 MOV AX, 0008h
 MOV BX, [Selector]
 MOV DX, WORD PTR [Limit]
 MOV CX, WORD PTR [Limit+2]
 INT 31h
 MOV AX, [Selector]
 JC @Error
@Error:
 MOV AX, 00h
@End:
end;

Procedure GetProtIntVec(IntNo: Byte; Var Vector: Pointer); Assembler;
ASM
 MOV AX, 0204h
 MOV BL, [IntNo]
 INT 31h
 LES DI, [Vector]
 MOV ES:[DI+2], CX
 MOV ES:[DI], DX
end;

END.