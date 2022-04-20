/********************************************************************
** Name: r47_jira3394_xdock_returns_out_ddl.sql
** Script to create new xdock_returns_out table
**
** Modification History:
**
**    Date     Comments
**    -------- -------------- --------------------------------------
**    7/11/2  vkal9662 Created
*********************************************************************/
DECLARE
  v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name   = 'XDOCK_RETURNS_OUT'
  AND owner          = 'SWMS';
  IF (v_table_exists = 0) THEN
    EXECUTE IMMEDIATE
    'CREATE TABLE "SWMS"."XDOCK_RETURNS_OUT"  
(    
"BATCH_ID"          VARCHAR2(14 CHAR),    
"SEQUENCE_NO"       NUMBER,    
"RECORD_STATUS"     CHAR(1),    
"SITE_FROM"         CHAR(3),    
"SITE_TO"           CHAR(3),   
"SITE_ID" VARCHAR2(5  CHAR),     
"DELIVERY_DOCUMENT_ID" VARCHAR2(30 CHAR)  ,    
"MANIFEST_NO"       NUMBER(7,0) NOT NULL ENABLE,    
"ROUTE_NO"          VARCHAR2(10 CHAR),    
"STOP_NO"           NUMBER(7,2),    
"REC_TYPE"          VARCHAR2(1 CHAR) NOT NULL ENABLE,    
"OBLIGATION_NO"     VARCHAR2(14 CHAR),    
"PROD_ID"           VARCHAR2(9 CHAR) NOT NULL ENABLE,    
"CUST_PREF_VENDOR"  VARCHAR2(10 CHAR) NOT NULL ENABLE,    
"RETURN_REASON_CD"  VARCHAR2(3 CHAR) NOT NULL ENABLE,    
"RETURNED_QTY"      NUMBER(4,0),    
"RETURNED_SPLIT_CD" VARCHAR2(1 CHAR),    
"CATCHWEIGHT"       NUMBER(9,3),    
"DISPOSITION"       VARCHAR2(3 CHAR),    
"RETURNED_PROD_ID"  VARCHAR2(9 CHAR),    
"ERM_LINE_ID"       NUMBER(4,0) NOT NULL ENABLE,    
"SHIPPED_QTY"       NUMBER(4,0),    
"SHIPPED_SPLIT_CD"  VARCHAR2(1 CHAR),    
"CUST_ID"           VARCHAR2(10 CHAR),    
"TEMPERATURE"       NUMBER,    
"ADD_DATE"          DATE,    
"ADD_USER"          VARCHAR2(30 CHAR),    
"ADD_SOURCE"        VARCHAR2(3 CHAR),    
"UPD_DATE"          DATE,    
"UPD_USER"          VARCHAR2(30 CHAR),    
"UPD_SOURCE"        VARCHAR2(3 CHAR),    
"STATUS"            VARCHAR2(4 CHAR),    
"ERR_COMMENT"       VARCHAR2(1000 CHAR),    
"ORG_RTN_REASON_CD" VARCHAR2(3 CHAR),    
"ORG_RTN_QTY"       NUMBER(4,0),    
"ORG_CATCHWEIGHT"   NUMBER(9,3),    
"RTN_SENT_IND"      CHAR(1 CHAR),    
"POD_RTN_IND"       CHAR(1 CHAR),    
"LOCK_CHG"          VARCHAR2(1),    
"BARCODE_REF_NO"    NUMBER(10,0),    
"CREATE_PUT"        VARCHAR2(1),    
"IMDT_RTN_IND"      VARCHAR2(1) )'
    ;
    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_RETURNS_OUT FOR SWMS.XDOCK_RETURNS_OUT';
    EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_RETURNS_OUT TO SWMS_USER';
    EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_RETURNS_OUT TO SWMS_VIEWER';
  END IF;
END;
/
