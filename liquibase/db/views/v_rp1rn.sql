------------------------------------------------------------------------------
--
-- Views:
--    V_RP1RN
--    V_RP1RN_FOOTER
--
-- Description:
--    These views are used to generate the Receiving Load Worksheet report.
--    The script that generates the report is rp1rn.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/17/16 bben0556 Brian Bent
--                      Project:
--          R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
--
--                      Created.
--
--
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_rp1rn
AS
SELECT maint.opco_number                                  opco_number,
       erm.load_no                                        load_no,
       erm.erm_id                                         erm_id,
       erm.status                                         status,
       erm.erm_type                                       erm_type,
       erm.door_no                                        door_no,
       erm.sched_date                                     sched_date,
       TO_CHAR(erm.sched_date, 'MM/DD/YY HH12:MI AM')     sched_date_text,
       TO_CHAR(erm.sched_date, 'YYYY/MM/DD HH24MISS')     sched_date_sort,
       SUM(DECODE(erd.uom, 1, 0, erd.qty / pm.spc))       cases,
       SUM(DECODE(erd.uom, 1, erd.qty, 0 ))               splits,
       --
       CEIL(SUM(DECODE(erd.uom, 1, erd.qty * pm.split_cube,
                                (erd.qty / pm.spc) * pm.case_cube))) cube,
       --
       CEIL(SUM(erd.qty * pm.g_weight))                 weight,
       --
       (SELECT COUNT(*) FROM putawaylst put WHERE put.rec_id = erm.erm_id) num_pallets,
       --
       (SELECT COUNT(*)
          FROM putawaylst p2, erm e2
         WHERE p2.rec_id = e2.erm_id
           AND e2.load_no = erm.load_no) number_of_pallets_on_load,
       --
       '*' || erm.erm_id || '*' barcode_erm_id,    -- Put barcode at end of line in the load
                                                   -- worksheet report because thats where
                                                   -- the filter program expects it.
       --
       -- 11/03/2016  Brian Bent Not sure how we will use these on the load worksheet.
       '*' || 'SY-' || maint.opco_number || '-' || DECODE(erm.erm_type, 'SN', 'RDP', 'RP') || '-' || erm.erm_id || '*' rp_barcode_erm_id,
       '*' || 'SY-' || maint.opco_number || '-' || DECODE(erm.erm_type, 'SN', 'RDP', 'RP') || '-' || erm.load_no || '*' rp_barcode_load_no,
       --
       (SELECT count(*)
          FROM erm erm2
         WHERE erm2.load_no = erm.load_no) number_of_pos_on_load,
       --
       NVL((SELECT DISTINCT food_safety_print_flag
              FROM erm erm2
             WHERE erm2.load_no = erm.load_no
               AND erm2.food_safety_print_flag = 'Y'), 'N') load_food_safety_print_flag
  FROM pm, 
       erm,
       erd,
       -- inlive view
       (SELECT MIN(TRIM(RPAD(SUBSTR(attribute_value, 1, INSTR(attribute_value, ':') - 1), 4, ' '))) opco_number
           FROM  maintenance
           WHERE component = 'COMPANY'
            AND attribute = 'MACHINE') maint
 WHERE pm.prod_id              = erd.prod_id
   AND pm.cust_pref_vendor     = erd.cust_pref_vendor
   AND erd.erm_id              = erm.erm_id
   AND erm.erm_type            IN ('PO', 'SN')
 GROUP BY erm.load_no, erm.erm_id, erm.status, erm.erm_type, erm.sched_date, erm.door_no, maint.opco_number
/

GRANT SELECT ON swms.v_rp1rn TO SWMS_USER;
GRANT SELECT ON swms.v_rp1rn TO SWMS_VIEWER;

CREATE OR REPLACE PUBLIC SYNONYM v_rp1rn FOR  swms.v_rp1rn
/



--
-- Page footer for rp1rn report.
-- The records below "only_for_food_safety_flag" set to Y will only print for
-- a load that has erm.FOOD_SAFETY_PRINT_FLAG set to Y for a PO on the load.
-- NOTE:  rp1re filters print the same first 2 records for food safety PO's.
--
CREATE OR REPLACE VIEW swms.v_rp1rn_footer
AS
SELECT 1 sort_order,
       'Date: _____ /_____ /_____      Door#: ________     Open Time: ______ : ______' text,
       'Y' only_for_food_safety_flag
  FROM DUAL
UNION
SELECT 2 sort_order,
       'Item Temperature: ______ Nose     ______ Middle      ______ Tail      Time: ______ : ______' text,
       'Y' only_for_food_safety_flag
  FROM DUAL
UNION
SELECT 3 sort_order,
       'Trailer was clean? Y/N ___     Trailer was pest free? ___     Trailer in good condition? Y/N ___ ' text ,
       'N' only_for_food_safety_flag
  FROM DUAL
UNION
SELECT 4 sort_order,
       'Condition Verified By: ____________________________________________________' text,
       'N' only_for_food_safety_flag 
  FROM DUAL
/

GRANT SELECT ON swms.v_rp1rn_footer TO SWMS_USER;
GRANT SELECT ON swms.v_rp1rn_footer TO SWMS_VIEWER;

CREATE OR REPLACE PUBLIC SYNONYM v_rp1rn_footer FOR  swms.v_rp1rn_footer;

