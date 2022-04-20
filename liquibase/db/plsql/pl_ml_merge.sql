
set serveroutput on size unlimited;
set pagesize 50000;
set linesize 25000;
set tab off;
set trimspool on;

-------------------------------------------------------------------------
-- Procedure:
--    p_merge
--
-- Description:
--    This script creates procedure "p_merge" that moves the records from
--    the miniloader HDO staging table to the SWMS HDO staging table.
--
--    It is called by shell script "/swms/curr/bin/ml_int.sh" which is run by cron.
--
--    There are three different versions of p_merge that can be created based on
--       - Miniloader using ORACLE
--       - Miniloader using SQLQERVER and not OpCo 024.
--       - Miniloader using SQLSERVER and it is OpCo 024.
--    Each version is stored in a variable and depending on the OpCo the
--    appropriate version is run.
--
--    The miniloader database affects how we select/insert/delete the records in the
--    miniloader staging tables.  We cannot do a 2 phase commit when
--    the miniloader is using SQLSERVER.  We have to do the action on the
--    miniloader staging table then commit then do the action on the
--    SWMS staging table and commit.
--
--    02/25/2020 Brian Bent
--    NOTE  When the miniloader switched to SQLSERVER I hacked up
--    pl_ml_split.sql and pl_ml_merge.sql to get them working with SQLSERVER
--    They are not pretty but they do work.
--

