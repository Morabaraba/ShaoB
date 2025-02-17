{ 
  sConsole.pas
  Copyright (c) 2019 Paul Davidson. All rights reserved.
}


unit sConsole;


  {$MODE OBJFPC}
  {$H+}


interface


  uses
    Classes;


  type


    tAttribute = ( taBlink,
                   taBold,
                   taInvBold,
                   taInverse,
                   taInvisible,
                   taLow,
                   taNormal,
                   taUnderline );  // tAttribute
                   

    tConsole = class( TObject )
      private
        fBlank     : string;
        fMutex     :TRTLCriticalSection;
        fTerminate : boolean;
        fTitle     : string;
        fXCurr     : integer;
        fXMax      : integer;
        fYMax      : integer;
        procedure    Attribute( a : tAttribute );
        procedure    ClearEOL;
        procedure    Init;
        function     KeyGet : string;
        procedure    Scroll;
        procedure    Window( t, b : integer );
        procedure    XY( x, y : integer );
        procedure    XYSA( x, y : integer; const s : string; a : tAttribute );
      public
        constructor Create( s : string );
        destructor  Destroy; override;
        procedure   AnyKey;
        procedure   Beep;
        procedure   Clear;
        procedure   Line1( s : string );
        function    LineGet : string;
        function    Menu( s : string ) : char;
        procedure   Ping;
        procedure   Send( s : string; a : tAttribute );
        procedure   Terminate;
        function    YesNo( s : string ) : boolean;
      end;  // tConsole


  const
    CR    = #13;
    CRLF  = CR + #10;
    CtrlC = #03;
    ESC   = #27;
    Tab   = #09;
    
    
  var
    fCon : tConsole;


