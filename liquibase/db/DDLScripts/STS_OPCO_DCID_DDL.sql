/****************************************************************************
** Date:       16-NOV-2018
** File:       STS_OPCO_DCID_DDL.sql
**
** Script to create table STS_OPCO_DCID
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-Oct-2018 Vishnupriya K.     Script to create table STS_OPCO_DCID
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
   FROM all_tables
  WHERE table_name = 'STS_OPCO_DCID';

  IF (v_exists = 0)  THEN
  
  EXECUTE IMMEDIATE 'CREATE TABLE SWMS.STS_OPCO_DCID 
   (DCID VARCHAR2(25 BYTE), 
	OPCO_ID VARCHAR2(25 BYTE), 
	OPCO_NAME VARCHAR2(500 BYTE), 
	TMPLT VARCHAR2(500 BYTE)  )';
	
  End If;
End;	
/