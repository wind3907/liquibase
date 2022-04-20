CREATE OR REPLACE TRIGGER swms.trg_sts_route_out_ins
BEFORE INSERT OR UPDATE ON swms.sts_route_out
FOR EACH ROW
WHEN (NEW.SPLITFLAG is not null)
DECLARE
------------------------------------------------------------------------------
-- Table:
--    sts_route_out
--
-- Description:
--    This trigger 
--    added or updated.
--
-- Exceptions raised:
--    
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    
--    
------------------------------------------------------------------------------


            
BEGIN

   If :NEW.SPLITFLAG = 'Y' then 
  
    :new.in_route_split_mode := 'Y';
	
   Else 	
   
    :new.in_route_split_mode := 'D';
	
  End if;	
    
END trg_sts_route_out_ins;
/ 
