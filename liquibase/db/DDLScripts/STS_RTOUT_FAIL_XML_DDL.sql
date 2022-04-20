/****************************************************************************
** Date:       16-NOV-2018
** File:       STS_RTOUT_FAIL_XML_DDL.sql
**
** Script to create table STS_RTOUT_FAIL_XML
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-Oct-2018 Vishnupriya K.     Script to create table STS_RTOUT_FAIL_XML
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
   FROM all_tables
  WHERE table_name = 'STS_RTOUT_FAIL_XML';

  IF (v_exists = 0)  THEN
  
  EXECUTE IMMEDIATE 'CREATE TABLE SWMS.STS_RTOUT_FAIL_XML
  ( PROCESS_NO NUMBER(10,0) NOT NULL ENABLE,
    ROUTE_NO   VARCHAR2(10 CHAR) NOT NULL ENABLE,
    ERR_CODE   VARCHAR2(36 CHAR) NOT NULL ENABLE,
    XML_DATA   CLOB,
    ERR_MSG  VARCHAR2(100 CHAR),
    ADD_DATE   DATE DEFAULT SYSDATE NOT NULL ENABLE,
    ADD_USER   VARCHAR2(30 CHAR) NOT NULL ENABLE,
    CONSTRAINT STS_RTOUT_XML_SQN PRIMARY KEY (PROCESS_NO) )';
    
     EXECUTE IMMEDIATE 'create sequence STS_RTOUT_FAIL_XML_SN start with 10';
	
  End If;
End;	
/
    