/********************************************************************
**
** Script to create new SWMS_ORDCW_IN table      
**
** Modification History:
** 
**    Date     Comments
**    -------- -------------- --------------------------------------
**    9/11/19  vkal9662 Created
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'SWMS_ORDCW_IN'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE '    
  CREATE TABLE "SWMS"."SWMS_ORDCW_IN" 
   (	"SEQUENCE_NUMBER" NUMBER NOT NULL ENABLE, 
	"RDC_NO" VARCHAR2(3 CHAR) NOT NULL ENABLE, 
	"OPCO_NO" VARCHAR2(10 CHAR) NOT NULL ENABLE, 
	"BATCH_ID" NUMBER NOT NULL ENABLE, 
	"ORDER_ID" VARCHAR2(20 CHAR) NOT NULL ENABLE, 
	"ORDER_LINE_ID" NUMBER(3,0) NOT NULL ENABLE, 
	"SEQ_NO" NUMBER(4,0), 
	"PROD_ID" VARCHAR2(9 CHAR), 
	"CUST_PREF_VENDOR" VARCHAR2(10 CHAR), 
	"CATCH_WEIGHT" NUMBER(9,3), 
	"CW_TYPE" VARCHAR2(1 CHAR), 
	"UOM" NUMBER(1,0), 
	"CW_FLOAT_NO" NUMBER(9,0), 
	"CW_SCAN_METHOD" CHAR(1 CHAR), 
	"ORDER_SEQ" NUMBER(8,0), 
	"CASE_ID" NUMBER(13,0), 
	"CW_KG_LB" NUMBER(9,3), 
	"RECORD_STATUS" VARCHAR2(1 CHAR) DEFAULT ''N'' NOT NULL ENABLE, 
	"ERROR_MSG" VARCHAR2(250 CHAR), 
	"ADD_USER" VARCHAR2(30 CHAR) DEFAULT REPLACE( USER, ''OPS$'' ), 
	"ADD_DATE" DATE DEFAULT SYSDATE, 
	"UPD_USER" VARCHAR2(30 CHAR), 
	"UPD_DATE" DATE
   )   ';
        
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM SWMS_ORDCW_IN FOR SWMS.SWMS_ORDCW_IN';

	EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SWMS_ORDCW_IN TO SWMS_USER';
        
	EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.SWMS_ORDCW_IN TO SWMS_VIEWER';   
    END IF;      
END;
/
