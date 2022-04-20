/****************************************************************************
** Date:       16-NOV-2018
** File:       STS_TEMPLATES_DDL.sql
**
** Script to create table
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-Oct-2018 Vishnupriya K.    table createion for sts_templates
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
   FROM all_tables
  WHERE table_name = 'STS_TEMPLATES';

  IF (v_exists = 0)  THEN
  EXECUTE IMMEDIATE   'CREATE TABLE SWMS.STS_TEMPLATES
   (TNAME VARCHAR2(100 BYTE), 
	SEQUENCE_NO NUMBER, 
	TAG_NAME VARCHAR2(100 BYTE), 
	TAG_VALUE VARCHAR2(4000 BYTE)   )';
	
  End If;
End;	
/