-- -------------------------------------------------------------------------
-- As of 14-FEB-2020 these are the miniloader OpCos
-- --------------------------------------------------------------------------
-- 26 OpCos have a miniloader. They are listed below along with the
-- database the miniloader(Oracle or SQL SERVER) system is using.
-- The miniloader database affects how we connect to the miniloader 
-- database as SWMS reads/write to/from 2 staging tables on the
-- miniloader database.
--
-- OPCO OPCO_NAME          Address                                                  Miniloader DB
-- ----------------------------------------------------------------------------------------------
-- 005  Intermountain      Sysco Intermountain                                      SQLSERVER
--                         9494 South Prosperity Road-West Jordan, Utah    84088
-- 
-- 007  Virginia           SYSCO Food Services of Virginia, LLC.                    SQLSERVER
--                         5081 South Valley Pike, Harrisonburg, VA 22801
-- 
-- 009  Pittsburgh         Sysco Food Services of Pittsburgh, LLC                   SQLSERVER
--                         One Whitney Drive, Harmony,  PA,  16037
-- 
-- 013  San Antonio        Sysco Food Services of Central Texas, LP                 SQLSERVER
--                         1260 Schwab Road, New Braunfels, TX, 78132
-- 
-- 024  Chicago            Sysco Food Services-Chicago                              SQLSERVER
--                         250 Wieboldt Drive, Des Plaines, Il 60016
-- 
-- 027  Syracuse           SYSCO Food Services Syracuse                             SQLSERVER
--                         RT 173 Warners, NY 13164
-- 
-- 031  Sacramento         Sysco Sacramento Inc                                     SQLSERVER
--                         7062 Pacific Avenue, Pleasant Grove, CA 95668
-- 
-- 036  San Diego          Could not find an address                                SQLSERVER
-- 
-- 050  San Francisco      Sysco San Francisco                                      SQLSERVER
--                         5900 Stewart Ave Fremont, CA 94538
-- 
-- 052  Portland           SYSCO-PORTLAND                                           SQLSERVER
--                         26250 SW Parkway Center Dr., Wilsonville, OR  97070
--
-- 056  Boston             Sysco Boston                                             SQLSERVER
--                         99 Spring Street Plympton, MA, 02367
--
-- ********** Detroit not longer uses it **********
-- 058  Detroit            Sysco Food Services of Detroit                           Oracle
--                         41600 Van Born, Canton, MI. 48188
--
-- 061  Lincoln            SYSCO Lincoln                                            SQLSERVER
--                         900 Kingbird Road, Lincoln, NE  68521
--
-- 067  Houston            SYSCO FOOD SERVICES OF HOUSTON, LP                       SQLSERVER
--                         10710 GREENS CROSSING TX 77038 SSL#TX 2074 SS
--
-- 073  Hampton Roads      Sysco Foodservices of Hampton Roads                      Oracle
--                         7000 Harbour View Blvd. Suffolk Va.
--
-- 075  Philadelphia       Sysco Food Services of Philadelphia, LLC                 SQLSERVER
--                         600 Packer Ave.  Philadelphia, PA  19148
--
-- 137  Columbia           SYSCO Food Services of Columbia,LLC                      SQLSERVER
--                         131 SYSCO Court,Columbia,SC,29209
--
-- 139  Victoria           Sysco Foodservice of Victoria                            Oracle
--                         2881 Amy Rd. Victoria, BC V9B 0B2
--
-- ********** 11/29/2019 About 4 months OpCo 163 took out their miniloader **********
-- 163  Raleigh            Sysco Food Services of Raleigh                           Oracle
--                         1032 Baugh Rd Selma, NC 27576
--
-- 288  Knoxville          SYSCO Knoxville                                          SQLSERVER
--                         900 Tennessee Avenue Knoxville, TN  37921 - 2630
--
-- 049  Arizona            Sysco Food Services of Arizona                           SQLSERVER
--                         611 South 80th Avenue Tolleson, Arizona 85353
--
-- 293  EAST TEXAS         SYSCO Food Services of East Texas                        SQLSERVER
--                         4577 Estes Parkway, Longview, TX 75603
--
-- 306  Long Island        Sysco Long Island                                        SQLSERVER
--                         199 Lowell Avenue, Central Islip, NY  11722
--
-- 320  Riverside          Sysco Riverside 320                                      SQLSERVER
--                         15750 Meridian Blvd. Riverside, CA 92507 Phone# 951-601-5300
--
-- 338  SW Ontario         Sysco Foodservice South West Ontario                     SQLSERVER
--                         1515 Commerce Way, Woodstock ON, N4V 0C3
--
-- 026  Oklahoma           Sysco Oklahoma                                           SQLSERVER
--                         1350 W. Tecumseh Road, Norman, OK 73069
--
-- 349  Pallas             Pallas Foods Dublin                                      SQLSERVER
--                         The Ward Co. Dublin
--
--
-- Parameters:
--		None
--
-- Exceptions raised:
--		None
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/26/07 ctvgg000 Created as part of the HK Automation
--
--    02/15/20 bben0556 Brian Bent
--                      Project:
--      R30.6.9-Jira-OPCOF-2830-Combine_multiple_p_split_and_p_merge_scripts_into_one_that_handle_oracle_or_sqlserver
--
--                      Changed to handle the miniloader using SQLSERVER
--                      database and special handling of OpCo 024.
--                      There were issues with OpCo 024 when the miniloader
--                      switched to SQLSERVER so 024 has different insert
--                      and delete statements.
--                      As I remember it the issue with 024 had to do with how
--                      the Oracle Heterogeneous Services configuration user
--                      and password were setup.
--                      
--                      What we will do is create the appropriate verson of "p_merge"
--                      based on:
--                      - Miniloader using ORACLE
--                      - Miniloader using SQLQERVER and not OpCo 024.
--                      - Miniloader using SQLSERVER and it is OpCo 024.
--
--                      What we had been doing is having different "pl_ml_merge.sql"
--                      for ORACLE, SQLSERVER and OpCo 024 which caused issues
--                      after a SWMS upgrade as we had to be sure to run the correct
--                      "pl_ml_merge.sql" after the upgrade.  This was a manual process.
--                      If the miniloader was using ORACLE database then the upgrade
--                      did not cause any issues.
--
--    06/23/20 bben0556 Brian Bent
--                      Project:
--      R30.6.9-Jira-OPCOF-2830-Combine_multiple_p_split_and_p_merge_scripts_into_one_that_handle_oracle_or_sqlserver
--
--                      Make script installable on a test box that has a miniloader OpCo data.
--                      The install on rs053a, the old Jamestown box, was failing.  This happened
--                      because rs053a has OpCo's 306 data per the MAINTENANCE table.
--                      Opco 306 has a miniloader and is using SQLSERVER so pl_ml_split.sql and
--                      pl_ml_merge.sql are expecting the miniloader synonyms to exist at install
--                      time which they don't on rs053.  So what we will do is check the hostname
--                      and if not a production box then create p_split and p_merge as we originally did which
--                      will always install successfully as the miniloader synonyms are only looked
--                      at at run time.
---------------------------------------------------------------------------

DECLARE
   l_file_name       VARCHAR2(20) := 'pl_ml_merge.sql';

   l_ml_database     VARCHAR2(20);
   l_sqlstmt_to_run  VARCHAR2(25000);


   ------------------------------------------------------------------------
   -- SQL stmt to create procedure p_merge when miniloader using ORACLE
   ------------------------------------------------------------------------
   l_sqlstmt_oracle  VARCHAR2(25000) :=
