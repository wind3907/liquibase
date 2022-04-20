/****************************************************************************
** Date:       26-Aug-2021
** File:       R47_DML_OPCOF3575_xn_erm_type.sql
**
** Script to insert new ERM Type XN in to REC_TYPE table.
** XN ERM type is used for Cross Dock Orders (XSN).
**
**
** Modification History:
**    Date         Designer           Comments
**    --------     -------- ---------------------------------------------------
**    26-Aug-2021  jkar6681      ERM Type XN for XDOCK Orders
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  FROM REC_TYPE
  WHERE REC_TYPE ='XN';
  
 IF (v_exists = 0)  THEN
  INSERT INTO REC_TYPE(REC_TYPE, DESCRIP)
  values('XN', 'Cross Dock Order');
  COMMIT;
 End If;
End;							  
/
