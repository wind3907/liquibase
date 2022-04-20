/****************************************************************************
 ** File:      add_swap_syspar.sql
 **
 ** Desc: Script to insert Sysconfig data for the SWAP funcitonality.
 **
 **
 ** Modification History:
 **    Date        Designer   Comments
 **    --------    --------   ----------------------------------------------------
 **    JUN-8-2021  mche6435   Initial version
 **
 ****************************************************************************/

DECLARE
  v_column_exists  NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM forklift_task_priority
  WHERE forklift_task_type = 'SWP'
  AND severity = 'NORMAL'
  AND priority = 53;

  IF (v_column_exists = 0)  THEN
    INSERT INTO swms.forklift_task_priority (
      forklift_task_type,
      severity,
      priority,
      remarks
    )
    VALUES (
      'SWP',
      'NORMAL',
      53,
      'Swap task'
    );
  END IF;

  COMMIT;
END;
/
