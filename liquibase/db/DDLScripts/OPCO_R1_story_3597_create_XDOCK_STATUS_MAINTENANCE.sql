set serveroutput on 

/****************************************************************************
**  Create new table XDOCK_STATUS_MAINTENANCE
**
**
** Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    08/16/2021 kchi7065 Created.
**
**
****************************************************************************/
----------------------------
-- XDOCK_STATUS_MAINTENANCE --
----------------------------
-- Purpose:  If table already exists, then do nothing.
--           Otherwise, drop table, create table as latest version, create public sysnonym, grant access to roles
DECLARE
  n_count                   PLS_INTEGER;
  SQL_stmt                  VARCHAR2(2000 CHAR); 
  l_schema_name               VARCHAR2(30);
  l_table_name                VARCHAR2(30);
BEGIN
  l_schema_name := 'SWMS';
  l_table_name := 'XDOCK_STATUS_MAINTENANCE';
  SELECT COUNT(*)
    INTO n_count
    FROM all_objects
   WHERE object_type = 'TABLE'
     AND owner       = l_schema_name
     AND object_name = l_table_name;

  IF N_COUNT > 0 THEN
    DBMS_OUTPUT.PUT_LINE( 'Table '||l_schema_name||'.'||l_table_name||' found, skipping recreation...' );
  ELSE
    DBMS_OUTPUT.PUT_LINE( 'Table '||l_schema_name||'.'||l_table_name||' not found, creating now...' );

        SQL_stmt := 'CREATE TABLE '||l_schema_name||'.'||l_table_name||' '
                 ||'('
                 ||'  XDOCK_STATUS VARCHAR2(30) NOT NULL  '
                 ||', STATUS_TYPE VARCHAR2(30) NOT NULL '
                 ||', STATUS_DESC  VARCHAR2(400)  NOT NULL '
                 ||', SORT_BY NUMBER '
                 ||', ADD_USER VARCHAR2(30 CHAR)  NOT NULL '
                 ||', ADD_DATE DATE  NOT NULL '
                 ||', UPD_USER VARCHAR2(30 CHAR)  NOT NULL '
                 ||', UPD_DATE DATE  NOT NULL '
                 ||')';         
     EXECUTE IMMEDIATE SQL_stmt;

     SQL_stmt := 'ALTER TABLE '||l_schema_name||'.'||l_table_name||' ADD constraint pk_xdock_status PRIMARY KEY (XDOCK_STATUS, STATUS_TYPE)';
     EXECUTE IMMEDIATE SQL_stmt;
    
     SQL_stmt := 'CREATE OR REPLACE PUBLIC SYNONYM '||l_table_name||' FOR '||l_schema_name||'.'||l_table_name||' ';
     EXECUTE IMMEDIATE SQL_stmt;

     SQL_stmt := 'GRANT select, insert, update, delete ON '||l_schema_name||'.'||l_table_name||' TO swms_user'; 
     EXECUTE IMMEDIATE SQL_stmt;
     
     SQL_stmt := 'GRANT select ON '||l_schema_name||'.'||l_table_name||' TO swms_viewer';
     EXECUTE IMMEDIATE SQL_stmt;
     
   END IF;

END;
/    
