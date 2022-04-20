CREATE OR REPLACE PACKAGE SWMS.PL_Sysco_Msg AS

  SUBTYPE Media_Method      IS NUMBER(1,0);

  MedMeth_Window     CONSTANT  Media_Method  := 1;
  MedMeth_DB_Table   CONSTANT  Media_Method  := 2;

  SUBTYPE MessageLevelType  IS NUMBER(1,0);
  SUBTYPE MediaDomain_Type  IS VARCHAR2(200);
  SUBTYPE MediaName_Type    IS VARCHAR2(60);

  MsgLvl_Debug      CONSTANT  MessageLevelType  := 1;
  MsgLvl_Info       CONSTANT  MessageLevelType  := 2;
  MsgLvl_Warning    CONSTANT  MessageLevelType  := 3;
  MsgLvl_Error      CONSTANT  MessageLevelType  := 4;
  MsgLvl_Severe     CONSTANT  MessageLevelType  := 5;
  MsgLvl_Fatal      CONSTANT  MessageLevelType  := 6;

  MedMeth_Default  CONSTANT  Media_Method       := MedMeth_Window;
  MsgLvl_Default   CONSTANT  MessageLevelType   := MsgLvl_Error;

  G_This_Package        CONSTANT  VARCHAR2(30)  := 'PL_Sysco_Msg';
  

  PROCEDURE Debug_On( i_Level IN  MessageLevelType  DEFAULT MsgLvl_Default );

  PROCEDURE Debug_Off;

  FUNCTION Is_Dbg_Enabled RETURN BOOLEAN;

  FUNCTION Is_Dbg_Disabled RETURN BOOLEAN;

  PROCEDURE Enable_Media( i_Method  IN Media_Method
                        , i_Name    IN MediaName_Type   DEFAULT NULL
                        , i_Domain  IN MediaDomain_Type DEFAULT NULL );

  PROCEDURE Disable_Media( i_Method  IN Media_Method
                         , i_Name    IN MediaName_Type   DEFAULT NULL
                         , i_Domain  IN MediaDomain_Type DEFAULT NULL );

  PROCEDURE Msg_Out( i_Level        IN MessageLevelType
                   , i_ModuleName   IN VARCHAR2
                   , i_Message      IN VARCHAR2
                   , i_Category     IN VARCHAR2
                   , i_Add_DB_Msg   IN BOOLEAN  DEFAULT TRUE
                   , i_ProgramName  IN VARCHAR2 DEFAULT G_This_Package );

 /* PROCEDURE Run_All_Unit_Tests;*/
END PL_Sysco_Msg;
/

SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY SWMS.PL_Sysco_Msg AS
  G_Debugging                BOOLEAN;
  G_DebugLevel               MessageLevelType;

  TYPE Media_Type IS RECORD
    ( Method  Media_Method
    , Domain  MediaDomain_Type
    , Name    MediaName_Type
    , Enabled BOOLEAN
    );

  TYPE Media_List IS TABLE OF Media_Type INDEX BY BINARY_INTEGER;

  Media                      Media_List;

  FUNCTION Media_Type_Init( p_Method  IN  Media_Method
                          , p_Name    IN  MediaName_Type
                          , p_Domain  IN  MediaDomain_Type  DEFAULT NULL
                          , p_Active  IN  BOOLEAN           DEFAULT FALSE
                              ) RETURN Media_Type IS
    this Media_Type;
  BEGIN
    this.Method  := p_Method;
    this.Name    := p_Name;
    this.Domain  := p_Domain;
    this.Enabled := p_Active;
    RETURN( this );
  END Media_Type_Init;

  PROCEDURE Initialize IS
  BEGIN
    G_Debugging  := TRUE;
    G_DebugLevel := MsgLvl_Default;

    -- Media(MedMeth_Window)   := Media_Type_Init( p_Method => MedMeth_Window
    --                                           , p_Domain => NULL  , p_Name => 'StandardOutput'
    --                                           , p_Active => TRUE );
    Media(MedMeth_DB_Table) := Media_Type_Init( p_Method => MedMeth_DB_Table
                                              , p_Domain => 'SWMS', p_Name => 'SWMS_LOG' );
  END Initialize;

  PROCEDURE Debug_On( i_Level IN  MessageLevelType  DEFAULT MsgLvl_Default ) IS
  BEGIN
    G_Debugging  := TRUE;
    G_DebugLevel := i_Level;
    DBMS_Output.Enable( Buffer_Size => 1000000 );
    RETURN;
  END Debug_On;

  PROCEDURE Debug_Off IS
  BEGIN
    G_Debugging  := FALSE;
    G_DebugLevel := MsgLvl_Default;
    DBMS_Output.Disable;
    RETURN;
  END Debug_Off;

  FUNCTION Is_Dbg_Enabled RETURN BOOLEAN IS
  BEGIN
    RETURN( G_Debugging );
  END Is_Dbg_Enabled;

  FUNCTION Is_Dbg_Disabled RETURN BOOLEAN IS
  BEGIN
    RETURN( NOT G_Debugging );
  END Is_Dbg_Disabled;

  PROCEDURE Enable_Media( i_Method  IN Media_Method
                        , i_Name    IN MediaName_Type   DEFAULT NULL
                        , i_Domain  IN MediaDomain_Type DEFAULT NULL ) IS
  BEGIN
   IF i_Domain IS NOT NULL THEN
    IF ( i_Domain <> Media(i_Method).Domain ) THEN
      Media(i_Method).Domain := i_Domain;
    END IF;
   END IF;

   IF i_Name IS NOT NULL THEN
    IF ( i_Name <> Media(i_Method).Name ) THEN
      Media(i_Method).Name := i_Name;
    END IF;
   END IF;


