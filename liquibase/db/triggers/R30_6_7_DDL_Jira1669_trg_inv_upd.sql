CREATE OR REPLACE TRIGGER swms.trg_inv_upd
BEFORE UPDATE ON swms.inv
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
 
 l_qoh number;
 l_err_msg  VARCHAR2(500);
 l_cas_to_del number :=0;
 l_spc number;
            
BEGIN


Begin
   select nvl(spc,1) into l_spc 
   from pm
   where PROD_ID = :old.PROD_ID;
Exception when others then
 l_spc := 1;
End;   

 if :new.QOH < :old.QOH and :new.QOH < :old.sigma_qty_produced then 
 
 
 l_qoh := :old.qoh - :new.qoh;
 
 l_cas_to_del := round ((l_qoh/l_spc ),0);
 
 If l_cas_to_del > 0 then
 
 :new.sigma_qty_produced := :old.sigma_qty_produced - l_qoh;
 
  
 For i in 1 .. l_cas_to_del loop 

   INSERT into INV_CASES_HIST
          (PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE)
   (SELECT PROD_ID ,REC_ID,ORDER_ID,BOX_ID,PACK_DATE,WEIGHT,UPC,LOGI_LOC,ADD_USER,SYSDATE,UPD_USER,SYSDATE 
    FROM inv_cases 
    WHERE PROD_ID = :old.PROD_ID 
    AND LOGI_LOC = :old.LOGI_LOC
    AND REC_ID = :old.rec_ID
    AND BOX_ID = (select max(box_id) 
                  from inv_cases 
                  WHERE PROD_ID = :old.PROD_ID 
                  AND LOGI_LOC = :old.LOGI_LOC
                  AND REC_ID = :old.REC_ID));

    DELETE  from INV_CASES a
    WHERE PROD_ID = :old.PROD_ID 
    AND LOGI_LOC = :old.LOGI_LOC
    AND REC_ID = :old.REC_ID
    AND BOX_ID = (select max(box_id) 
                  from inv_cases 
                  WHERE PROD_ID = :old.PROD_ID 
                  AND LOGI_LOC = :old.LOGI_LOC
                  AND REC_ID = :old.REC_ID);
    
 End Loop;
 
 End If;
 
 End If;
 
 Exception when others then 
  l_err_msg := 'Trigger trg_inv_upd FAILED. ' ||
                    'Prod_id = [' || :NEW.prod_id || '] ' ||
                    'Po_no = [' || :NEW.rec_id || '] ' ||
                    'Order_id = [' || :NEW.inv_order_id || ']' ;
       pl_log.ins_msg('FATAL', 'trg_inv_upd', l_err_msg, SQLCODE, SQLERRM);
    
END trg_inv_del;
/ 
