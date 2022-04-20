/********************************************************************
**
** Script to create new SWMS_FLOATS_IN table      
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
    WHERE  table_name = 'SWMS_FLOATS_IN'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
        EXECUTE IMMEDIATE '
  CREATE TABLE "SWMS"."SWMS_FLOATS_IN" 
   ( "SEQUENCE_NUMBER" NUMBER NOT NULL ENABLE, 
	"RDC_NO" VARCHAR2(3 CHAR) NOT NULL ENABLE, 
	"OPCO_NO" VARCHAR2(10 CHAR) NOT NULL ENABLE, 
  	"BATCH_ID" NUMBER NOT NULL ENABLE, 
	"BATCH_NO" NUMBER(9,0), 
	"BATCH_SEQ" NUMBER(2,0), 
	"FLOAT_NO" NUMBER(9,0) NOT NULL ENABLE, 
	"FLOAT_SEQ" VARCHAR2(4 CHAR), 
	"ROUTE_NO" VARCHAR2(10 CHAR), 
	"B_STOP_NO" NUMBER(7,2), 
	"E_STOP_NO" NUMBER(7,2), 
	"FLOAT_CUBE" NUMBER(12,4), 
	"GROUP_NO" NUMBER(3,0), 
	"MERGE_GROUP_NO" NUMBER(3,0), 
	"MERGE_SEQ_NO" NUMBER(3,0), 
	"MERGE_LOC" VARCHAR2(10 CHAR), 
	"ZONE_ID" VARCHAR2(5 CHAR), 
	"EQUIP_ID" VARCHAR2(10 CHAR), 
	"COMP_CODE" VARCHAR2(1 CHAR), 
	"SPLIT_IND" VARCHAR2(1 CHAR), 
	"PALLET_PULL" VARCHAR2(1 CHAR), 
	"PALLET_ID" VARCHAR2(18 CHAR), 
	"HOME_SLOT" VARCHAR2(10 CHAR), 
	"DROP_QTY" NUMBER(9,0), 
	"DOOR_AREA" VARCHAR2(1 CHAR), 
	"SINGLE_STOP_FLAG" VARCHAR2(1 CHAR), 
	"STATUS" VARCHAR2(3 CHAR), 
	"SHIP_DATE" DATE, 
	"PARENT_PALLET_ID" VARCHAR2(18 CHAR), 
	"FL_METHOD_ID" VARCHAR2(10 CHAR), 
	"FL_SEL_TYPE" VARCHAR2(3 CHAR), 
	"FL_OPT_PULL" VARCHAR2(1 CHAR), 
	"TRUCK_NO" VARCHAR2(10 CHAR), 
	"DOOR_NO" VARCHAR2(10 CHAR), 
	"CW_COLLECT_STATUS" CHAR(1 CHAR), 
	"CW_COLLECT_USER" VARCHAR2(30 CHAR), 
	"FL_NO_OF_ZONES" NUMBER(3,0), 
	"FL_MULTI_NO" NUMBER(3,0), 
	"FL_SEL_LIFT_JOB_CODE" VARCHAR2(6), 
	"MX_PRIORITY" NUMBER(2,0), 
	"IS_LOADED_FLAG" VARCHAR2(1), 
	"FLOAT_CUBE_WITH_SKID" NUMBER(12,4), 
	"FLOAT_WEIGHT" NUMBER(9,3), 
	"FLOAT_WEIGHT_WITH_SKID" NUMBER(9,3), 
	"IS_MOVED" VARCHAR2(1), 
	"LOT_ID" VARCHAR2(30 CHAR), 
	"TASK_ID" NUMBER(10,0), 
	"RDC_OUTBOUND_PALLET_ID" VARCHAR2(18 CHAR), 
	"RDC_OUTBOUND_PARENT_PALLET_ID" VARCHAR2(18 CHAR), 
	"LABOR_BATCH_NO" VARCHAR2(13 CHAR), 
	"RECORD_STATUS" VARCHAR2(1 CHAR) DEFAULT ''N'' NOT NULL ENABLE, 
	"ERROR_MSG" VARCHAR2(250 CHAR), 
	"ADD_USER" VARCHAR2(30 CHAR) DEFAULT REPLACE( USER, ''OPS$'' ), 
	"ADD_DATE" DATE DEFAULT SYSDATE, 
	"UPD_USER" VARCHAR2(30 CHAR), 
	"UPD_DATE" DATE
   )';
        
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM SWMS_FLOATS_IN FOR SWMS.SWMS_FLOATS_IN';

	EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SWMS_FLOATS_IN TO SWMS_USER';
        
	EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.SWMS_FLOATS_IN TO SWMS_VIEWER';   
    END IF;      
END;
/
