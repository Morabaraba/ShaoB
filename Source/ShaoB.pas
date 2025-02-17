program ShaoB;

  // IRC ShaoB
  // Will only work on UNIX based OS.  Linux, Darwin, *NIX, etc.
  // Uses ARARAT SYNAPSE library for sockets and SSL/TLS.


  {$MODE OBJFPC}
  {$H+}


uses
  cThreads,
  cMem,
  Classes,
  sConsole,
  sCurl,
  sIRC,
  sNote,
  sProfile,
  sQuake,
  sWeather,
  SysUtils;


var
  err       : string;
  fAPIXU    : string;
  fChannel  : string;
  fNetwork  : string;
  fOEDAppID : string;
  fOEDKey   : string;
  fPassword : string;
  fPort     : string;
  fVersion  : string; 
  fUserName : string;
  s         : string;


  function ConfigRead : string;
  var
    i    : integer;
    name : string;
    para : string;
    s    : string;
    t    : TStringList;
  begin
    s := '';
    t := TStringList.Create;
    t.LoadFromFile( 'shao.config' );
    for i := 0 to t.Count - 1 do begin
      name := trim( leftStr( t.Strings[ i ], pos( ':', t.Strings[ i ] + ':' ) - 1 ) );
      if pos( ':', t.Strings[ i ] ) > 0
        then para := trim( rightStr( t.Strings[ i ], length( t.Strings[ i ] ) - pos( ':', t.Strings[ i ] ) ) )
        else para := '';
      case uppercase( name ) of
        'APIXU'    : fAPIXU    := para;
        'CHANNEL'  : fChannel  := para;
        'NETWORK'  : fNetwork  := para;
        'OEDAPPID' : fOEDappID := para;
        'OEDKEY'   : fOEDKey   := para;
        'PASSWORD' : fPassword := para;
        'PORT'     : fPort     := para;
        'USERNAME' : fUsername := para;
      end;  // case
    end;  // for i
    if length( trim( fAPIXU ) ) = 0 then begin
      if length( s ) > 0 then s := s + ', ';
      s := s + 'missing APIXU:';
    end;
    if length( trim( fChannel ) ) = 0 then begin
      if length( s ) > 0 then s := s + ', ';
      s := s + 'Missing Channel:';
    end else if fChannel[ 1 ] <> '#' then fChannel := '#' + fChannel;
    if length( trim( fNetwork ) ) = 0 then begin
      if length( s ) > 0 then s := s + ', ';
      s := s + 'Missing Network:';
    end;
    if length( trim( fOEDAppID ) ) = 0 then begin
      if length( s ) > 0 then s := s + ', ';
      s := s + 'Missing OEDAppID:';
    end;
    if length( trim( fOEDKey ) ) = 0 then begin
      if length( s ) > 0 then s := s + ', ';
      s := s + 'Missing OEDKey:';
    end;
    if length( trim( fPort ) ) = 0 then begin
      fPort := '6667';
    end;
    if length( trim( fUserName ) ) = 0 then begin
      fUserName := 'ShaoB';
    end;
    ConfigRead := s;
    t.Free;
  end;  //  ConfigRead


begin
  fVersion := '1.9.1';
  fIRC     := tIRC.Create;
  fNote    := tNote.Create;
  fProf    := tProf.Create;
  fQuake   := tQuake.Create;
  fWeather := tWeather.Create;
  err := ConfigRead;
  if paramcount = 1 then begin
    fChannel := paramstr( 1 );
    if ( fChannel <> '' ) and ( fChannel[ 1 ] <> '#' )
      then fChannel := '#' + fChannel;
  end;
  with fIRC do begin
    APIXU     := fAPIXU;
    Channel   := fChannel;
    Network   := fNetwork;
    OEDAppID  := fOEDAppID;
    OEDKey    := fOEDKey;
    Password  := fPassword;
    Port      := fPort;
    UserName  := fUserName;
    Version   := fVersion;
  end;
  fCurl := tCurl.Create( fUserName );
  fWeather.APIXU := fAPIXU;
  fCon := tConsole.Create( fUserName + ' ' + fVersion );
  if err = '' then begin
    fCon.Send( 'Starting ' + fNetwork + ': ' + fUserName + ' v' + fVersion, taBold );
    fIRC.Start;
    fQuake.Start;
    repeat
      s := fCon.LineGet;
      if s <> CtrlC then begin
        if s <> TAB then begin
          s := Trim( s );
          if length( s ) > 0 then begin
            fIRC.MsgChat( s );
            fCon.Send( fUsername + '> ' + s, taBold );
            s := '';
          end;
        end else if fCon.YesNo( 'Quit' ) then s := 'q';  // Tab
      end;  // CtrlC
    until ( s = 'q' ) or ( s = CtrlC );
  end;
  if err <> '' then begin
    fCon.Send( err, taBold );
    fCon.Send( 'Please review shao.config', taNormal );
    fCon.Send( 'Requires Network: Channel: OEDAppID: OEDKey: and APIXU: parameters as minimum', taNormal );
    fCon.Send( 'If Password: is missing then it is assumed none is required', taNormal );
    fCon.Send( 'If Port: is missing then 6667 is used', taNormal );
    fCon.Send( 'If Username: is missing then ShaoB is used', taNormal );
    fCon.Beep;
    fCon.AnyKey;
  end;
  fQuake.Terminate;
  fQuake.WaitFor;
  fCon.Send( 'Quake thread terminated', taNormal );
  fIRC.Shutdown;
  fIRC.WaitFor;
  fCon.Send( 'IRC thread terminated', taNormal );
  fCon.Terminate;
  try
    fNote.Free;
    fProf.Free;
    fQuake.Free;
    fWeather.Free;
    fIRC.Free;
    fCurl.Free;
    fCon.Free;
  except
  end;
  Writeln( 'Laters' );
  Writeln;
end.  // ShaoB
