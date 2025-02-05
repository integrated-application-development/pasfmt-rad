unit Pasfmt.WinExec;

interface

uses Winapi.Windows;

type
  TReadPrepareOutputProc = reference to procedure(var Data: PByte; var DataCapacity: Cardinal);
  TReadConsumeOutputProc = reference to procedure(Data: PByte; DataLen: Cardinal);
  TOutputHandler = record
    Prepare: TReadPrepareOutputProc;
    Consume: TReadConsumeOutputProc;
  end;

  TWriteInputProc = reference to procedure(var Data: PByte; var DataLen: Cardinal; BytesWritten: Cardinal);
  TInputHandler = record
    Produce: TWriteInputProc;
  end;

function RunWinProcess(
    CommandLine: string;
    StdIn: TInputHandler;
    StdOut: TOutputHandler;
    StdErr: TOutputHandler;
    WorkingDirectory: string;
    TimeoutMillis: Cardinal
): Cardinal;

implementation

uses System.Classes, System.SysUtils;

type
  TOutputPipeThread = class(TThread)
  private
    FPipe: THandle;
    FOutputHandler: TOutputHandler;
    FPipeDesc: string;
  public
    constructor Create(Pipe: THandle; OutputHandler: TOutputHandler; PipeDesc: string); overload;
    procedure Execute; override;
  end;

  TInputPipeThread = class(TThread)
  private
    FPipe: THandle;
    FInputHandler: TInputHandler;
    FPipeDesc: string;
  public
    constructor Create(Pipe: THandle; InputHandler: TInputHandler; PipeDesc: string); overload;
    procedure Execute; override;
  end;

constructor TOutputPipeThread.Create(Pipe: THandle; OutputHandler: TOutputHandler; PipeDesc: string);
begin
  inherited Create(False);
  FPipe := Pipe;
  FOutputHandler := OutputHandler;
  FPipeDesc := PipeDesc;
end;

procedure TOutputPipeThread.Execute;
var
  WasOK: Boolean;
  Ptr: PByte;
  DataLen: Cardinal;
  BytesRead: FixedUInt;
begin
  NameThreadForDebugging('pasfmt: read output pipe (' + FPipeDesc + ')');

  repeat
    FOutputHandler.Prepare(Ptr, DataLen);
    WasOK := Winapi.Windows.ReadFile(FPipe, Ptr^, DataLen, BytesRead, nil);
    FOutputHandler.Consume(Ptr, BytesRead);
  until not WasOK or (BytesRead = 0);
end;

constructor TInputPipeThread.Create(Pipe: THandle; InputHandler: TInputHandler; PipeDesc: string);
begin
  inherited Create(False);
  FPipe := Pipe;
  FInputHandler := InputHandler;
  FPipeDesc := PipeDesc;
end;

procedure TInputPipeThread.Execute;
var
  WasOK: Boolean;
  Ptr: PByte;
  DataLen: Cardinal;
  BytesWritten: Cardinal;
begin
  NameThreadForDebugging('pasfmt: write input pipe (' + FPipeDesc + ')');

  try
    BytesWritten := 0;
    repeat
      FInputHandler.Produce(Ptr, DataLen, BytesWritten);
      WasOK := True;
      if DataLen > 0 then
        WasOK := Winapi.Windows.WriteFile(FPipe, Ptr^, DataLen, BytesWritten, nil);
    until not WasOK or (BytesWritten = 0) or (DataLen = 0);
  finally
    if not CloseHandle(FPipe) then
      RaiseLastOSError;
  end;
end;

function RunWinProcess(
    CommandLine: string;
    StdIn: TInputHandler;
    StdOut: TOutputHandler;
    StdErr: TOutputHandler;
    WorkingDirectory: string;
    TimeoutMillis: Cardinal
): Cardinal;
var
  SecAttrs: TSecurityAttributes;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;

  ProcHandle: Boolean;

  StdOutPipeRead, StdOutPipeWrite: THandle;
  StdErrPipeRead, StdErrPipeWrite: THandle;
  StdInPipeRead, StdInPipeWrite: THandle;

  StdInThread: TInputPipeThread;
  StdOutThread: TOutputPipeThread;
  StdErrThread: TOutputPipeThread;
begin
  Result := High(Cardinal);

  SecAttrs := Default(TSecurityAttributes);
  SecAttrs.nLength := SizeOf(SecAttrs);
  SecAttrs.bInheritHandle := True;
  SecAttrs.lpSecurityDescriptor := nil;

  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecAttrs, 0);
  CreatePipe(StdErrPipeRead, StdErrPipeWrite, @SecAttrs, 0);
  CreatePipe(StdInPipeRead, StdInPipeWrite, @SecAttrs, 0);

  if not SetHandleInformation(StdOutPipeRead, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(StdErrPipeRead, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(StdInPipeWrite, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;

  StartupInfo := Default(TStartupInfo);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.hStdInput := StdInPipeRead;
  StartupInfo.hStdOutput := StdOutPipeWrite;
  StartupInfo.hStdError := StdErrPipeWrite;

  ProcHandle :=
      CreateProcess(nil, PChar(CommandLine), nil, nil, True, 0, nil, PChar(WorkingDirectory), StartupInfo, ProcessInfo);

  if not ProcHandle then
    RaiseLastOSError;

  try
    if not CloseHandle(StdOutPipeWrite) then
      RaiseLastOSError;
    if not CloseHandle(StdErrPipeWrite) then
      RaiseLastOSError;
    if not CloseHandle(StdInPipeRead) then
      RaiseLastOSError;

    StdInThread := TInputPipeThread.Create(StdInPipeWrite, StdIn, 'stdin');
    StdOutThread := TOutputPipeThread.Create(StdOutPipeRead, StdOut, 'stdout');
    StdErrThread := TOutputPipeThread.Create(StdErrPipeRead, StdErr, 'stderr');
    try
      Assert(StdInThread.WaitFor = 0);
      Assert(StdOutThread.WaitFor = 0);
      Assert(StdErrThread.WaitFor = 0);

      case WaitForSingleObject(ProcessInfo.hProcess, TimeoutMillis) of
        WAIT_TIMEOUT: begin
          raise Exception.CreateFmt('subprocess timed out after %d ms: %s', [TimeoutMillis, CommandLine]);
        end;
        WAIT_FAILED: RaiseLastOSError;
      else
        Assert(GetExitCodeProcess(ProcessInfo.hProcess, Result));
      end;

    finally
      FreeAndNil(StdInThread);
      FreeAndNil(StdOutThread);
      FreeAndNil(StdErrThread);
    end;
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

end.
