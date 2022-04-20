/****************************************************************************
** File: CRQ31527insert_data_apcom_queue.sql
**
** Desc: Insert data to table:APCOM_QUEUE  
**        
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    03-dec-2017 Elaine Zheng   Insert data to table:APCOM_QUEUE  
**                                
**                                   
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'IM'
  AND  IN_OR_OUT='I';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('IM', 2100, 'I', 'Y');
 END IF;
 END;
 /
 DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'OR'
  AND  IN_OR_OUT='I';

  IF (v_column_exists = 0)
  THEN
     
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('OR', 2100, 'I', 'Y');
     END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'MF'
  AND  IN_OR_OUT='I';

  IF (v_column_exists = 0)
  THEN
     
        Insert into SWMS.APCOM_QUEUE
           (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
         Values
           ('MF', 2100, 'I', 'Y');
     END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'ML'
  AND  IN_OR_OUT='I';

  IF (v_column_exists = 0)
  THEN
     
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('ML', 2100, 'I', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'PO'
  AND  IN_OR_OUT='I';

  IF (v_column_exists = 0)
  THEN
     
       Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('PO', 2100, 'I', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'PW'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('PW', 2100, 'O', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'OW'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('OW', 2100, 'O', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'LM'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('LM', 2100, 'O', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'IA'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('IA', 2100, 'O', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'WH'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('WH', 2100, 'O', 'Y');
    END IF;
 END;
/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
  INTO v_column_exists
  FROM APCOM_QUEUE
  WHERE  QUEUE_NAME = 'RT'
  AND  IN_OR_OUT='O';

  IF (v_column_exists = 0)
  THEN
    Insert into SWMS.APCOM_QUEUE
       (QUEUE_NAME, SECOND_DURATION, IN_OR_OUT, MONITOR)
     Values
       ('RT', 2100, 'O', 'Y');
    END IF;
 END;
/
COMMIT;
