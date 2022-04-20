/****************************************************************************
**
** File:       r47_jira3506_xdoc_rtn_rule_dml.sql
**
** Script to insert new Rule to be used by Cross Dock process.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    11-May-2021 vkal9662      New rule for crossdock returns process
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM Rules
  WHERE Rule_id = 15;
  
IF (v_column_exists = 0)  THEN

INSERT
INTO Rules
  (RULE_ID,
   RULE_TYPE,
   RULE_DESC,
   DEF  )
  VALUES
  (  15,
    'PUT',
    'RETURNS CROSSDOCK STAGING',
    'N'  );
	
  COMMIT;
  
  End If;
End;							  
/