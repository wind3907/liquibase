/* CRQ46091- Equipment_Safety_check */
/* CRQ46091- Added one new column to the existing view */
/* Formatted on 6/7/2013 11:21:21 AM (QP5 v5.163.1008.3004) */
CREATE OR REPLACE FORCE VIEW SWMS.V_EQUIP_SAFETY_HIST
(
   EQUIP_ID,
   APPL_TYPE,
   ADD_DATE,
   ADD_USER,
   STATUS_TYPE,
   ADD_DATE_Q
)
AS
   SELECT DISTINCT
          equip_id,
          appl_type,
          add_date,
          add_user,
          status_type,
          TO_DATE (TO_CHAR (add_date, 'mm/dd/yy hh24:mi'),
                   'mm/dd/yy hh24:mi')
     FROM equip_safety_hist;
	 
