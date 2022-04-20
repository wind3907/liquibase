SET ECHO OFF
SET SCAN OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** Date:       30-nov-2021
** File:       Brakes_DDL_Story_3880_add_col_multi_split.sql
**
**             Script to add the columns to SEL_EQUIP
**
**    - SQL Script
**
**    To undo issue the following command. 
**      alter table SWMS.SEL_EQUIP drop column MULTI_SPLIT_NO;
**      alter table SWMS.T_CURR_BATCH drop column MULTI_SPLIT_NO;
**      alter table SWMS.T_CURR_BATCH_SHORT drop column MULTI_SPLIT_NO;
**    Modification History:
**    Date         Designer  Comments
**    -----------  --------  -----------------------------------------------------
**    30-nov-2021  kchi7065  Created
**********************************************************************************
*/
DECLARE
  K_This_Script             CONSTANT  VARCHAR2(50 CHAR) := 'Brakes_DDL_Story_3561_add_col_multi_split.sql';

  Column_Already_Exists EXCEPTION;
  PRAGMA Exception_Init (Column_Already_Exists, -01430);

  l_count binary_integer;

  PROCEDURE add_col ( p_owner VARCHAR2,
                      p_table_name VARCHAR2, 
                      p_column_name VARCHAR2, 
                      p_data_type VARCHAR2)
  IS
    l_sql varchar2(200);
    l_results binary_integer;

  BEGIN

    l_sql := 'ALTER TABLE '||p_owner||'.'||p_table_name||' ADD ( '||p_column_name||' '||p_data_type||' )';  
    l_results := pl_utility.execute_ddl(l_sql);
  
    if ( l_results <> 0 ) then 

        Dbms_Output.Put_Line( K_This_Script || ' had an error. ' );

      elsif ( l_results = 0 ) then 

        Dbms_Output.Put_Line( 'Column '||p_column_name||' added to '||p_table_name||'. ' );

    end if;
  
  END add_col;

BEGIN
  ------------------------------
  -- Add column to SWMS.SEL_EQUIP --
  ------------------------------
  BEGIN
    -- Add MULTI_SPLIT_NOf column
    Dbms_Output.Put( K_This_Script || ': Column addition SWMS.SEL_EQUIP.MULTI_SPLIT_NO ' );

    add_col ( 'SWMS',
              'SEL_EQUIP', 
              'MULTI_SPLIT_NO', 
              'NUMBER(3,0)');

    Dbms_Output.Put_Line( K_This_Script || ' completed. ' );

  EXCEPTION
    WHEN Column_Already_Exists THEN
      Dbms_Output.Put_Line( '- Already Exists.' );
    WHEN OTHERS THEN
      Dbms_Output.Put_Line( '- Failed, ' || SQLERRM );
  END;

  ------------------------------
  -- Add column to SWMS.t_curr_batch --
  ------------------------------
  BEGIN
    -- Add MULTI_SPLIT_NOf column
    Dbms_Output.Put( K_This_Script || ': Column addition SWMS.SEL_EQUIP.MULTI_SPLIT_NO ' );

    add_col ( 'SWMS',
              'T_CURR_BATCH', 
              'MULTI_SPLIT_NO', 
              'NUMBER(3,0)');

    Dbms_Output.Put_Line( K_This_Script || ' completed. ' );

  EXCEPTION
    WHEN Column_Already_Exists THEN
      Dbms_Output.Put_Line( '- Already Exists.' );
    WHEN OTHERS THEN
      Dbms_Output.Put_Line( '- Failed, ' || SQLERRM );
  END;

  ------------------------------
  -- Add column to SWMS.t_curr_batch_short --
  ------------------------------
  BEGIN
    -- Add MULTI_SPLIT_NO column
    Dbms_Output.Put( K_This_Script || ': Column addition SWMS.SEL_EQUIP.MULTI_SPLIT_NO ' );

    add_col ( 'SWMS',
              'T_CURR_BATCH_SHORT', 
              'MULTI_SPLIT_NO', 
              'NUMBER(3,0)');

    Dbms_Output.Put_Line( K_This_Script || ' completed. ' );

  EXCEPTION
    WHEN Column_Already_Exists THEN
      Dbms_Output.Put_Line( '- Already Exists.' );
    WHEN OTHERS THEN
      Dbms_Output.Put_Line( '- Failed, ' || SQLERRM );
  END;

END;
/