'CREATE OR REPLACE PROCEDURE swms.p_merge
IS
   CURSOR c_ml_config
   IS
   SELECT * FROM miniload_config order by ml_system;
 
   sqlStmt VARCHAR2(1000);
BEGIN
   DBMS_OUTPUT.PUT_LINE(''Executing p_merge, miniloader using ORACLE...'');

   FOR c1 IN c_ml_config
   LOOP
      DBMS_OUTPUT.PUT_LINE('' ***** Writing to HDO FROM '' || c1.ml_system || '' ***** '');
				
      sqlStmt := ''insert into HDO (hdo_id, source_hdo_id, creation_timestamp, length, data, ml_system) (select hdo_id_sequence.nextval, temp.* from (select hdo_id, creation_timestamp, length, data,'' || '''''''' || c1.ml_system || '''''''' || ''from '' || c1.ml_swms_synonym || '' order by hdo_id) temp) '';												

      EXECUTE IMMEDIATE sqlStmt;

      DBMS_OUTPUT.PUT_LINE('' ***** Deleting from '' || c1.ml_system || '' ***** '');
      sqlStmt := ''delete from '' || c1.ml_swms_synonym || '' where 
         hdo_id <= (select max(source_hdo_id) from HDO where ml_system=''|| '''''''' || c1.ml_system || '''''''' ||'')'';

      EXECUTE IMMEDIATE sqlStmt;

   END LOOP;

   COMMIT;	

END p_merge;';


   -----------------------------------------------------------------------------
   -- SQL stmt to create procedure p_merge when miniloader using SQLSERVER
   -- and it is not OpCo 024
   -----------------------------------------------------------------------------
   l_sqlstmt_sqlserver  varchar2(25000) :=
'CREATE OR REPLACE PROCEDURE swms.p_merge
IS
   l_first_hdo_id                NUMBER := NULL;
   l_last_hdo_id                 NUMBER;
   l_number_of_records_inserted  PLS_INTEGER;

   CURSOR c_ml_config IS
      SELECT ml_system, ml_swms_synonym
       FROM miniload_config
      ORDER BY ml_system;
  
	sqlStmt VARCHAR2(1000);

   CURSOR c_hdo IS
        SELECT hdo_id,
               creation_timestamp,
               length,
               data
          FROM hdo_hk1
         ORDER BY hdo_id;

BEGIN
   DBMS_OUTPUT.PUT_LINE(''Executing p_merge, miniloader using SQLSERVER and it is not OpCo 024...'');

   l_number_of_records_inserted := 0;

   FOR c1 IN c_ml_config LOOP
      DBMS_OUTPUT.PUT_LINE('' ***** Writing to SWMS HDO FROM '' || c1.ml_system || '' ***** '');

      FOR r_hdo IN c_hdo LOOP
         INSERT INTO hdo
                 (hdo_id,
                  source_hdo_id,
                  creation_timestamp,
                  length, data,
                  ml_system)
          VALUES (hdo_id_sequence.nextval,
                  r_hdo.hdo_id,
                  r_hdo.creation_timestamp,
                  r_hdo.length,
                  r_hdo.data,
                  c1.ml_system);
 
         IF (l_first_hdo_id IS NULL) THEN
            l_first_hdo_id :=  r_hdo.hdo_id;
         END IF;

         l_last_hdo_id  := r_hdo.hdo_id;
         l_number_of_records_inserted := l_number_of_records_inserted + 1;

      END LOOP;

      DBMS_OUTPUT.PUT_LINE(''Before COMMIT of insert to SWMS HDO table'');
      COMMIT;	
      DBMS_OUTPUT.PUT_LINE(''After COMMIT of insert to SWMS HDO table'');

      DBMS_OUTPUT.PUT_LINE(''l_number_of_records_inserted: '' || TO_CHAR(l_number_of_records_inserted));
      DBMS_OUTPUT.PUT_LINE(''l_first_hdo_id: '' || TO_CHAR(l_first_hdo_id));
      DBMS_OUTPUT.PUT_LINE(''l_last_hdo_id: '' || TO_CHAR(l_last_hdo_id));

      DBMS_OUTPUT.PUT_LINE(''Before DELETE from hdo_hk1'');
      DELETE FROM hdo_hk1 WHERE hdo_id BETWEEN l_first_hdo_id AND l_last_hdo_id;
      DBMS_OUTPUT.PUT_LINE(''SQL%ROWCOUNT: '' || SQL%ROWCOUNT);
      DBMS_OUTPUT.PUT_LINE(''After DELETE from hdo_hk1'');

      COMMIT;	

   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(sqlStmt);
      DBMS_OUTPUT.PUT_LINE(sqlerrm);
      ROLLBACK;
