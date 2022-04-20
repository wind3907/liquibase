/****************************************************************************
**
** File:       r47_jira3506_xdoc_rec_rule_dml.sql
**
** Script to insert new Rule to be used by Cross Dock process.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    11-May-2021 vkal9662      New rule for crossdock Rec
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM Rules
  WHERE Rule_id = 14;
  
IF (v_column_exists = 0)  THEN

INSERT
INTO Rules
  (RULE_ID,
   RULE_TYPE,
   RULE_DESC,
   DEF  )
  VALUES
  (  14,
    'PUT',
    'RECEIVING CROSSDOCK STAGING',
    'N'  );
	
  COMMIT;
  
  End If;
End;							  
/