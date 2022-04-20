/*============================================================================================-
  Types for the SOS Short Form
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  15-Jan-2015    spin3676         Initial Version
  12-Jun-2015    sont5129         Added new columns in the Object and Force is added to avoid re-run errors
  =============================================================================================*/
CREATE OR REPLACE TYPE "SWMS"."SHORT_OBJECT" FORCE AS OBJECT ( 
    "ORDERSEQ" NUMBER(8), "LOCATION" VARCHAR2(6), "PICKTYPE" VARCHAR2(2),
    "AREA" VARCHAR2(1), "TRUCK" VARCHAR2(4), "QTY_SHORT" NUMBER(3),
    "SHORT_REASON" VARCHAR2(8), "BATCH_NO" VARCHAR2(7), "FORK_STATUS" VARCHAR2(8),
    "PIK_STATUS" VARCHAR2(1), "USER_ID" VARCHAR2(30), "SLOT_TYPE" VARCHAR2(3),
    "CASE_BARCODE" VARCHAR2(20), "FLOAT_NO" NUMBER(9), "FLOAT_DETAIL_SEQ_NO" NUMBER(3));
/


CREATE OR REPLACE TYPE "SWMS"."SHORT_TABLE" FORCE AS 
    TABLE OF "SWMS"."SHORT_OBJECT";
/

CREATE OR REPLACE PUBLIC SYNONYM SHORT_OBJECT FOR "SWMS"."SHORT_OBJECT";
CREATE OR REPLACE PUBLIC SYNONYM SHORT_TABLE FOR "SWMS"."SHORT_TABLE";

GRANT EXECUTE ON SHORT_OBJECT TO SWMS_USER;
GRANT EXECUTE ON SHORT_TABLE TO SWMS_USER;
