unit Pasfmt.FormatCore;

interface

type
  TFormatResult = record
    Output: UTF8String;
    Cursors: TArray<Integer>;
    ExitCode: Cardinal;
    ErrorInfo: string;
  end;

  TFormatter = record
    Executable: string;
    function Format(Input: UTF8String; Cursors: TArray<Integer>): TFormatResult;
  end;

implementation

uses Pasfmt.Subprocess, System.SysUtils, System.StrUtils;

//______________________________________________________________________________________________________________________

function ExtractCursorTag(Data: string; out TagValue: string): string;

  function IsValueChar(const Char: Char): Boolean;
  begin
    Result := ((Char >= '0') and (Char <= '9')) or (Char = ',');
  end;

const
  CTag: string = 'CURSOR=';
var
  TagPos: Integer;
  StartPos: Integer;
  EndPos: Integer;
begin
  TagPos := System.Pos(CTag, Data);
  if TagPos > 0 then begin
    StartPos := TagPos + Length(CTag);
    EndPos := StartPos;

    while (EndPos <= Length(Data)) and IsValueChar(Data[EndPos]) do
      Inc(EndPos);

    TagValue := Copy(Data, StartPos, EndPos - StartPos);
    Result := Copy(Data, 1, TagPos - 1) + Copy(Data, EndPos + 1);
  end;
end;

//______________________________________________________________________________________________________________________

function SerializeCursors(const Cursors: TArray<Integer>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(Cursors) - 1 do begin
    if I = 0 then
      Result := IntToStr(Cursors[I])
    else
      Result := Result + ',' + IntToStr(Cursors[I]);
  end;
end;

//______________________________________________________________________________________________________________________

function DeserializeCursors(TagValue: string): TArray<Integer>;
var
  CursorStrs: TArray<string>;
  I: Integer;
begin
  CursorStrs := SplitString(TagValue, ',');
  SetLength(Result, Length(CursorStrs));
  for I := 0 to Length(CursorStrs) - 1 do begin
    if not TryStrToInt(CursorStrs[I], Result[I]) then begin
      Result[I] := -1;
    end;
  end;
end;

//______________________________________________________________________________________________________________________

function TFormatter.Format(Input: UTF8String; Cursors: TArray<Integer>): TFormatResult;
var
  CommandLine: string;
  StdErr: UTF8String;
  CursorTagValue: string;
  EffectiveExe: string;
begin
  EffectiveExe := Executable;
  if EffectiveExe = '' then begin
    EffectiveExe := 'pasfmt.exe';
  end;

  CommandLine :=
      System.SysUtils.Format('"%s" -C encoding=utf-8 --cursor=%s', [EffectiveExe, SerializeCursors(Cursors)]);

  Result := Default(TFormatResult);
  Result.ExitCode := RunProcess(CommandLine, Input, Result.Output, StdErr, 1);
  Result.ErrorInfo := ExtractCursorTag(string(StdErr), CursorTagValue);
  Result.Cursors := DeserializeCursors(CursorTagValue);
end;

end.
