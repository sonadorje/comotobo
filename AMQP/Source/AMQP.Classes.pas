unit AMQP.Classes;

interface

Uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  AMQP.Frame, AMQP.Message, AMQP.Method, AMQP.Types;

Type
  AMQPException = Class(Exception);

  TAMQPServerProperties = Class
  Strict Private
    FCapabilities : TStringList;
    FMechanisms   : TStringList;
    FLocales      : TStringList;
    FClusterName  : String;
    FCopyright    : String;
    FInformation  : String;
    FPlatform     : String;
    FProduct      : String;
    FVersion      : String;
    FKnownHosts   : String;
    FVersionMajor : Integer;
    FVersionMinor : Integer;
    FChannelMax   : Integer;
    FFrameMax     : Integer;
    FHeartbeat    : Integer;
  Public
    Property Capabilities         : TStringList read FCapabilities;
    Property Mechanisms           : TStringList read FMechanisms;
    Property Locales              : TStringList read FLocales;
    Property ClusterName          : String      read FClusterName;
    Property Copyright            : String      read FCopyright;
    Property Information          : String      read FInformation;
    Property &Platform            : String      read FPlatform;
    Property Product              : String      read FProduct;
    Property Version              : String      read FVersion;
    Property KnownHosts           : String      read FKnownHosts;
    Property ProtocolVersionMajor : Integer     read FVersionMajor;
    Property ProtocolVersionMinor : Integer     read FVersionMinor;
    Property ChannelMax           : Integer     read FChannelMax;
    Property FrameMax             : Integer     read FFrameMax;
    Property Heartbeat            : Integer     read FHeartbeat;

    Procedure ReadConnectionStart( AConnectionStart: TAMQPMethod );
    Procedure ReadConnectionTune( AConnectionTune: TAMQPMethod );
    Procedure ReadConnectionOpenOK( AConnectionOpenOK: TAMQPMethod );

    Constructor Create;
    Destructor Destroy; Override;
  End;

  TBlockingQueue<T> = Class
  Strict Protected
    FGuard     : TCriticalSection;
    FCondition : TConditionVariableCS;
    FQueue     : TQueue<T>;
  Public
    Function Count: Integer; Virtual;
    Function Get: T; Virtual;
    Procedure Put( Item: T ); Virtual;

    Constructor Create; Virtual;
    Destructor Destroy; Override;
  End;

  TAMQPQueue = TBlockingQueue<TAMQPFrame>;

  TAMQPMessageQueue = TBlockingQueue<TAMQPMessage>;

implementation

{ TAMQPServerProperties }

constructor TAMQPServerProperties.Create;
begin
  FCapabilities := TStringList.Create;
  FMechanisms   := TStringList.Create;
  FLocales      := TStringList.Create;
  FMechanisms.StrictDelimiter := True;
  FMechanisms.Delimiter       := ' ';
  FLocales.StrictDelimiter    := True;
  FLocales.Delimiter          := ' ';
  FClusterName  := '';
  FCopyright    := '';
  FInformation  := '';
  FPlatform     := '';
  FProduct      := '';
  FVersion      := '';
  FKnownHosts   := '';
  FVersionMajor := 0;
  FVersionMinor := 0;
  FChannelMax   := 0;
  FFrameMax     := 0;
  FHeartbeat    := 0;
end;

Procedure TAMQPServerProperties.ReadConnectionStart( AConnectionStart: TAMQPMethod );
var
  ServerProperties: TFieldTable;
  ServerCapabilities: TFieldTable;
  Pair: TFieldValuePair;
begin
  FMechanisms.DelimitedText := AConnectionStart.Field['mechanisms'].AsLongString.Value;
  FLocales.DelimitedText    := AConnectionStart.Field['locales'].AsLongString.Value;
  ServerProperties          := AConnectionStart.Field['server-properties'].AsFieldTable;
  FVersionMajor             := AConnectionStart.Field['version-major'].AsShortShortUInt.Value;
  FVersionMinor             := AConnectionStart.Field['version-minor'].AsShortShortUInt.Value;
  FClusterName              := ServerProperties.Field['cluster_name'].AsShortString.Value;
  FCopyright                := ServerProperties.Field['copyright'].AsShortString.Value;
  FInformation              := ServerProperties.Field['information'].AsShortString.Value;
  FPlatform                 := ServerProperties.Field['platform'].AsShortString.Value;
  FProduct                  := ServerProperties.Field['product'].AsShortString.Value;
  FVersion                  := ServerProperties.Field['version'].AsShortString.Value;
  ServerCapabilities        := ServerProperties.Field['capabilities'].AsFieldTable;
  for Pair in ServerCapabilities do
    FCapabilities.Values[ Pair.Name.Value ] := Pair.Value.AsString('');
end;

Procedure TAMQPServerProperties.ReadConnectionTune( AConnectionTune: TAMQPMethod );
begin
  FChannelMax               := AConnectionTune.Field['channel-max'].AsShortUInt.Value;
  FFrameMax                 := AConnectionTune.Field['frame-max'].AsLongUInt.Value;
  FHeartbeat                := AConnectionTune.Field['heartbeat'].AsShortUInt.Value;
end;

Procedure TAMQPServerProperties.ReadConnectionOpenOK( AConnectionOpenOK: TAMQPMethod );
begin
  FKnownHosts               := AConnectionOpenOK.Field['known-hosts'].AsShortString.Value;
end;

destructor TAMQPServerProperties.Destroy;
begin
  FCapabilities.Free;
  FMechanisms.Free;
  FLocales.Free;
  inherited;
end;

{ TBlockingQueue<T> }

function TBlockingQueue<T>.Count: Integer;
begin
  FGuard.Acquire;
  try
    Result := FQueue.Count;
  finally
    FGuard.Release;
  end;
end;

constructor TBlockingQueue<T>.Create;
begin
  inherited;
  FGuard     := TCriticalSection.Create;
  FCondition := TConditionVariableCS.Create;
  FQueue     := TQueue<T>.Create;
end;

destructor TBlockingQueue<T>.Destroy;
begin
  FQueue.Free;
  FQueue := nil;
  FCondition.Free;
  FCondition := nil;
  FGuard.Free;
  FGuard := nil;
  inherited;
end;

function TBlockingQueue<T>.Get: T;
begin
  FGuard.Acquire;
  try
    while FQueue.Count = 0 do
    begin
      FCondition.WaitFor(FGuard);
    end;
    Result := FQueue.Dequeue;
  finally
    FGuard.Release;
  end;
end;

procedure TBlockingQueue<T>.Put(Item: T);
begin
  FGuard.Acquire;
  try
    FQueue.Enqueue( Item );
    FCondition.ReleaseAll;
  finally
    FGuard.Release;
  end;
end;

end.
