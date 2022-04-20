CREATE OR REPLACE TRIGGER trg_ins_upd_chk_po_pm
-----------------------------------------------------------------------------------------
   -- trg_ins_upd_chk_pm.sql
   --
   -- Description:
   --     This script contains a trigger which deletes the data from temporary table which
   --     is user_downloaded_po for Caching Logic.
   --
   -- Modification History: 
   --    Date      Designer        Comments
   --    --------- --------        -------------------------------------------
   --    24-Feb-17 Sunil Ontipalli Created as part of the Live Receiving.
------------------------------------------------------------------------------------------
AFTER INSERT or UPDATE
ON swms.pm
FOR EACH ROW
DECLARE
l_count     NUMBER;
BEGIN

     IF INSERTING THEN
		    delete from user_downloaded_po where (user_id = user or prod_id = :NEW.prod_id);
     END IF;

     IF UPDATING THEN  
		IF :NEW.internal_upc <> :OLD.internal_upc OR :NEW.external_upc <> :OLD.external_upc THEN
		     delete from user_downloaded_po where (user_id = user or prod_id = :NEW.prod_id);  
        END IF;
     END IF;

EXCEPTION
WHEN OTHERS
THEN
RAISE;
END trg_ins_upd_chk_po_pm;
/