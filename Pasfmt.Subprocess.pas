unit Pasfmt.Subprocess;

interface

function RunProcess(
    CommandLine: string;
    const StdIn: UTF8String;
    out StdOut: UTF8String;
    out StdErr: UTF8String;
    WorkingDirectory: string = '';
    TimeoutMillis: Cardinal = INFINITE
): Cardinal;

implementation

uses
  Pasfmt.WinExec,
  System.SysUtils;

function RunProcess(
    CommandLine: string;
    const StdIn: UTF8String;
    out StdOut: UTF8String;
    out StdErr: UTF8String;
    WorkingDirectory: string = '';
    TimeoutMillis: Cardinal = INFINITE
): Cardinal;
var
  Buf: TBytes;
  BufErr: TBytes;

  FirstInput: Boolean;

  StdOutHandler: TOutputHandler;
  StdErrHandler: TOutputHandler;
  StdInHandler: TInputHandler;

  LocalStdOut: UTF8String;
  LocalStdErr: UTF8String;
begin
  SetLength(Buf, 4096);
  SetLength(BufErr, 4096);

  FirstInput := True;
  StdInHandler.Produce :=
      procedure(var Data: PByte; var DataLen: Cardinal; BytesRead: Cardinal)
      begin
        if FirstInput then begin
          Data := PByte(StdIn);
          DataLen := Length(StdIn);
        end
        else begin
          Data := Data + BytesRead;
          DataLen := DataLen - BytesRead;
        end;

        FirstInput := False;
      end;

  StdOutHandler.Prepare :=
      procedure(var Data: PByte; var DataCapacity: Cardinal)
      begin
        Data := Pointer(Buf);
        DataCapacity := Length(Buf) - 1;
      end;

  StdOutHandler.Consume :=
      procedure(Data: PByte; DataLen: Cardinal)
      begin
        Data[DataLen] := 0;
        LocalStdOut := LocalStdOut + UTF8String(PAnsiChar(Data));
      end;

  StdErrHandler.Prepare :=
      procedure(var Data: PByte; var DataCapacity: Cardinal)
      begin
        Data := Pointer(BufErr);
        DataCapacity := Length(BufErr) - 1;
      end;

  StdErrHandler.Consume :=
      procedure(Data: PByte; DataLen: Cardinal)
      begin
        Data[DataLen] := 0;
        LocalStdErr := LocalStdErr + UTF8String(PAnsiChar(Data));
      end;

  Result :=
      Pasfmt
          .WinExec
          .RunWinProcess(CommandLine, StdInHandler, StdOutHandler, StdErrHandler, WorkingDirectory, TimeoutMillis);

  StdOut := LocalStdOut;
  StdErr := LocalStdErr;
end;

end.
