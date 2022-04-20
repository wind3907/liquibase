CREATE OR REPLACE PACKAGE SWMS.pl_purge_stagetable
AS

   -- sccs_id=@(#) src/schema/plsql/pl_purge_stagetable.sql, 
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_purge_stagetable
   --
   -- Description:
   --    Purging the records in the staging tables for SAP OpCo
   --
   -- Modification History:
   --    Date     Designer        Comments
   --    -------- --------        -----------------------------------------------------
   --    07/03/09 ykri0358        Created.
   --    07/15/15 Sunil Ontipalli Modified to handle timestamps and also modified to properly handle exception.
   --
   -----------------------------------------------------------------------------
    
   PROCEDURE swms_purge_stagetable;

END pl_purge_stagetable;
/

--*************************************************************************
--Package Body

--*************************************************************************

CREATE OR REPLACE PACKAGE BODY SWMS.pl_purge_stagetable
AS

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- PROCEDURE
--    swms_purge_stagetable
--
-- Description:
--     This procedure purges the data from the staging table based on the 
--     number of retention days given in sap_interface_purge table
--
-- Parameters:
--      None
--
-- Exceptions Raised:
--      None
--
-- Modification History:
--    Date     Designer        Comments
--    -------- --------        --------------------------------------------------- 
--    06/23/10 ykri0358        Created.
--    07/15/15 Sunil Ontipalli Modified to handle timestamps and also modified to properly handle exception.
-----------------------------------------------------------------------------                                   

PROCEDURE swms_purge_stagetable

IS

purge_date date;
query VARCHAR2(200);
i_count number;
message VARCHAR2(70);

BEGIN
 
    FOR i_index in (SELECT table_name, retention_days FROM SAP_INTERFACE_PURGE)
    
    LOOP
       
      BEGIN	   
        message := i_index.table_name || ' - PURGE OLD DATA FAILED';
        
        purge_date := to_date(to_char(sysdate,'DD-MON-YY'),'DD-MON-YY') - (i_index.retention_days - 1);
        
        query := 'DELETE FROM ' || i_index.table_name || ' WHERE to_date(to_char(add_date,''DD-MON-YY''), ''DD-MON-YY'') < ''' ||  purge_date || '''' ;
        
        EXECUTE IMMEDIATE query;
        
        COMMIT;
	  EXCEPTION
	   WHEN OTHERS THEN
	    pl_log.ins_msg('FATAL', 'swms_purge_stagetable', message, SQLCODE, SQLERRM, NULL, NULL, 'Y');
	  END;
            
    END LOOP;
    
EXCEPTION

    WHEN OTHERS THEN
        
        pl_log.ins_msg('FATAL', 'swms_purge_stagetable', message, SQLCODE, SQLERRM, NULL, NULL, 'Y');
 
END swms_purge_stagetable;

END pl_purge_stagetable;
/