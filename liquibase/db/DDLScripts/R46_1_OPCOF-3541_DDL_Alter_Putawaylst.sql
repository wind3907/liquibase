SET ECHO OFF
/* *****************************************************************************
Script:   R46_1_OPCOF-3541_DDL_Alter_Putawaylst.sql
Purpose:  Ensure creation of the OSD_LR_Reason_Cd column on the PUTAWAYLST table.
History:
  Date       By       CRQ/Project Description
  ---------- -------- ----------- ----------------------------------------------
  09/28/2021 bgil6182 OPCOF-3541  Created script.
***************************************************************************** */
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  This_Script                    CONSTANT VARCHAR2(100 CHAR) := 'R46_1_OPCOF-3541_DDL_Alter_Putawaylst.sql';

  K_Table_Owner                  CONSTANT all_tab_columns.owner%TYPE       := UPPER( 'swms' );
  K_Table_Name                   CONSTANT all_tab_columns.table_name%TYPE  := UPPER( 'putawaylst' );
  K_Column_Name                  CONSTANT all_tab_columns.column_name%TYPE := UPPER( 'OSD_LR_Reason_Cd' );
  K_Data_Type_Options            CONSTANT VARCHAR2(100 CHAR) := 'VARCHAR2(3 CHAR)';

  DDL_Stmt                                VARCHAR2(2000 CHAR);
  ErrCode                                 NUMBER;
  ErrText                                 VARCHAR2(4000 CHAR);

  FUNCTION Column_Exists( i_Owner      IN VARCHAR2
                        , i_TableName  IN VARCHAR2
                        , i_ColumnName IN VARCHAR2 ) RETURN BOOLEAN IS
    l_count     NATURAL;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM all_tab_columns c
     WHERE c.owner       = i_Owner
       AND c.table_name  = i_TableName
       AND c.column_name = i_ColumnName;

    RETURN( l_count > 0 );
  END Column_Exists;

BEGIN
  IF ( K_Table_Owner IS NULL OR K_Table_Name IS NULL OR K_Column_Name IS NULL ) THEN
    IF ( K_Table_Owner IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "K_Table_Owner".' );
    END IF;
    IF ( K_Table_Name IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "K_Table_Name".' );
    END IF;
    IF ( K_Column_Name IS NULL ) THEN
      DBMS_Output.Put_Line( This_Script || ': missing required argument "K_Column_Name".' );
    END IF;
  ELSE
    DBMS_Output.Put( This_Script || ': Adding table column ' || K_Table_Owner || '.' || K_Table_Name || '.' || K_Column_Name );
    IF Column_Exists( K_Table_Owner, K_Table_Name, K_Column_Name ) THEN
      DBMS_Output.Put_Line( ' skipped, already exists.' );
    ELSE
      DDL_Stmt := 'ALTER TABLE ' || K_Table_Owner || '.' || K_Table_Name
               || ' ADD ' || '( ' || K_Column_Name || ' ' || K_Data_Type_Options || ')';
      EXECUTE IMMEDIATE ( DDL_Stmt );
      DBMS_Output.Put_Line( ' succeeded.' );
    END IF;   /* Table column existence check */
  END IF;   /* Required arguments check */
EXCEPTION
  WHEN OTHERS THEN
    ErrCode := SQLCODE;
    ErrText := SQLERRM;
    DBMS_Output.Put_Line( ' ' );  -- Echo newline
    DBMS_Output.Put     ( 'Exception occurred while executing "' );
    DBMS_Output.Put_Line( DDL_Stmt || '", ' || ErrText );
    ROLLBACK;
    RAISE;
END;
/
