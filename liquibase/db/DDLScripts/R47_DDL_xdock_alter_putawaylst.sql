/****************************************************************************
** File:       r47_jira3490_alter_putawaylst_ddl.sql
**
** Desc: this creates a column XDOCK_SHIP_CONFIRM in putawaylst & putawaylst_hist table,  
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    Aug24th 2021  apri0734          one xdock related column added to table putawaylst
**    Feb23th 2022  kchi7065      Story 3960 one xdock related column added to table putawaylst_hist
**       
****************************************************************************/

DECLARE
  v_column_exists1 NUMBER := 0; 
  l_column_name varchar2(40);
  l_table_name varchar2(40);
  BEGIN
    l_column_name := 'XDOCK_SHIP_CONFIRM';
    l_table_name := 'PUTAWAYLST';
  
    SELECT COUNT(*)
    INTO v_column_exists1
    FROM user_tab_cols
    WHERE column_name = l_column_name
    AND table_name = l_table_name;

    IF (v_column_exists1 = 0)   THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.'||l_table_name||' ADD '||l_column_name||' VARCHAR2(1)';
      dbms_output.put_line ('Column '||l_column_name||' on table '||l_table_name||' created. ');
    ELSE 
      dbms_output.put_line ('Column '||l_column_name||' on table '||l_table_name||' already exists. ');
    END IF;
 
    l_table_name := 'PUTAWAYLST_HIST';
    SELECT COUNT(*)
    INTO v_column_exists1
    FROM user_tab_cols
    WHERE column_name = l_column_name
    AND table_name = l_table_name;
 
    IF (v_column_exists1 = 0)   THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.'||l_table_name||' ADD '||l_column_name||' VARCHAR2(1)';
      dbms_output.put_line ('Column '||l_column_name||' on table '||l_table_name||' created. ');
    ELSE 
      dbms_output.put_line ('Column '||l_column_name||' on table '||l_table_name||' already exists. ');
    END IF;
 
 END;
/ 

