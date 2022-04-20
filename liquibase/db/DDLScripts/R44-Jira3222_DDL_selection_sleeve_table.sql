
set serveroutput on size unlimited;
set linesize 240;
set tab off;
set trimspool on;

/****************************************************************************
**
** Description:
**    Create table SELECTION_SLEEVE and associated indexes.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    10/30/20 bben0556 Brian Bent
**                      Project: R44-Jira3222_Sleeve_selection
**                      Created.
**    01/05/21 bben0556 Brian Bent
**                      Change sleeve_id length from 15 to 11 as STS has a
**                      maximum of 11 characters for a barcode.
**
****************************************************************************/

DECLARE

   l_file_name  VARCHAR2(200) := '"R44-Jira3222_DDL_selection_sleeve_table.sql"';  -- Used in error messages
   l_stmt VARCHAR2(30000);

   ----------------------------------------------------
   -- Local procedure to check if an index already exists
   ----------------------------------------------------
   FUNCTION does_index_exists
                (i_owner      IN VARCHAR2,
                 i_index_name IN VARCHAR2)
   RETURN BOOLEAN
   IS
      l_count  NUMBER;
   BEGIN
      SELECT COUNT(*) INTO l_count
        FROM dba_indexes idx
       WHERE idx.owner      = UPPER(i_owner)
         AND idx.index_name = UPPER(i_index_name);

      IF (l_count = 1) THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error in "does_index_exists" in file ' || l_file_name
             || '  i_owner[' || i_owner || ']   i_index_name[' || i_index_name || ']');
      RAISE;
   END does_index_exists;

   ----------------------------------------------------
   -- Local procedure to check if a table already exists
   ----------------------------------------------------
   FUNCTION does_table_exists
                (i_owner      IN VARCHAR2,
                 i_table_name IN VARCHAR2)
   RETURN BOOLEAN
   IS
      l_count  NUMBER;
   BEGIN
      SELECT COUNT(*) INTO l_count
        FROM dba_tables t
       WHERE t.owner      = UPPER(i_owner)
         AND t.table_name = UPPER(i_table_name);

      IF (l_count = 1) THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error in "does_table_exists" in file ' || l_file_name
             || '  i_owner[' || i_owner || ']   i_table_name[' || i_table_name || ']');
   END does_table_exists;


   --------------------------------------------------------------------------
   -- Local procedure to check if a constraint already exists on a table
   --------------------------------------------------------------------------
   FUNCTION does_constraint_exist
                 (i_owner            IN VARCHAR2,
                  i_table_name       IN VARCHAR2,
                  i_constraint_name  IN VARCHAR2)
   RETURN BOOLEAN
   IS
      l_count  NUMBER;
   BEGIN
      SELECT COUNT(*) INTO l_count
        FROM all_constraints t
       WHERE t.owner           = UPPER(i_owner)
         AND t.table_name      = UPPER(i_table_name)
         AND t.constraint_name = UPPER(i_constraint_name);

      IF (l_count = 1) THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error in "does_constraint_exist" in file ' || l_file_name
             || ' i_owner['           || i_owner           || ']'
             || ' i_table_name['      || i_table_name      || ']'
             || ' i_constraint_name[' || i_constraint_name || ']');
   END does_constraint_exist;


   -----------------------------------------------------------------
   -- Local procedure to execute stmt to add a column to a table.
   -----------------------------------------------------------------
   PROCEDURE execute_stmt_add_col(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN
         NULL;
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE(SQLERRM);
         RAISE;
   END execute_stmt_add_col;

   ----------------------------------------------------
   -- Local procedure to execute a stmt
   ----------------------------------------------------
   PROCEDURE execute_stmt(i_stmt  IN VARCHAR2)
   IS
   BEGIN
     EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE(SQLERRM);
         DBMS_OUTPUT.PUT_LINE(i_stmt);
         DBMS_OUTPUT.PUT_LINE('Error in "execute_stmt" in file ' || l_file_name
             || '  i_stmt[' || i_stmt || ']');
   END execute_stmt;

BEGIN

   -------------------------------------------
   -- Create table SWMS.SELECTION_SLEEVE
   -------------------------------------------
   IF (does_table_exists(i_owner => 'swms', i_table_name => 'selection_sleeve') = FALSE)
   THEN
      l_stmt :=
          'CREATE TABLE swms.selection_sleeve
          (
             sleeve_id                 VARCHAR2(11 CHAR)                               NOT NULL,  -- primary key
             descrip                   VARCHAR2(50 CHAR),
             active_flag               VARCHAR2(1 CHAR),                                          -- Valid values are NULL, Y or N.  If N then the sleeve cannot be assigned to a float-zone.
                                                                                                  -- 11/01/2020 We will see if this gets used
             add_date                  DATE              DEFAULT SYSDATE               NOT NULL,
             add_user                  VARCHAR2(30)      DEFAULT REPLACE(USER, ''OPS$'') NOT NULL,
             upd_date                  DATE,                                                      -- Populated by DB trigger
             upd_user                  VARCHAR2(30)                                               -- Populated by DB trigger
          )
          TABLESPACE swms_dts2
          STORAGE (INITIAL 64K NEXT 1M PCTINCREASE 0)
          PCTFREE 5';

      execute_stmt(l_stmt);
   END IF;

   --------------------------------------------------------------------------
   -- Create primary key on table SELECTION_SLEEVE
   --------------------------------------------------------------------------
   IF (does_index_exists(i_owner => 'swms', i_index_name => 'selection_sleeve_pk') = FALSE)
   THEN
      l_stmt := 
         'ALTER TABLE swms.selection_sleeve ADD CONSTRAINT selection_sleeve_pk
            PRIMARY KEY (sleeve_id)
            USING INDEX
                TABLESPACE SWMS_ITS1
                STORAGE (INITIAL 64K NEXT 64K PCTINCREASE 0)
                PCTFREE 5';

      execute_stmt(l_stmt);
   END IF;

   --------------------------------------------------------------------------
   -- Create check constraints on table SELECTION_SLEEVE.
   --------------------------------------------------------------------------
   IF (does_constraint_exist(i_owner => 'swms', i_table_name => 'selection_sleeve', i_constraint_name => 'selection_sleeve_active_flag') = FALSE)
   THEN
      l_stmt := 
          'ALTER TABLE swms.selection_sleeve ADD CONSTRAINT selection_sleeve_active_flag
          CHECK (active_flag IN (''N'', ''Y''))';

      execute_stmt(l_stmt);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(SQLERRM);
      DBMS_OUTPUT.PUT_LINE('Error in ' || l_file_name);
END;
/


GRANT ALL    ON swms.selection_sleeve TO swms_user;
GRANT SELECT ON swms.selection_sleeve TO swms_viewer;
CREATE OR REPLACE PUBLIC SYNONYM selection_sleeve FOR swms.selection_sleeve;



