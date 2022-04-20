DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
   FROM all_tables
  WHERE table_name = 'FLOAT_XML_TAB';

  IF (v_exists = 0)  THEN
  
  EXECUTE IMMEDIATE 'CREATE TABLE SWMS.FLOAT_XML_TAB
  ( ID NUMBER NOT NULL ENABLE,
    STATUS VARCHAR2(1 CHAR),
    ROUTE_NO   VARCHAR2(10 CHAR),
    XML_DATA  CLOB ,
    ERR_MSG  VARCHAR2(100 CHAR),
    ADD_DATE   DATE DEFAULT SYSDATE,
	UPD_DATE   DATE,
    CONSTRAINT XML_FLOAT_PK PRIMARY KEY (ID) )';
    
 	
  End If;
                                  
  EXECUTE IMMEDIATE 'GRANT all on SWMS.FLOAT_XML_TAB to swms_user';
				
  EXECUTE IMMEDIATE 'GRANT all on SWMS.FLOAT_XML_TAB to swms_jdbc';

  EXECUTE IMMEDIATE 'create or replace public synonym FLOAT_XML_TAB for SWMS.FLOAT_XML_TAB';  
  
End;	
/