--    RAISE;
END p_merge;';


   --------------------------------------------------------------------------------
   -- SQL stmt to create procedure p_merge when miniloader using SQLSERVER
   -- and it is OpCo 024
   --------------------------------------------------------------------------------
   l_sqlstmt_sqlserver_024  varchar2(25000) :=
'CREATE OR REPLACE PROCEDURE swms.p_merge
IS
   l_first_hdo_id                NUMBER := NULL;
   l_last_hdo_id                 NUMBER;
   l_number_of_records_inserted  PLS_INTEGER;
   l_number_of_records_deleted   PLS_INTEGER;


   CURSOR c_ml_config IS
      SELECT ml_system, ml_swms_synonym
       FROM miniload_config
      ORDER BY ml_system;
  
   sqlStmt VARCHAR2(1000);

   /*********
   CURSOR c_hdo IS
        SELECT hdo_id,
               creation_timestamp,
               length,
               data
          FROM hdo_hk1
         ORDER BY hdo_id;
    *********/

   TYPE r_hdo IS RECORD
   (
      hdo_id                hdo.hdo_id%TYPE,
      creation_timestamp    hdo.creation_timestamp%TYPE,
      length                hdo.length%TYPE,
      data                  hdo.data%TYPE
   );

   TYPE type_r_hdo_table IS TABLE OF r_hdo
       INDEX BY BINARY_INTEGER;

     t_r_hdo   type_r_hdo_table;

BEGIN
   DBMS_OUTPUT.PUT_LINE(''Executing p_merge, miniloader using SQLSERVER and it is OpCo 024...'');

   l_number_of_records_inserted := 0;
	
   FOR c1 IN c_ml_config LOOP
      DBMS_OUTPUT.PUT_LINE('' ***** Writing to SWMS HDO FROM '' || c1.ml_system || '' ***** '');

     sqlStmt :=
       ''SELECT hdo_id,
               creation_timestamp,
               length,
               data
          FROM hdo@hk1.world
         ORDER BY hdo_id'';

      EXECUTE IMMEDIATE (sqlStmt) bulk collect into t_r_hdo;

      DBMS_OUTPUT.PUT_LINE(''t_r_hdo.COUNT:''  || to_char(t_r_hdo.COUNT));

       FOR i IN 1..t_r_hdo.COUNT LOOP
          DBMS_OUTPUT.PUT_LINE(t_r_hdo(i).hdo_id || ''   '' || t_r_hdo(i).data);

         INSERT INTO hdo
                 (hdo_id,
                  source_hdo_id,
                  creation_timestamp,
                  length,
                  data,
                  ml_system)
          VALUES (hdo_id_sequence.NEXTVAL,
                  t_r_hdo(i).hdo_id,
                  t_r_hdo(i).creation_timestamp,
                  t_r_hdo(i).length,
                  t_r_hdo(i).data,
                  c1.ml_system);

         IF (l_first_hdo_id IS NULL) THEN
            l_first_hdo_id :=  t_r_hdo(i).hdo_id;
         END IF;

         l_last_hdo_id  := t_r_hdo(i).hdo_id;
         l_number_of_records_inserted := l_number_of_records_inserted + 1;

       END LOOP;

      DBMS_OUTPUT.PUT_LINE(''l_number_of_records_inserted: '' || TO_CHAR(l_number_of_records_inserted));
      DBMS_OUTPUT.PUT_LINE(''Before COMMIT of insert to SWMS HDO table'');

      COMMIT;	

      DBMS_OUTPUT.PUT_LINE(''After COMMIT of insert to SWMS HDO table'');
      DBMS_OUTPUT.PUT_LINE(''l_first_hdo_id: '' || TO_CHAR(l_first_hdo_id));
      DBMS_OUTPUT.PUT_LINE(''l_last_hdo_id: '' || TO_CHAR(l_last_hdo_id));

      IF (l_first_hdo_id IS NOT NULL) THEN
         pl_log.ins_msg(''INFO'', ''p_merge'',
                   ''After inserting into swms HDO from hdo_hk1  l_first_hdo_id: '' || TO_CHAR(l_first_hdo_id)
                || ''  l_last_hdo_id: ''  || TO_CHAR(l_last_hdo_id)
                || ''  l_number_of_records_inserted: '' || TO_CHAR(l_number_of_records_inserted),
                 sqlcode, null, ''INV'', ''p_merge'');
      END IF;

      DBMS_OUTPUT.PUT_LINE(''Before DELETE from hdo_hk1'');

      sqlStmt := ''DELETE FROM hdo_hk1 WHERE hdo_id BETWEEN :first_hdo_id AND :last_hdo_id'';
      DBMS_OUTPUT.PUT_LINE(sqlStmt);

      EXECUTE IMMEDIATE (sqlStmt) USING l_first_hdo_id, l_last_hdo_id;

      DBMS_OUTPUT.PUT_LINE(''After DELETE from hdo_hk1'');
      DBMS_OUTPUT.PUT_LINE(''SQL%ROWCOUNT: '' || SQL%ROWCOUNT);

      l_number_of_records_deleted := SQL%ROWCOUNT;
      COMMIT;	

