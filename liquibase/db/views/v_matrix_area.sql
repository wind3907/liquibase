
------------------------------------------------------------------------------
--
-- View:
--    v_matrix_area
--
-- Description:
--    This view is used in the mi1se.fmb   
--
-- Modification History:
--    Date      Designer     Comments
--    --------  --------     ---------------------------------------------------
--    9/22/14   Vani Reddy   Created.  
--                      
--------------------------------------------------------------------------------
--DROP VIEW SWMS.V_MATRIX_AREA;

CREATE OR REPLACE FORCE VIEW SWMS.V_MATRIX_AREA
(AREA, ZONE, ZONE_TYPE, LOCATION)
AS 
SELECT z_area_code area, 
       zone_id zone, 
       zone_type, 
       induction_loc location 
 FROM zone 
 WHERE rule_id = 5
 AND ZONE_TYPE = 'PUT';


CREATE OR REPLACE PUBLIC SYNONYM V_MATRIX_AREA FOR SWMS.V_MATRIX_AREA;


GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.V_MATRIX_AREA TO SWMS_USER;

GRANT SELECT ON SWMS.V_MATRIX_AREA TO SWMS_VIEWER;