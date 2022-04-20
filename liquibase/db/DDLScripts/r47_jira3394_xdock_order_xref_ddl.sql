/********************************************************************
** Name: r47_jira3394_xdock_order_xref_ddl.sql
** Script to create new XDOCK_ORDER_XREF table      
**
** Modification History:
** 
**    Date     Comments
**    -------- -------------- --------------------------------------
**    7/11/2  vkal9662 Created
**    8/10/21 kchi7065 Added new columns, S_FULLFILLMENT_STATUS and X_LASTMILE_STATUS
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN 
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'XDOCK_ORDER_XREF'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN  
                                 
EXECUTE IMMEDIATE     
 '
 CREATE TABLE "SWMS"."XDOCK_ORDER_XREF"
  (    
    "DELIVERY_DOCUMENT_ID" VARCHAR2(30 CHAR) NOT NULL ENABLE,
    "CROSS_DOCK_TYPE"     VARCHAR2(1), 
    "SITE_FROM"           CHAR(3),
    "SITE_TO"             CHAR(3),
    "MANIFEST_NO_FROM"    NUMBER(7,0) ,
    "MANIFEST_NO_TO"      NUMBER(7,0) ,
    "ROUTE_NO_FROM"       VARCHAR2(10 CHAR) ,
    "ROUTE_NO_TO"         VARCHAR2(10 CHAR) ,
    "S_FULLFILLMENT_STATUS" VARCHAR2(30 CHAR) ,
    "X_LASTMILE_STATUS"     VARCHAR2(30 CHAR) ,
    "ORDER_ID_FROM"       VARCHAR2(14 CHAR) ,
    "ORDER_ID_TO"         VARCHAR2(14 CHAR) ,
    "OBLIGATION_NO"       VARCHAR2(14 CHAR),
    "CUST_ID_FROM"             VARCHAR2(10 CHAR) ,
    "CUST_ID_TO"             VARCHAR2(10 CHAR) ,
    "ADD_USER"            VARCHAR2(30 CHAR) ,
    "ADD_DATE"            DATE  )  '; 


	EXECUTE IMMEDIATE 'ALTER TABLE XDOCK_ORDER_XREF add CONSTRAINT pk_xdx_ord_xref PRIMARY KEY (DELIVERY_DOCUMENT_ID)';    
    
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_ORDER_XREF FOR SWMS.XDOCK_ORDER_XREF';

	EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_ORDER_XREF TO SWMS_USER';
        
	EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_ORDER_XREF TO SWMS_VIEWER';
  
  END IF;      
END;
/
