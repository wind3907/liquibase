/****************************************************************************
** Date:       30-DEC-2019
** File:       type_pl_lm_goaltime.sql
**
**             Script for creating objects for lm goal time.
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    01/04/20   KSAR9933  type_pl_lm_goaltime.sql
**    09/07/20   NSEL0716  Implement putaway_pickup rec, table and obj
**
****************************************************************************/
CREATE OR REPLACE TYPE PUTAWAY_PICKUP_REC FORCE AS OBJECT (
    PUT_PATH           				NUMBER,
    EXP_DATE         				NUMBER,
    PALLET_ID           			VARCHAR2(40),
    SRC_LOC           				VARCHAR2(10),
    MSKU_BATCH_FLAG					VARCHAR2(1),
    PALLET_ID_SORT					VARCHAR2(40),
    C_IGNORE_BATCH_FLAG				VARCHAR2(1),
    DROPPED_FOR_A_BREAK_AWAY_FLAG	VARCHAR2(1),
    RESUMED_AFTER_BREAK_AWAY_FLAG	VARCHAR2(1)
)
/

CREATE OR REPLACE TYPE PUTAWAY_PICKUP_TABLE FORCE AS TABLE OF PUTAWAY_PICKUP_REC;
/

CREATE OR REPLACE TYPE PUTAWAY_PICKUP_OBJ FORCE AS OBJECT(
    RESULT_TABLE                    PUTAWAY_PICKUP_TABLE );		
/

GRANT EXECUTE ON PUTAWAY_PICKUP_REC TO SWMS_USER;
GRANT EXECUTE ON PUTAWAY_PICKUP_TABLE TO SWMS_USER;
GRANT EXECUTE ON PUTAWAY_PICKUP_OBJ TO SWMS_USER;
