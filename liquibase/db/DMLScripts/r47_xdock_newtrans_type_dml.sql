/****************************************************************************
** Date:       09-Aug-2021
** File:       R47_NewTRans_Type_dml.sql
**
** Script to insert new Trans Type RTX in to TRans_type table.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    7-Aug-2018 vkal9662      New Trans Type RTX for XDOCK LP project
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  FROM TRANS_TYPE
  WHERE TRANS_TYPE ='RTX';
  
IF (v_exists = 0)  THEN

INSERT INTO TRANS_TYPE(TRANS_TYPE, DESCRIP,retention_days, inv_affecting)
values('RTX', 'Xdock Return', 55, 'N');

  COMMIT;
  
  End If;
End;							  
/