unit Pasfmt.ProjectNotifier;

interface

uses
  ToolsAPI,
  System.SysUtils,
  System.StrUtils;

type
  TProjectNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier, IOTAProjectNotifier)
  public
    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    { IOTAModuleNotifier }
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string); overload;

    { IOTAProjectNotifier }
    procedure ModuleAdded(const AFileName: string);
    procedure ModuleRemoved(const AFileName: string);
    procedure ModuleRenamed(const AOldFileName, ANewFileName: string); overload;
  end;

function OnProjectNotify: TProjectNotifier;

implementation

var
  GOnProjectNotifier: IOTAProjectNotifier;

function OnProjectNotify: TProjectNotifier;
begin
  if not Assigned(GOnProjectNotifier) then
  begin
    GOnProjectNotifier := TProjectNotifier.Create;
  end;

  Result := TProjectNotifier(GOnProjectNotifier);
end;

{ TProjectNotifier }

procedure TProjectNotifier.AfterSave;
begin
  inherited;
end;

procedure TProjectNotifier.BeforeSave;
begin
  inherited;
end;

function TProjectNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TProjectNotifier.Destroyed;
begin
  inherited;
end;

procedure TProjectNotifier.Modified;
begin

end;

procedure TProjectNotifier.ModuleAdded(const AFileName: string);
begin

end;

procedure TProjectNotifier.ModuleRemoved(const AFileName: string);
begin

end;

procedure TProjectNotifier.ModuleRenamed(const NewName: string);
begin

end;

procedure TProjectNotifier.ModuleRenamed(const AOldFileName, ANewFileName: string);
begin

end;

end.
