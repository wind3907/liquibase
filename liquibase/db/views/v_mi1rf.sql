------------------------------------------------------------------------------
--
-- View:
--    v_mi1rf
--
-- Description:
--    This view is used in the mi1rf.sql   
--
-- Used by:
--    Report mi1rf.sql
--
-- Modification History:
--    Date      Designer     Comments
--    --------  --------     ---------------------------------------------------
--     9/22/14  Vani Reddy   Created.  
--    10/28/14  Vani Reddy   Modified to add 5 more fields              
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_mi1rf
AS
SELECT p.mx_eligible, 
       p.mx_item_assign_flag,
       p.prod_id,
	   p.descrip,
       pl_common.f_get_first_pick_slot(p.prod_id, '-',null,null) home,
       p.mx_upc_present_flag,
       p.mx_multi_upc_problem, 
       p.mx_food_type,
       p.mx_master_case_flag, 
	   p.brand, 
	   p.pack, 
	   p.prod_size, 
	   p.prod_size_unit,
       p.mx_package_type,
       p.mx_hazardous_type,    
       p.case_length,
       p.case_width,
       p.case_height,
       p.cust_pref_vendor ,
       p.mx_stability_flag,
       p.WSH_AVG_INVS,
       p.WSH_SHIP_MOVEMENTS,
       p.WSH_HITS,
       p.EXPECTED_CASE_ON_PO,
       p.DIAGONAL_MEASUREMENT,
       p.area,
       p.container,
       p.auto_ship_flag,
       p.g_weight,
       p.spc
  FROM  pm p; 

CREATE OR REPLACE PUBLIC SYNONYM v_mi1rf FOR SWMS.v_mi1rf;

GRANT ALL ON SWMS.v_mi1rf TO SWMS_USER;

GRANT SELECT ON SWMS.v_mi1rf TO SWMS_VIEWER;                         
