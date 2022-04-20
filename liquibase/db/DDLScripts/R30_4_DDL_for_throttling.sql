
/****************************************************************************
**
** Description:
**    Symbotic Throttling DML
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    03/03/16          Created.
**    03/18/16 bben0556 Brian Bent
**                      I had put comments using "--" in the file but having a comment
**                      on the the last line in the "ALTER TABLE pm" stmt kept
**                      prevented the stmt from running--as if the ALTER stmt
**                      was just a big comment.  I moved the comments above
**                      the ALTER stmt.
****************************************************************************/


---------------------------------------------
-- PM table changes
-- Add columns:
--    mx_throttle_flag     Flags if the item can be throttled.
--    hist_case_order      Historical case order qty for the day.
--                         Populated by DB trigger when the historical
--                         orders sent to SWMS which is usually right
--                         after day close.
--    hist_case_date       When hist_case_order is updated.  Populated
--                         by the DB trigger.
--    hist_split_order     For splits.
--    hist_split_date      For splits.
---------------------------------------------

ALTER TABLE swms.pm
   ADD (mx_throttle_flag     VARCHAR2(1 CHAR),
        hist_case_order      NUMBER,
        hist_case_date       DATE,
        hist_split_order     NUMBER,
        hist_split_date      DATE);



---------------------------------------------
-- PM table changes
---------------------------------------------
CREATE TABLE swms.mx_throttle_replenlst_options
(
   select_flag		 NUMBER,	
   prod_id               VARCHAR2(9 CHAR),
   descrip               VARCHAR2(30 CHAR),
   pallet_id             VARCHAR2(18 CHAR),
   location              VARCHAR2(10 CHAR),
   qoh_case              NUMBER(7),
   throttle_flag         VARCHAR2(1 CHAR),
   hist_order            NUMBER,
   wsh_ship_movements    NUMBER
);

GRANT ALL ON swms.mx_throttle_replenlst_options TO swms_user;

CREATE OR REPLACE PUBLIC SYNONYM mx_throttle_replenlst_options FOR swms.mx_throttle_replenlst_options;

