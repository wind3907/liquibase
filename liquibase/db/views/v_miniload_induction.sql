-----------------------------------------------------------------------         
-- v_miniload_induction.sql                                                 
--                                                                              
-- Description:                                                                 
--     This script contains the list of view that are required 
--	   for HK Warehouse Automation Integration.
--                                                                              
-- Modification History:                                                        
--    Date      Designer Comments                                               
--    --------- -------- ---------------------------------------------------    
--    22-Nov-07 CTVGG000 Created as part of the Miniload changes                
---------------------------------------------------------------------------

CREATE OR REPLACE VIEW SWMS.V_MINILOAD_INDUCTION AS
 SELECT DISTINCT LOGI_LOC, ML_SYSTEM FROM LOC
 WHERE ML_SYSTEM IS NOT NULL 
 AND   ML_SYSTEM != 'SWMS'
 AND   SLOT_TYPE = 'MLS'
 AND   LOGI_LOC LIKE '%0000'
 ORDER BY ML_SYSTEM;

CREATE OR REPLACE PUBLIC SYNONYM V_MINILOAD_INDUCTION FOR SWMS.V_MINILOAD_INDUCTION;