implementation


  uses
    Keyboard,
    SysUtils;


  const
    cKeyWait = 50;       // Wait time between keyboard scans


  constructor tConsole.Create( s : string );
    // s is app title of page
  begin
    inherited Create;
    fTerminate := FALSE;
    fTitle     := s;
    InitCriticalSection( fMutex );
    InitKeyboard;
    Init;
  end;  // tConsole.Create


  destructor tConsole.Destroy;
  begin
    Clear;
    DoneKeyboard;
    DoneCriticalSection( fMutex );
    inherited Destroy;
  end;  // tConsole.Destroy


  procedure tConsole.AnyKey;
    // Hit any key to continue
  begin
    XYSA( 2, fYMax, 'Hit any key to continue', taInvBold );
    XY( 26, fYMax );
    KeyGet;
  end;  // tConsole.AnyKey


  procedure tConsole.Attribute( a : tAttribute );
    // Set text attribute
  begin
    case a of
      taBlink     : write( ESC, '[0m', ESC, '[5m' );
      taBold      : write( ESC, '[0m', ESC, '[1m' );
      taInvBold   : write( ESC, '[0m', ESC, '[40m', ESC, '[1;32m' );
      taInverse   : write( ESC, '[0m', ESC, '[7m' );
      taInvisible : write( ESC, '[0m', ESC, '[8m' );
      taLow       : write( ESC, '[0m', ESC, '[2m' );
      taNormal    : write( ESC, '[0m', ESC, '[m' );
      taUnderline : write( ESC, '[0m', ESC, '[4m' );
  	end;  // case
  end;  // tConsole.Attribute


  procedure tConsole.Beep;
    // Make noise
  begin
    write( #7 );
  end;  // tConsole.Beep;

  
  procedure tConsole.Clear;
    // Clear entire screen
  begin
    Window( 1, fYMax );
    Attribute( taNormal );
    write( ESC, '[2J' );
  end;  // tConsole.Clear


  procedure tConsole.ClearEOL;
    // Clear end of line
  begin
    write( ESC, '[K' );
  end;  // tConsole.ClearEOL


  procedure tConsole.Init;
    // Initialize console
  begin
    Clear; 
    fXMax := 132;
    fYMax := 50;
    Window( 1, fYMax );                                               // Remove scroll window
    SetLength( fBlank, fXMax );                                       // Make fBlank line
    Fillchar( fBlank[ 1 ], fXMax, ' ' );                              // Fill fBlank with blanks
    XYSA( 1, 1,         fBlank, taInvBold );                          // Write inverted blank line at top of console                            
    XYSA( 1, fYMax,     fBlank, taInverse );                          // Write inverted blank line at bottum of console
    XYSA( ( fXMax - Length( fTitle ) ) div 2, 1, fTitle, taInvBold ); // Write fTitle at middle of top line
    fXCurr := 2;                                                      // Sett fXCurr
  end;  // tConsole.Init


  function tConsole.KeyGet : string;
    // Get key from terminal without having to press return
  var
    k : TKeyEvent;
    s : string;
  begin
    repeat
      Sleep( 50 );
      k := PollKeyEvent;
    until ( k > 0 ) or fTerminate;
    if not fTerminate then begin
      k := GetKeyEvent;
      k := TranslateKeyEvent( k );
      s := GetKeyEventChar( k );
    end else s:= #00;
    if ( s >= ' ' ) and ( s <= '~' ) then XYSA( fXCurr, fYMax, s, taInverse );
    KeyGet := s;
  end;  // tConsole.KeyGet


  procedure tConsole.Line1( s : string );
    // Write top line
  begin
    fTitle := s;
    XYSA( ( fXMax - Length( fTitle ) ) div 2, 1, fTitle, taInvBold );
  end;  // tConsole.Line1

  
  function tConsole.LineGet : string;
    // Gets line from keyboard
  var
    c : string;
    s : string;
  begin
    s      := '';
    fXCurr := 2;
    XYSA( 1, fYMax, fBlank, taInverse );
    XY( fXCurr, fYMax );
    Attribute( taInverse  );
    repeat
      c := KeyGet;
      if not fTerminate then begin
        case c of
          ' '..'~' : begin
                       s := s + c;
                       if fXCurr < fXMax then Inc( fXCurr );
                       XY( fXCurr, fYMax );
                     end;
           CtrlC    : s := c;
           TAB      : s := c;
           ESC      : s := c;
        end;  // case c
      end;  // if not fTerminate
    until fTerminate or ( c = CR ) or ( c = CtrlC ) or ( c = ESC ) or ( c = TAB );  // repeat
    XYSA( 1, fYMax, fBlank, taInverse );
    XY( 2, fYMax );
    LineGet := s;
  end;  // tConsole.LineGet


  function  tConsole.Menu( s : string ) : char;
    // Displays menu.  CAPITAL letter in items are valid reponses
  var
    c    : string;
    caps : string;
    i    : integer;
  begin
    caps := '';                                                         // This will hold valid responses
    XYSA( 1, fYMax, fBlank, taInverse );                                // Blank out last line
    for i := 1 to length( s ) do begin                                  // Loop through each character of menu
      if s[ i ] in [ 'A'..'Z' ] then begin                              // If char is uppercase 
        caps := caps + uppercase( s[ i ] );                             // Remember it
        XYSA( i + 1, fYMax, s[ i ], taInvBold );                        // Write out bold
      end else XYSA( I + 1, fYMax, s[ i ], taInverse );                 // Or not
    end;
    fXCurr := i + 3;
    XY( fXCurr, fYMax );                                                // Park cursor
    repeat                                                              // Wait for key
      c := uppercase( KeyGet );
    until ( Pos( c, caps ) > 0 ) or fTerminate;                         // Stop looping when valid response is found
    XYSA( fXCurr, fYMax, c, taInverse );                                // write out key
    Menu := c[ 1 ];
  end;  // tConsole.Menu


  procedure tConsole.Ping;
    // Puts ping time on line one
  var
    s : string;
  begin
    DateTimeToString( s, 'HH:MM ', Now );
    XYSA( 2, 1, 'Ping: ' + s, taInvBold );
    XY( 1, fYMax );
  end;  // tConsole.Ping

  
  procedure tConsole.Scroll;
    // Scroll main window up one line
  begin
    XY( 1, 2 );
    write( ESC, '[1M'  );
  end;  // tConsole.Scroll

 
  procedure tConsole.Send
  ( s : string; a : tAttribute );
    // Writes a line of text to the screen.  Only printable characters please
  const
    delim = ' ,.:;' + CR;
  var
    blk   : string;    // Blank, same length as time
    blkln : integer;   // tab length
    out   : string;    // Current output line
    stop  : integer;   // 
    time  : string;    // Now
  begin
    EnterCriticalSection( fMutex );
    Attribute ( a );                          
    Window( 2, fYMax - 1 );                                                    // Make the middle window active
    XY( 1, fYMax - 1 );
    DateTimeToString( time, 'HH:MM ', Now );                                   // Get current time
    blk   := copy( fBlank, 1, length( time ) );                                // Make tab same length as time for multi line s
    blkln := length( blk );
    out   := '';
    s     := trim( s );
    repeat                                                                     // Start to parse out line
      if length( out ) = 0
        then out := time                                                       //   Add time leader
        else out := blk;                                                       //   Or add blanks 
      if length( s ) + blkln > fXMax then begin                                // Is line too long?
        stop := fXMax - blkln;
        while ( stop > 0 ) and ( Pos( s[ stop ], delim ) = 0 ) do dec( stop ); // Find nice place to chop line
        if stop > 0 then begin
          out := out + copy( s, 1, stop );
          s   := copy( s, stop + 1, length( s ) );
        end else begin
          out := out + copy( s, 1, fXMax - blkln );
          s   := copy( s, fXMax - blkln + 1, length( s ) );
        end;
      end else begin
        out := out + s;
        s   := '';
      end;
      Scroll;
      XY( 1, fYMax - 1 );
      write( out );  
    until length( s ) = 0;
    Window( 1, fYMax );
    XY( 2, fYMax );
    LeaveCriticalSection( fMutex );
  end;  // tConsole.Send


  procedure TConsole.Terminate;
    // Signals keyboard loop to terminate 
  begin
    fTerminate := TRUE;
  end;  // tConsole.Terminate


  procedure tConsole.Window( t, b : integer );
    // Create Window region for top line t to bottom line b
  begin
    write( ESC, '[', t, ';', b, 'r' );
  end;  // tConsole.Window

  
  procedure tConsole.XY( x, y : integer );
    // Position cursor at X, Y with 1,1 as upper left origin
  begin
    write( ESC, '[', y, ';', x, 'H' );
  end;  // tConsole.XY


  procedure tConsole.XYSA( x, y : integer; const s : string; a : tAttribute );
  begin
    XY( x, y );
    Attribute( a );
    write( s );
  end;  // tConsole.XYSA


  function tConsole.YesNo( s : string ) : boolean;
    // Asks yes/question and awaits Y, y, N, n response.  No RETURN is needed
  var
    c : string;
  begin
    XYSA( 1, fYMax, fBlank , taInverse );
    XYSA( 2, fYMax, s + '[ / ]', taInverse );
    XYSA( length( s ) + 3, fYMax, 'Y', taInvBold );
    XYSA( length( s ) + 5, fYMax, 'N', taInvBold );
    fXCurr := length( s ) + 8;
    XY( fXCurr, fYMax );
    repeat
      c := KeyGet;
    until ( Pos( c, 'yYnN' ) > 0 ) or fTerminate;
    if c[ 1 ] in [ 'y', 'Y' ] then begin
      XYSA( length( s ) + 8, fYMax, 'Y', taInvBold );
      YesNo := TRUE;
    end else begin
      XYSA( length( s ) + 8, fYMax, 'N', taInvBold );
      YesNo := FALSE;
    end;
  end; // tConsole.YesNo


end.  // sConsole 