-- Before marking enabled, perform I/O initialization if necessary
--    IF ( i_Method = MedMeth_File ) THEN
--      utl_file.fopen( Media(i_Method).Domain, Media(i_Method).Name, 'W', --
--    END IF;

    Media(i_Method).Enabled := TRUE;
  END Enable_Media;

  PROCEDURE Disable_Media( i_Method  IN Media_Method
                         , i_Name    IN MediaName_Type   DEFAULT NULL
                         , i_Domain  IN MediaDomain_Type DEFAULT NULL ) IS
  BEGIN
-- if file then close
    Media(i_Method).Enabled := FALSE;
  END Disable_Media;

  PROCEDURE Send_Out( i_Level       IN MessageLevelType
                    , i_Message     IN VARCHAR2
                    , i_Module      IN VARCHAR2
                    , i_Add_DB_Msg  IN BOOLEAN ) IS
    i       PLS_INTEGER;
    v_Level VARCHAR2(20);
    DB_Code NUMBER;
    DB_Msg  VARCHAR2(4000);
  BEGIN
    IF i_Add_DB_Msg THEN
      DB_Code := SQLCODE;
      IF ( DB_Code <> 0 ) THEN
        DB_Msg := SQLERRM( SQLCODE );
      ELSE
        DB_Msg := NULL;
      END IF;
    ELSE
      DB_Code := NULL;
      DB_Msg  := NULL;
    END IF;

    v_Level := CASE i_Level
                  WHEN MsgLvl_Debug   THEN 'INFO'
                  WHEN MsgLvl_Info    THEN 'INFO'
                  WHEN MsgLvl_Warning THEN 'WARN'
                  WHEN MsgLvl_Error   THEN 'WARN'
                  WHEN MsgLvl_Severe  THEN 'FATAL'
                  WHEN MsgLvl_Fatal   THEN 'FATAL'
                  ELSE 'WARN'
               END;

    FOR i IN NVL(Media.First,0)..NVL(Media.Last,-1) LOOP
      IF Media(i).Enabled THEN
        CASE i
          WHEN MedMeth_Window THEN
            BEGIN
              DBMS_Output.Put_Line( i_Message );
              IF DB_Msg IS NOT NULL THEN
                DBMS_Output.Put_Line( '  ...SQL Error=' || TO_CHAR( DB_Code ) || ', ' || DB_Msg );
              END IF;
            END;
          WHEN MedMeth_DB_Table THEN
            PL_Log.Ins_Msg( v_Level, i_Module, i_Message, DB_Code, DB_Msg
                          , PL_RCV_Open_PO_Types.CT_Application_Function, G_This_Package, 'N' );
          ELSE
            PL_Log.Ins_Msg( v_Level, i_Module, 'Bad value for Media (' || TO_CHAR( i_Level ) || ')', DB_Code, DB_Msg
                          , PL_RCV_Open_PO_Types.CT_Application_Function, G_This_Package, 'N' );
        END CASE;
      END IF;
    END LOOP;
  END Send_Out;

  PROCEDURE Msg_Out( i_Level        IN MessageLevelType
                   , i_ModuleName   IN VARCHAR2
                   , i_Message      IN VARCHAR2
                   , i_Category     IN VARCHAR2
                   , i_Add_DB_Msg   IN BOOLEAN  DEFAULT TRUE
                   , i_ProgramName  IN VARCHAR2 DEFAULT G_This_Package
                   ) IS
    My_DB_Code  PLS_INTEGER   := SQLCODE;
    My_Header   VARCHAR2(300) := '';
  BEGIN
    IF ( G_Debugging AND i_Level >= G_DebugLevel ) THEN
      IF ( NVL( i_ModuleName, 'NULL' ) <> NVL( i_ProgramName, 'NULL' ) ) THEN
        My_Header := i_ProgramName || '.';
      END IF;
      IF ( i_ModuleName IS NOT NULL ) THEN
        My_Header := My_Header || i_ModuleName || '-';
      END IF;
      IF ( i_Category IS NOT NULL ) THEN
        My_Header := My_Header || i_Category || ': ';
      END IF;
      Send_Out( i_Level, My_Header || i_Message, i_ModuleName, i_Add_DB_Msg );
    END IF;
  END Msg_Out;

BEGIN
  Initialize;
END PL_Sysco_Msg;
/

SHOW ERRORS;


