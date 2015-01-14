unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, Menus, StrUtils, Process;

type

  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    StatusBar1: TStatusBar;
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure MenuItem2Click(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

function IsWavFile(const FileName: string): Boolean;
begin
  Result := LowerCase(ExtractFileExt(FileName)) = '.wav';
end;

function IsCueFile(const FileName: string): Boolean;
begin
  Result := LowerCase(ExtractFileExt(FileName)) = '.cue';
end;

function LoadCueFile(const FileName: string): TStringList;
begin
  Result := TStringList.Create();
  Result.LoadFromFile(FileName);
end;

function GetFileLineIndex(const Cue: TStringList): Integer;
var
  I: Integer;
begin
  I := -1;
  for I := 0 to Cue.Count - 1 do
  begin
    if Pos('FILE', Cue.Strings[I]) = 1 then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function ExtractFileLine(const Cue: TStringList): string;
var
  LineIndex: Integer;
begin
  LineIndex := GetFileLineIndex(Cue);
  if LineIndex = -1 then Result := '' else Result := Cue.Strings[LineIndex];
end;

function ExtractWavFileName(const Line: string): string;
begin
  Result := Copy(Line, Pos('"', Line) + 1, RPos('"', Line) - Pos('"', Line) - 1);
end;

procedure EncodeWavFile(const FileName: string);
var
  FlacExe: string;
  AProcess: TProcess;
begin
  FlacExe := ExtractFilePath(Application.ExeName) + 'flac.exe';
  //ExecuteProcess(FlacExe, ['-8', FileName])

  try
    AProcess := TProcess.Create(nil);
    AProcess.Executable:= FlacExe;
    AProcess.Parameters.Add('-8');
    AProcess.Parameters.Add(FileName);
    AProcess.Options := AProcess.Options + [poWaitOnExit];
    AProcess.ShowWindow := swoMinimize;
    AProcess.Execute;
  finally
    AProcess.Free;
  end;
end;

function ChangeFileLineExtToFlac(const Line: string): string;
begin
  Result := StringReplace(Line, '.wav', '.flac', []);
end;

procedure SaveCueFile(const Cue: TStringList; const FilePath: string);
var
  LineIndex: Integer;
begin
  LineIndex := GetFileLineIndex(Cue);
  Cue.Strings[LineIndex] := ChangeFileLineExtToFlac(Cue.Strings[LineIndex]);
  Cue.SaveToFile(FilePath);
end;

procedure RestorCueTimestamp(const CueFilePath: string);
var
  Line: string;
  Cue: TStringList;
  WaveFileName: string;
  WaveFilePath: string;
begin
  Cue := LoadCueFile(CueFilePath);
  try
    Line := ExtractFileLine(Cue);
    if Line = '' then Exit;
    Form1.Memo1.Lines.Add(Format('Line: %s', [SysToUTF8(Line)]));
    WaveFileName := ExtractWavFileName(Line);
    Form1.Memo1.Lines.Add(Format('WaveFileName: %s', [SysToUTF8(WaveFileName)]));
    WaveFilePath := ExtractFilePath(CueFilePath) + WaveFileName;
    Form1.Memo1.Lines.Add(Format('CueFile: %s, WaveFile: %s', [SysToUTF8(CueFilePath), SysToUTF8(WaveFilePath)]));
    FileSetDate(CueFilePath, FileAge(WaveFilePath));
  finally
    Cue.Free;
  end;
end;

procedure ChangeWavToFlac(const CueFilePath: string);
var
  Line: string;
  Cue: TStringList;
  WavFileName: string;
  WaveFilePath: string;
  WaveFileSize: Int64;
  FlacFileName: string;
  FlacFilePath: string;
  FlacFileSize: Int64;
begin
  Cue := LoadCueFile(CueFilePath);
  try
    Line := ExtractFileLine(Cue);
    if Line = '' then Exit;
    WavFileName := ExtractWavFileName(Line);
    if not IsWavFile(WavFileName) then Exit;
    WaveFilePath := ExtractFilePath(CueFilePath) + WavFileName;
    WaveFileSize := FileSize(SysToUTF8(WaveFilePath));
    Form1.Memo1.Lines.Add(Format('InFile: %s (%s bytes)', [SysToUTF8(WavFileName), FormatFloat('#,', WaveFileSize)]));
    EncodeWavFile(WaveFilePath);
    FlacFileName := ChangeFileExt(WavFileName, '.flac');
    FlacFilePath := ExtractFilePath(CueFilePath) + FlacFileName;
    FlacFileSize := FileSize(SysToUTF8(FlacFilePath));
    Form1.Memo1.Lines.Add(Format('OutFile: %s (%s bytes / %.1f%%)', [SysToUTF8(FlacFileName), FormatFloat('#,', FlacFileSize), FlacFileSize / WaveFileSize * 100]));
    SaveCueFile(Cue, CueFilePath);
  finally
    Cue.Free;
  end;
end;

procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of string
  );
var
  I: Integer;
  TargetFile: string;
begin
  for I := 0 to Length(FileNames) -1 do
  begin
    TargetFile := UTF8ToSys(FileNames[I]);
    if IsCueFile(TargetFile) then
    begin
      ChangeWavToFlac(TargetFile);
      RestorCueTimestamp(TargetFile);
    end;
  end;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
begin
  Close();
end;

end.
