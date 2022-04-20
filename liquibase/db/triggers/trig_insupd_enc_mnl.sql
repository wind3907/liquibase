--------------------------------------------------------------------
-- trig_insupd_enc_mnl.sql
--                                                                              
-- Description:                                                                 
--     This script contains a trigger which encrypts the password 
--     column of the miniload_config table.
--                                                                              
-- Modification History:                                                        
--    Date      Designer Comments                                               
--    --------- -------- -------------------------------------------
--    3-Jan-07 CTVGG000 Created as part of the HK Integration                
--------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRIG_INSUPD_ENC_MNL 
BEFORE INSERT OR UPDATE ON MINILOAD_CONFIG
FOR EACH ROW
DECLARE
BEGIN
 :new.password:= pl_ml_enc.encrypt(:new.password);
END;
/
