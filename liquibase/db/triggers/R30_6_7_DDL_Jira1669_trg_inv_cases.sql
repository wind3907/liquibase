CREATE OR REPLACE TRIGGER swms.trg_inv_cases_ins
AFTER INSERT ON swms.inv_cases
FOR EACH ROW

DECLARE
------------------------------------------------------------------------------
-- Table:
--    swms.inv_cases
-- Description:
--    This trigger 
--    added or updated.
-- Exceptions raised:
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
------------------------------------------------------------------------------
 l_spc number;
 l_err_msg  VARCHAR2(500);
 
 
BEGIN

Begin
   select nvl(spc,1) into l_spc 
   from pm
   where PROD_ID = :new.PROD_ID;
Exception when others then
 l_spc := 1;
End;   

Update INV a
set a.sigma_qty_produced = (nvl(a.sigma_qty_produced,0)+1*l_spc)
WHERE PROD_ID = :new.PROD_ID 
AND LOGI_LOC = :new.LOGI_LOC
AND rec_ID = :new.rec_ID;

Exception when others then 
  l_err_msg := 'Trigger trg_inv_cases_ins FAILED. ' ||
                    'Prod_id = [' || :NEW.prod_id || '] ' ||
                    'Po_no = [' || :NEW.rec_id || '] ' ||
                    'Order_id = [' || :NEW.order_id || '] ' ||
                    'Box_id = [' || :NEW.box_id || ']';
       pl_log.ins_msg('FATAL', 'trg_inv_cases_ins', l_err_msg, SQLCODE, SQLERRM);
    
END trg_inv_cases_ins;
/ 