-- old stuff    DELETE FROM hdo_hk1 WHERE hdo_id BETWEEN l_first_hdo_id AND l_last_hdo_id;

      IF (l_first_hdo_id IS NOT NULL) THEN
         pl_log.ins_msg(''INFO'', ''p_merge'',
                   ''after deleting from hdo_hk1  l_first_hdo_id: '' || TO_CHAR(l_first_hdo_id)
                || ''  l_last_hdo_id: ''               || TO_CHAR(l_last_hdo_id)
                || ''  l_number_of_records_deleted: '' || TO_CHAR(l_number_of_records_deleted),
                 sqlcode, null, ''INV'', ''p_merge'');
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(sqlStmt);
      DBMS_OUTPUT.PUT_LINE(sqlerrm);
      ROLLBACK;
--    RAISE;
END p_merge;';



------------------------------------------------------------------------
-- Local Function:
--    get_company_no
--
-- Description:
--    This function returns the company number from the MAINTENANCE
--    table.
--
-- Parameters:
--    None
--
-- Return Value:
--    OpCo number.  Examples: 001 056 203
--
-- Exceptions raised:
--    The exception will be propagated out.
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    02/15/20 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_company_no
RETURN VARCHAR2
IS
   l_company_no  maintenance.attribute_value%TYPE;

   CURSOR c_company_no
   IS
   SELECT TRIM(SUBSTR(attribute_value,
                         1, INSTR(attribute_value, ':') -1))
     FROM maintenance
    WHERE component = 'COMPANY'
      AND attribute = 'MACHINE';
BEGIN
   OPEN c_company_no;
   FETCH c_company_no INTO l_company_no;
   IF (c_company_no%NOTFOUND) THEN
      l_company_no := NULL;
   END IF;
   CLOSE c_company_no;

   RETURN (l_company_no);
END get_company_no;


------------------------------------------------------------------------
-- Local Function:
--    get_ml_database
--
-- Description:
--    This function returns the database the miniloader is using.
--
--    The database affects how we select/insert/delete the records in the
--    miniloader staging tables.  We cannot do a 2 phase commit when
--    the miniloader is using SQLSERVER.  We have to do the action on the
--    miniloader staging table then commit then do the action on the
--    SWMS staging table and commit.
--
-- Parameters:
--    None
--
-- Return Value:
--    ORACLE
--    SQLSERVER_024    -- OpCo 024 has a little different processing.
--    SQLSERVER
--
-- Exceptions raised:
--    The exception will be propagated out.
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    02/15/20 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_ml_database
RETURN VARCHAR2
IS
   l_opco_num       VARCHAR2(30);
   l_ml_database    VARCHAR2(20);
BEGIN
   l_opco_num := get_company_no;
   DBMS_OUTPUT.PUT_LINE(l_file_name || ': l_opco_num: ' || l_opco_num);

   IF (l_opco_num IN ('005', '007', '009', '013', '026', '027', '031', '036', '049', '050',
                      '052', '056', '061', '067', '075', '137', '288', '293', '306', '320',
                      '338', '349'))
   THEN
      l_ml_database  := 'SQLSERVER';
   ELSIF (l_opco_num = '024') THEN
      l_ml_database  := 'SQLSERVER_024';
   ELSIF (l_opco_num IN ('058', '139', '073')) THEN
      l_ml_database  := 'ORACLE';
   ELSE
      l_ml_database  := 'ORACLE';  -- Default to ORACLE
      DBMS_OUTPUT.PUT_LINE(l_file_name || ': OpCo not a minloader OpCo.  Default to ORACLE');
   END IF;

   DBMS_OUTPUT.PUT_LINE(l_file_name || ': l_ml_database: ' || l_ml_database);

   RETURN (l_ml_database);
