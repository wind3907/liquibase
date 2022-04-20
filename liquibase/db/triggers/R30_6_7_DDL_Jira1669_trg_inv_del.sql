CREATE OR REPLACE TRIGGER swms.trg_inv_del
AFTER DELETE ON swms.inv
FOR EACH ROW

DECLARE
------------------------------------------------------------------------------
-- Table:
--    swms.inv
-- Description:
--    This trigger 
--    added or updated.
-- Exceptions raised:  
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------  
------------------------------------------------------------------------------
  l_err_msg  VARCHAR2(500);           
BEGIN

INSERT into INV_CASES_HIST
       (PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,ALLOCATE_IND, ADD_USER,ADD_DATE,UPD_USER,UPD_DATE)
(SELECT PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,ALLOCATE_IND, ADD_USER,ADD_DATE,UPD_USER,UPD_DATE 
 FROM inv_cases 
 WHERE PROD_ID = :old.PROD_ID 
 AND LOGI_LOC = :old.LOGI_LOC
 AND rec_ID = :old.rec_ID);

 DELETE  from INV_CASES a
 WHERE PROD_ID = :old.PROD_ID 
 AND LOGI_LOC = :old.LOGI_LOC
 AND rec_ID = :old.rec_ID;
 
 Exception when others then 
  l_err_msg := 'Trigger trg_inv_del FAILED. ' ||
                    'Prod_id = [' || :NEW.prod_id || '] ' ||
                    'Po_no = [' || :NEW.rec_id || '] ' ||
                    'Order_id = [' || :NEW.inv_order_id || ']' ;
       pl_log.ins_msg('FATAL', 'trg_inv_del', l_err_msg, SQLCODE, SQLERRM);
    
END trg_inv_del;
/ 
