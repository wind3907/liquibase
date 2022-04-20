/****************************************************************************
** File:
**    R47_DDL_xdock_Jira3380_OP_site_1_build_pallets.sql
**
** Description:
**    Project: R1 Cross docking  (Xdock)
**             R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
**
**    This file has the DDL to create/modify objects necessary for the changes to 
**    the order generation process at Site 1 for the Xdock project
**
**    Objects created/modified by this DDL script:
**       - Create sequence XDOCK_ORDD_SEQ  
**
**    The ORDD.SEQ needs to be unique at Site 2 (last mile site).
**    This is what we will do at Site 1 (fulfullment site) to ensure the ORDD.SEQ is unique at Site 2.
**    Create a 5 digit sequence called XDOCK_ORDD_SEQ
**       START WITH 10000
**       MAXVALUE   99999
**       MINVALUE   10000
**       CYCLE
**       CACHE 20
**       ORDER;
**    Create a function to return the ordd.seq for document type 'S' orders.
**    The function will return:  XDOCK_ORDD_SEQ.NEXTVAL || TO_NUMBER(LPAD(TRIM(opco#), 3, '0'))  -- opco# is the Site 1 opco number
**    The programs that insert into ORDD changed to use this function for ORDD.SEQ
**
**    In order to keep the ordd.seq unique at Site 2 between regular orders and
**    cross dock orders--either S or X--the ordd.seq for regular orders cannot end in a OpCo number.
**    So the function that returns the ordd.seq will not return an ordd.seq
**    that ends in a OpCo number for a regular order.
**    Example:
**       Site 1 OpCos are 002 and 037
**       Site 2 OpCo is 016
**       Site 2 is going to get two cross dock orders from 002 and 037.
**       Site 2 is sending one cross dock to some OpCo (Site 2 can also be a Site 1)
**          ordd.seq from Site 1 Opco 002    ordd.seq from Site 1 Opco 027     ordd.seq Site 2 is sending out
**          ----------------------------     ------------------------------    --------------------------------
**          80001002                         80001027                          80001016
**          80002002                         80002027
**          80003002                    
**          80004002
**
**      So for regulars orders at Site 2 these values are not available to use for the ordd.seq
**      as they are used by the above cross dock orders.
**          80001002, 80001027, 80001016
**          80002002, 80002027
**          80003002                    
**          80004002
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/12/21 bben0556 Brian Bent
**                      R1 cross dock.
**                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
**                      Created this file.
**
**
** 
****************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED.


DECLARE
   l_file_name   VARCHAR2(100) := 'R47_DDL_xdock_Jira3380_OP_site_1_build_pallets.sql';
   l_stmt        VARCHAR2(3000);
   l_count       PLS_INTEGER;

   ----------------------------------------------------
   -- Local procedure to create a table.
   ----------------------------------------------------
   PROCEDURE execute_stmt_create_table(i_stmt IN VARCHAR2)
   IS
      e_table_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_table_already_exists, -955);
   BEGIN
      EXECUTE IMMEDIATE (i_stmt);
   EXCEPTION
      WHEN e_table_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END;

   -------------------------------------------------------
   -- Local procedure to create a primary key on a table.
   -- ORA-02260: table can have only one primary key
   -------------------------------------------------------
   PROCEDURE execute_stmt_create_pk(i_stmt IN VARCHAR2)
   IS
      e_pk_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_pk_already_exists, -2260);
   BEGIN
      EXECUTE IMMEDIATE (i_stmt);
   EXCEPTION
      WHEN e_pk_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END;


   ----------------------------------------------------
   -- Local procedure to add a column to a table.
   ----------------------------------------------------
   PROCEDURE execute_stmt_add_col(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt_add_col;

BEGIN
   --------------------------------------------------------------------------
   -- Create sequence XDOCK_ORDD_SEQ
   --------------------------------------------------------------------------
   BEGIN
      SELECT COUNT(*)
        INTO l_count 
        FROM dba_sequences
       WHERE sequence_owner  = 'SWMS'
         AND sequence_name   = 'XDOCK_ORDD_SEQ';

      IF (l_count = 0) THEN
         l_stmt := 'CREATE SEQUENCE swms.xdock_ordd_seq
                      INCREMENT BY 1
                      START WITH   10000
                      MINVALUE     10000
                      MAXVALUE     99999
                      CYCLE
                      CACHE        20
                      ORDER';
         EXECUTE IMMEDIATE(l_stmt);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE(SQLERRM);
   END;

END;
/