END get_ml_database;


------------------------------------------------------------------------
-- Local Function:
--    is_production_box
--
-- Description:
--    Return TRUE if the box is a production box otherwise FALSE.
--    The box name comes from HOST_NAME in V$INSTANCE.
--
--    A box is considered a production box if the box name:
--       Starts with "rs" or "lx".
--       Followed by 3 digts.
--       Ends with "a" or "e".
--     Exception is rs053a and rs053e, old Jamestown box. which is not
--     a production box.
--
-- Parameters:
--    None
--
-- Return Value:
--    TRUE
--    FALSE
--
-- Exceptions raised:
--    The exception will be propagated out.
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    06/23/20 bben0556 Created.
------------------------------------------------------------------------
FUNCTION is_production_box
RETURN BOOLEAN
IS
   l_host_name      VARCHAR2(500);
BEGIN
   SELECT host_name
     INTO l_host_name
     FROM v$instance;

   DBMS_OUTPUT.PUT_LINE('pl_ml_merge.sql: l_host_name: ' || l_host_name);

   IF (    (REGEXP_LIKE(l_host_name, '^rs\d{3}a$') OR REGEXP_LIKE(l_host_name, '^rs\d{3}e$') OR
            REGEXP_LIKE(l_host_name, '^lx\d{3}a$') OR REGEXP_LIKE(l_host_name, '^lx\d{3}e$'))
       AND l_host_name NOT IN ('rs053a', 'rs053e'))
   THEN
       RETURN TRUE;
   ELSE
       RETURN FALSE;
   END IF;
END is_production_box;


BEGIN
   --
   -- If not a production box then default to oracle.
   --
   IF (is_production_box = FALSE) THEN
      DBMS_OUTPUT.PUT_LINE('pl_ml_merge.sql:  Not a production box.');
      l_ml_database := 'ORACLE';
   ELSE
      l_ml_database := get_ml_database;
   END IF;

   --
   -- The miniloader database determines what procedure is called
   -- to move the message from the miniloader HDO staging table to the
   -- SWMS HDO staging table.
   --
   IF (l_ml_database = 'SQLSERVER') THEN
      l_sqlstmt_to_run := l_sqlstmt_sqlserver;
      DBMS_OUTPUT.PUT_LINE(l_file_name || ': Create procedure p_merge for SQLSERVER and it is not OpCo 024');
   ELSIF (l_ml_database = 'SQLSERVER_024') THEN
      l_sqlstmt_to_run := l_sqlstmt_sqlserver_024;
      DBMS_OUTPUT.PUT_LINE(l_file_name || ': Create procedure p_merge for SQLSERVER and it is OpCo 024');
   ELSIF (l_ml_database  = 'ORACLE') THEN
      l_sqlstmt_to_run := l_sqlstmt_oracle;
      DBMS_OUTPUT.PUT_LINE(l_file_name || ': Create procedure p_merge for ORACLE');
   ELSE
      l_sqlstmt_to_run := l_sqlstmt_oracle;   -- Default is oracle. as this will always compile.
      DBMS_OUTPUT.PUT_LINE(l_file_name || ': Default  Create procedure p_merge for ORACLE');
   END IF;


   ------------DBMS_OUTPUT.PUT_LINE(l_sqlstmt_to_run);

   --
   -- If creating p_merge fails output a message.  Do not raise an exception.
   -- Reasons it could fail is when the miniloader is using SQLSERVER and
   -- database link hk1.world does not exist or synonym hdo_hk1 does not exist
   -- or tnsmames.ora does not have the correct entries.
   -- On a test box these probably do not exist.
   -- Note that when creating p_merge when the miniloader database is ORACLE should
   -- always success because the sql is created dynamically.
   --
   BEGIN
      EXECUTE IMMEDIATE(l_sqlstmt_to_run);
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE(l_file_name || ': Error creating p_merge');
         DBMS_OUTPUT.PUT_LINE(l_file_name || ': Reasons for error is when the miniloader is using SQLSERVER and'
                      || ' database link hk1.world does not exist or synonym hdo_hk1 does not exist'
                      || ' or tnsmames.ora does not have the correct entries.');
         DBMS_OUTPUT.PUT_LINE(SQLERRM);
   END;
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error running ' || l_file_name);
      DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/


-- set back to "normal" values
set pagesize 30;
set linesize 100;

