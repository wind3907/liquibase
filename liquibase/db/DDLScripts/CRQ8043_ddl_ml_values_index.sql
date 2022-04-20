----------------------------------------------------------------------------------------------
-- Date:       26-AUG-2016
-- File:       CRQ8043_indexes.sql
--
--            Script for creating indexes : ORA-01450: maximum key length (3215) exceeded” 
--                                          during online SWMS.IDX_ML_VALUES_TEXT index rebuild.
--
--   - SCRIPT
--
--    Modification History:
--    Date      	Designer Comments
--    --------  	-------- --------------------------------------------------- **    
--    26-AUG-2016 	vvar7800 CRQ8043
--                  	Project: CRQ8043_ddl_ml_values_index.sql  
--  		        Need indexes on ORA-01450: maximum key length (3215) exceeded” 
--                                           during online SWMS.IDX_ML_VALUES_TEXT index rebuild.
-------------------------------------------------------------------------------------------------/


DROP INDEX IDX_ML_VALUES_TEXT;


