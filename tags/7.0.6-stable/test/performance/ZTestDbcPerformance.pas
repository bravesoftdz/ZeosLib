{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{            Test Case for ZDBC API Performance           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZTestDbcPerformance;

interface

{$I ZPerformance.inc}

uses {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF},
  SysUtils, Classes, Types,
  ZPerformanceTestCase, ZDbcIntfs, ZCompatibility, ZSQLTestCase;

type

  {** Implements a performance test case for Native DBC API. }
  TZNativeDbcPerformanceTestCase = class(TZPerformanceSQLTestCase)
  protected
    FConnection: IZConnection;
    FSQL: String;
    FResultSet: IZResultSet;
  protected
    property SQL: String read FSQL;
    property Connection: IZConnection read FConnection write FConnection;

    function GetImplementedAPI: string; override;
    function CreateResultSet(Query: string): IZResultSet; virtual;

    { Implementation of different tests. }
    procedure DefaultSetUpTest; override;
    procedure DefaultTearDownTest; override;

    procedure SetUpTestConnect; override;
    procedure RunTestConnect; override;
    procedure SetUpTestInsert; override;
    procedure RunTestInsert; override;
    procedure RunTestOpen; override;
    procedure SetUpTestFetch; override;
    procedure RunTestFetch; override;
    procedure SetUpTestUpdate; override;
    procedure RunTestUpdate; override;
    procedure RunTestDelete; override;
    procedure SetUpTestDirectUpdate; override;
    procedure RunTestDirectUpdate; override;
  end;

  {** Implements a performance test case for Native DBC API. }
  TZCachedDbcPerformanceTestCase = class (TZNativeDbcPerformanceTestCase)
  private
    FAsciiStream, FUnicodeStream, FBinaryStream: TStream;
  protected
    function GetImplementedAPI: string; override;
    function CreateResultSet(Query: string): IZResultSet; override;

    procedure SetUpTestInsert; override;
    procedure RunTestInsert; override;
    procedure TearDownTestInsert; override;
    procedure SetUpTestUpdate; override;
    procedure RunTestUpdate; override;
    procedure TearDownTestUpdate; override;
    procedure RunTestDelete; override;
  end;

implementation

uses ZTestCase, ZTestConsts, ZSysUtils, ZDbcResultSet, ZDbcUtils, Math;

{ TZNativeDbcPerformanceTestCase }

{**
  Gets a name of the implemented API.
  @return the name of the implemented tested API.
}
function TZNativeDbcPerformanceTestCase.GetImplementedAPI: string;
begin
  Result := 'dbc';
end;

{**
  Creates a specific for this test result set.
  @param Query a SQL query string.
  @return a created Result Set for the SQL query.
}
function TZNativeDbcPerformanceTestCase.CreateResultSet(
  Query: string): IZResultSet;
var
  Statement: IZStatement;
begin
  Statement := Connection.CreateStatement;
  Statement.SetFetchDirection(fdForward);
  Statement.SetResultSetConcurrency(rcReadOnly);
  Statement.SetResultSetType(rtForwardOnly);
  Result := Statement.ExecuteQuery(Query);
end;

{**
  The default empty Set Up method for all tests.
}
procedure TZNativeDbcPerformanceTestCase.DefaultSetUpTest;
begin
  Connection := CreateDbcConnection;
end;

{**
  The default empty Tear Down method for all tests.
}
procedure TZNativeDbcPerformanceTestCase.DefaultTearDownTest;
begin
  if Assigned(FResultSet) then
  begin
    FResultSet.Close;
    FResultSet := nil;
  end;

  if Connection <> nil then
  begin
    Connection.Close;
    Connection := nil;
  end;
end;

{**
  The empty Set Up method for connect test.
}
procedure TZNativeDbcPerformanceTestCase.SetUpTestConnect;
begin
end;

{**
  Performs a connect test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestConnect;
begin
  if SkipForReason(srNoPerformance) then Exit;
  Connection := CreateDbcConnection;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZNativeDbcPerformanceTestCase.SetUpTestInsert;
var I: Integer;
begin
  inherited;
  FSQL := 'INSERT INTO '+PerformanceTable+' VALUES (';
  for i := 0 to high(ConnectionConfig.PerformanceResultSetTypes) do
    if i = 0 then FSQL := FSQL+'?'
    else FSQL := FSQL+',?';
  FSQL := FSQL+')';
end;

{**
  Performs an insert test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestInsert;
var
  I,N: Integer;
  Statement: IZPreparedStatement;
  Ansi: ZAnsiString;
  Uni: ZWideString;
  Bts: TByteDynArray;
begin
  if SkipForReason(srNoPerformance) then Exit;

  Statement := Connection.PrepareStatement(SQL);
  for I := 1 to GetRecordCount do
  begin
    for N := 1 to high(ConnectionConfig.PerformanceResultSetTypes)+1 do
      case ConnectionConfig.PerformanceResultSetTypes[N-1] of
        stBoolean: Statement.SetBoolean(N, Random(1) = 1);
        stByte:    Statement.SetByte(N, Ord(Random(255)));
        stShort,
        stInteger,
        stLong:    Statement.SetInt(N, I);
        stFloat,
        stDouble,
        stBigDecimal: Statement.SetFloat(N, RandomFloat(-100, 100));
        stString: Statement.SetString(N, RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stUnicodeString: Statement.SetUnicodeString(N, ZWideString(RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1])));
        stDate:    Statement.SetDate(N, Now);
        stTime:    Statement.SetTime(N, Now);
        stTimestamp: Statement.SetTimestamp(N, now);
        stGUID: Statement.SetBytes(N, RandomGUIDBytes);
        stBytes: Statement.SetBytes(N, RandomBts(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stAsciiStream:
          begin
            Ansi := ZAnsiString(RandomStr(GetRecordCount*100));
            Statement.SetBlob(N, stAsciiStream, TZAbstractBlob.CreateWithData(PAnsiChar(Ansi), Length(Ansi), Connection, False));
          end;
        stUnicodeStream:
          begin
            Uni := ZWideString(RandomStr(GetRecordCount*100));
            Statement.SetBlob(N, stUnicodeStream, TZAbstractBlob.CreateWithData(PWideChar(Uni), Length(Uni)*2, Connection, True));
          end;
        stBinaryStream:
          begin
            Bts := RandomBts(GetRecordCount*100);
            Statement.SetBlob(N, stBinaryStream, TZAbstractBlob.CreateWithData(Pointer(Bts), Length(Bts), Connection, False));
          end;
      end;
    Statement.ExecuteUpdatePrepared;
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

{**
  Performs an open test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestOpen;
begin
  if SkipForReason(srNoPerformance) then Exit;

  CreateResultSet('SELECT * FROM '+PerformanceTable);
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZNativeDbcPerformanceTestCase.SetUpTestFetch;
begin
  inherited;
  FResultSet := CreateResultSet('SELECT * FROM '+PerformanceTable);
end;
{**
   Performs a fetch data
}
procedure TZNativeDbcPerformanceTestCase.RunTestFetch;
var
  I: Integer;
begin
  if SkipForReason(srNoPerformance) then Exit;

  while FResultSet.Next do
    for i := 1 to high(ConnectionConfig.PerformanceResultSetTypes)+1 do
      case ConnectionConfig.PerformanceResultSetTypes[i-1] of
        stBoolean: FResultSet.GetBoolean(I);
        stByte:    FResultSet.GetByte(I);
        stShort,
        stInteger,
        stLong:    FResultSet.GetInt(I);
        stFloat,
        stDouble,
        stBigDecimal: FResultSet.GetFloat(I);
        stString: FResultSet.GetString(I);
        stUnicodeString: FResultSet.GetUnicodeString(I);
        stDate:    FResultSet.GetDate(I);
        stTime:    FResultSet.GetTime(I);
        stTimestamp: FResultSet.GetTimestamp(I);
        stBytes, stGUID: FResultSet.GetBytes(I);
        stAsciiStream, stUnicodeStream, stBinaryStream: FResultSet.GetBlob(I);
      end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZNativeDbcPerformanceTestCase.SetUpTestUpdate;
var I: Integer;
begin
  inherited;
  FSQL := 'UPDATE '+PerformanceTable+' SET';
  for i := 1 to high(ConnectionConfig.PerformanceFieldNames) do
    if I = 1 then
      FSQL := FSQL + ' '+ConnectionConfig.PerformanceFieldNames[I]+'=?'
    else
      FSQL := FSQL + ', '+ConnectionConfig.PerformanceFieldNames[I]+'=?';
  FSQL := FSQL + ' WHERE '+PerformancePrimaryKey+'=?';
end;

{**
  Performs an update test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestUpdate;
var
  I, N: Integer;
  Statement: IZPreparedStatement;
  Ansi: ZansiString;
  Uni: ZWideString;
  Bts: TByteDynArray;
begin
  if SkipForReason(srNoPerformance) then Exit;

  Statement := Connection.PrepareStatement(SQL);
  for I := 1 to GetRecordCount do
  begin
    for N := 1 to high(ConnectionConfig.PerformanceResultSetTypes) do
      case ConnectionConfig.PerformanceResultSetTypes[N] of
        stBoolean: Statement.SetBoolean(N, Random(1) = 1);
        stByte:    Statement.SetByte(N, Ord(Random(255)));
        stShort,
        stInteger,
        stLong:    Statement.SetInt(N, I);
        stFloat,
        stDouble,
        stBigDecimal: Statement.SetFloat(N, RandomFloat(-100, 100));
        stString: Statement.SetString(N, RandomStr(ConnectionConfig.PerformanceFieldSizes[N]));
        stUnicodeString: Statement.SetUnicodeString(N, ZWideString(RandomStr(ConnectionConfig.PerformanceFieldSizes[N])));
        stDate:    Statement.SetDate(N, Now);
        stTime:    Statement.SetTime(N, Now);
        stTimestamp: Statement.SetTimestamp(N, now);
        stGUID: Statement.SetBytes(N, RandomGUIDBytes);
        stBytes: Statement.SetBytes(N, RandomBts(ConnectionConfig.PerformanceFieldSizes[N]));
        stAsciiStream:
          begin
            Ansi := ZAnsiString(RandomStr(GetRecordCount*100));
            Statement.SetBlob(N, stAsciiStream, TZAbstractBlob.CreateWithData(PAnsiChar(Ansi), Length(Ansi), Connection, False));
          end;
        stUnicodeStream:
          begin
            Uni := ZWideString(RandomStr(GetRecordCount*100));
            Statement.SetBlob(N, stUnicodeStream, TZAbstractBlob.CreateWithData(PWideChar(Uni), Length(Uni)*2, Connection, True));
          end;
        stBinaryStream:
          begin
            Bts := RandomBts(GetRecordCount*100);
            Statement.SetBlob(N, stBinaryStream, TZAbstractBlob.CreateWithData(Pointer(Bts), Length(Bts), Connection, False));
          end;
      end;
    Statement.SetInt(High(ConnectionConfig.PerformanceResultSetTypes)+1, I);
    Statement.ExecuteUpdatePrepared;
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

{**
  Performs a delete test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestDelete;
var
  I: Integer;
  Statement: IZPreparedStatement;
begin
  if SkipForReason(srNoPerformance) then Exit;

  Statement := Connection.PrepareStatement(
    'DELETE FROM '+PerformanceTable+' WHERE '+PerformancePrimaryKey+'=?');
  for I := 1 to GetRecordCount do
  begin
    Statement.SetInt(1, I);
    Statement.ExecutePrepared;
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZNativeDbcPerformanceTestCase.SetUpTestDirectUpdate;
var
  I: Integer;
begin
  inherited;
  SetLength(FDirectSQLTypes, 0);
  SetLength(FDirectFieldNames, 0);
  SetLength(FDirectFieldSizes, 0);
  for i := 0 to high(ConnectionConfig.PerformanceResultSetTypes) do
  begin
    { copy predefined values to temporary arrays }
    SetLength(FDirectSQLTypes, Length(FDirectSQLTypes)+1);
    FDirectSQLTypes[High(FDirectSQLTypes)] := ConnectionConfig.PerformanceResultSetTypes[i];
    SetLength(FDirectFieldNames, Length(FDirectFieldNames)+1);
    FDirectFieldNames[High(FDirectFieldNames)] := ConnectionConfig.PerformanceFieldNames[i];
    SetLength(FDirectFieldSizes, Length(FDirectFieldSizes)+1);
    FDirectFieldSizes[High(FDirectFieldSizes)] := ConnectionConfig.PerformanceFieldSizes[i];
    { check types }
    case ConnectionConfig.PerformanceResultSetTypes[i] of
      stBytes, stBinaryStream:
        if StartsWith(Protocol, 'firebird') and not EndsWith(Protocol, '2.5') then //firebird below 2.5 doesn't support x'hex' syntax
        begin
          SetLength(FDirectSQLTypes, Length(FDirectSQLTypes)-1); //omit these types to avoid exception
          SetLength(FDirectFieldNames, Length(FDirectFieldNames)-1); //omit these names to avoid exception
          SetLength(FDirectFieldSizes, Length(FDirectFieldSizes)-1); //omit these names to avoid exception
        end;
      stBoolean:
        if StartsWith(Protocol, 'sqlite') or StartsWith(Protocol, 'mysql') then
        begin
          Self.FTrueVal := #39'Y'#39;
          Self.FFalseVal := #39'N'#39;
        end
        else
          if StartsWith(Protocol, 'postgre')then
          begin
            Self.FTrueVal := 'TRUE';
            Self.FFalseVal := 'FALSE';
          end
          else
          begin
            Self.FTrueVal := '1';
            Self.FFalseVal := '0';
        end;
      stDate, stTime, stTimeStamp: //session dependend values. This i'll solve later
        begin
          SetLength(FDirectSQLTypes, Length(FDirectSQLTypes)-1); //omit these types to avoid exception
          SetLength(FDirectFieldNames, Length(FDirectFieldNames)-1); //omit these names to avoid exception
          SetLength(FDirectFieldSizes, Length(FDirectFieldSizes)-1); //omit these names to avoid exception
        end;
    end;
  end;
end;

{**
  Performs a direct update test.
}
procedure TZNativeDbcPerformanceTestCase.RunTestDirectUpdate;
var
  I, N: Integer;
  Statement: IZStatement;
  SQL: String;
  OldDecimalSeparator: Char;
  OldThousandSeparator: Char;
begin
  if SkipForReason(srNoPerformance) then Exit;

  OldDecimalSeparator := {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}DecimalSeparator;
  OldThousandSeparator := {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}ThousandSeparator;
  {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}DecimalSeparator := '.';
  {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}ThousandSeparator := ',';
  Statement := Connection.CreateStatement;
  for I := 1 to GetRecordCount do
  begin
    SQL := 'UPDATE '+PerformanceTable+' SET ';
    for N := 1 to high(FDirectSQLTypes) do
    begin
      case FDirectSQLTypes[n] of
        stBoolean:
          if Random(1) = 1 then
            SQL := SQL + FDirectFieldNames[N]+'='+ FTrueVal
          else
            SQL := SQL + FDirectFieldNames[N]+'='+ FFalseVal;
        stByte:
          SQL := SQL + FDirectFieldNames[N]+'='+IntToStr(Random(255));
        stShort,
        stInteger,
        stLong:
          SQL := SQL + FDirectFieldNames[N]+'='+IntToStr(Random(I));
        stFloat,
        stDouble,
        stBigDecimal:
          {$IFNDEF WITH_FORMATSETTINGS}
          SQL := SQL + FDirectFieldNames[N]+'='+StringReplace(FloatToStr(RandomFloat(-100, 100)), ',','.', [rfReplaceAll]);
          {$ELSE}
          SQL := SQL + FDirectFieldNames[N]+'='+FloatToStr(RandomFloat(-100, 100));
          {$ENDIF}
        stString, stUnicodeString:
          SQL := SQL + FDirectFieldNames[N]+'='+Connection.GetEscapeString(RandomStr(FDirectFieldSizes[N]));
        stGUID:
          SQL := SQL + FDirectFieldNames[N]+'='+Connection.GetEscapeString(RandomGUIDString);
        stBytes:
          SQL := SQL + FDirectFieldNames[N]+'='+Connection.GetBinaryEscapeString(RandomBts(FDirectFieldSizes[N]));
        stAsciiStream, stUnicodeStream:
          SQL := SQL + FDirectFieldNames[N]+'='+Connection.GetEscapeString(RandomStr(GetRecordCount*100));
        stBinaryStream:
          SQL := SQL + FDirectFieldNames[N]+'='+Connection.GetBinaryEscapeString(RandomBts(GetRecordCount*100));
        //stDate, stTime, stTimestamp //session dependend
      end;
      if N = high(FDirectSQLTypes) then
        SQL := SQL + ' WHERE '+ PerformancePrimaryKey+'='+IntToStr(i)
      else
        SQL := SQL + ',';
    end;
    Statement.ExecuteUpdate(SQL);
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
  {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}DecimalSeparator := OldDecimalSeparator;
  {$IFDEF WITH_FORMATSETTINGS}FormatSettings.{$ENDIF}ThousandSeparator := OldThousandSeparator;
end;

{ TZCachedDbcPerformanceTestCase }

{**
  Gets a name of the implemented API.
  @return the name of the implemented tested API.
}
function TZCachedDbcPerformanceTestCase.GetImplementedAPI: string;
begin
  Result := 'dbc-cached';
end;

{**
  Creates a specific for this test result set.
  @param Query a SQL query string.
  @return a created Result Set for the SQL query.
}
function TZCachedDbcPerformanceTestCase.CreateResultSet(
  Query: string): IZResultSet;
var
  Statement: IZStatement;
begin
  Statement := Connection.CreateStatement;
  Statement.SetFetchDirection(fdForward);
  Statement.SetResultSetConcurrency(rcUpdatable);
  Statement.SetResultSetType(rtScrollInsensitive);
  Result := Statement.ExecuteQuery(Query);
end;

{**
  Performs an insert test.
}
procedure TZCachedDbcPerformanceTestCase.SetUpTestInsert;
var
  Bts: TByteDynArray;
  Count: Integer;
begin
  inherited;
  Count := Min(MaxPerformanceLobSize, GetRecordCount);
  FAsciiStream := TStringStream.Create(ZAnsiString(RandomStr(Count)));
  FUnicodeStream := WideStringStream(ZWideString(RandomStr(Count)));
  FBinaryStream := TMemoryStream.Create;
  Bts := RandomBts(Count);
  TMemoryStream(FBinaryStream).Write(Bts, Count);
  FBinaryStream.Position := 0;
  FResultSet := CreateResultSet('SELECT * FROM '+PerformanceTable);
end;

procedure TZCachedDbcPerformanceTestCase.RunTestInsert;
var
  I,N: Integer;
begin
  if SkipForReason(srNoPerformance) then Exit;

  for I := 1 to GetRecordCount do
  begin
    FResultSet.MoveToInsertRow;
    for N := 1 to high(ConnectionConfig.PerformanceResultSetTypes)+1 do
      case ConnectionConfig.PerformanceResultSetTypes[N-1] of
        stBoolean: FResultSet.UpdateBoolean(N, Random(1) = 1);
        stByte:    FResultSet.UpdateByte(N, Ord(Random(255)));
        stShort,
        stInteger,
        stLong:    FResultSet.UpdateInt(N, I);
        stFloat,
        stDouble,
        stBigDecimal: FResultSet.UpdateFloat(N, RandomFloat(-100, 100));
        stString: FResultSet.UpdateString(N, RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stUnicodeString: FResultSet.UpdateUnicodeString(N, ZWideString(RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1])));
        stDate:    FResultSet.UpdateDate(N, Now);
        stTime:    FResultSet.UpdateTime(N, Now);
        stTimestamp: FResultSet.UpdateTimestamp(N, now);
        stGUID: FResultSet.UpdateBytes(N, RandomGUIDBytes);
        stBytes: FResultSet.UpdateBytes(N, RandomBts(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stAsciiStream: FResultSet.UpdateAsciiStream(N, FAsciiStream);
        stUnicodeStream: FResultSet.UpdateUnicodeStream(N, FUnicodeStream);
        stBinaryStream: FResultSet.UpdateBinaryStream(N, FBinaryStream);
      end;
    FResultSet.InsertRow;
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZCachedDbcPerformanceTestCase.TearDownTestInsert;
begin
  FAsciiStream.Free;
  FUnicodeStream.Free;
  FBinaryStream.Free;
  inherited;
end;

procedure TZCachedDbcPerformanceTestCase.SetUpTestUpdate;
var
  Bts: TByteDynArray;
begin
  inherited;
  FAsciiStream := TStringStream.Create(ZAnsiString(RandomStr(GetRecordCount*100)));
  FUnicodeStream := WideStringStream(ZWideString(RandomStr(GetRecordCount*100)));
  FBinaryStream := TMemoryStream.Create;
  Bts := RandomBts(GetRecordCount*100);
  TMemoryStream(FBinaryStream).Write(Bts, GetRecordCount*100);
  FBinaryStream.Position := 0;
end;

{**
  Performs an update test.
}
procedure TZCachedDbcPerformanceTestCase.RunTestUpdate;
var
  N: Integer;
  ResultSet: IZResultSet;
begin
  if SkipForReason(srNoPerformance) then Exit;

  ResultSet := CreateResultSet('SELECT * from '+PerformanceTable);
  while ResultSet.Next do
  begin
    for N := 2 to high(ConnectionConfig.PerformanceResultSetTypes)+1 do
      case ConnectionConfig.PerformanceResultSetTypes[N-1] of
        stBoolean: ResultSet.UpdateBoolean(N, Random(1) = 1);
        stByte:    ResultSet.UpdateByte(N, Ord(Random(255)));
        stShort,
        stInteger,
        stLong:    ResultSet.UpdateInt(N, ResultSet.GetRow);
        stFloat,
        stDouble,
        stBigDecimal: ResultSet.UpdateFloat(N, RandomFloat(-100, 100));
        stString: ResultSet.UpdateString(N, RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stUnicodeString: ResultSet.UpdateUnicodeString(N, ZWideString(RandomStr(ConnectionConfig.PerformanceFieldSizes[N-1])));
        stDate:    ResultSet.UpdateDate(N, Now);
        stTime:    ResultSet.UpdateTime(N, Now);
        stTimestamp: ResultSet.UpdateTimestamp(N, now);
        stGUID: ResultSet.UpdateBytes(N, RandomGUIDBytes);
        stBytes: ResultSet.UpdateBytes(N, RandomBts(ConnectionConfig.PerformanceFieldSizes[N-1]));
        stAsciiStream: ResultSet.UpdateAsciiStream(N, FAsciiStream);
        stUnicodeStream: ResultSet.UpdateUnicodeStream(N, FUnicodeStream);
        stBinaryStream: ResultSet.UpdateBinaryStream(N, FBinaryStream);
      end;
    ResultSet.UpdateRow;
  end;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

procedure TZCachedDbcPerformanceTestCase.TearDownTestUpdate;
begin
  FAsciiStream.Free;
  FUnicodeStream.Free;
  FBinaryStream.Free;
  inherited;
end;

{**
  Performs a delete test.
}
procedure TZCachedDbcPerformanceTestCase.RunTestDelete;
var
  ResultSet: IZResultSet;
begin
  if SkipForReason(srNoPerformance) then Exit;

  ResultSet := CreateResultSet('SELECT * from '+PerformanceTable);
  while ResultSet.Next do
    ResultSet.DeleteRow;
  if not SkipPerformanceTransactionMode then Connection.Commit;
end;

initialization
  RegisterTest('performance', TZNativeDbcPerformanceTestCase.Suite);
  RegisterTest('performance', TZCachedDbcPerformanceTestCase.Suite);
end.

