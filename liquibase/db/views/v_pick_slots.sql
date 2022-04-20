REM @(#) src/schema/views/v_pick_slots.sql, swms, swms
REM File : @(#) src/schema/views/v_pick_slots.sql, swms
REM Usage: sqlplus USR/PWD @src/schema/views/v_pick_slots.sql, swms
REM
REM      MODIFICATION HISTORY
REM  05/29/14 Infosys ssin2436 New View Created for fetching Pick slots for an item 


/* Formatted on 5/22/2014 3:54:05 PM (QP5 v5.163.1008.3004) */
CREATE OR REPLACE VIEW SWMS.V_PICK
(
   PROD_ID,
   LOGI_LOC,
   PLOGI_LOC,
   REC_DATE,
   QOH,
   EXP_DATE
)
AS
   (   SELECT i.prod_id,
             i.logi_loc,
             i.plogi_loc,
             i.rec_date,
             trunc(i.qoh/(select spc from pm where prod_id = i.prod_id)),
             i.exp_date
        FROM inv i, loc l
       WHERE i.logi_loc = i.plogi_loc
       AND i.logi_loc = l.logi_loc
       AND l.PERM = 'Y');

--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM V_PICK FOR SWMS.V_PICK;