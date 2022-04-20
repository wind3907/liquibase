/*********************************************************************
**
**  DDL script to: 
**    Jira 3523
**    Add new column task_id, lm_rcv_batch_no to tables: putawaylst

**  Modification History:
**  
**   Date       Author        Comment
**   ----------------------------------------------------------------
**  07/08/21    mcha1213      created
**
**********************************************************************/

DECLARE
   v_column_exists NUMBER := 0;
   v_column_exists_1 NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'TASK_ID'
     AND table_name  = 'PUTAWAYLST';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST ADD TASK_ID NUMBER(10,0)';
	  
	  EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST ADD CONSTRAINT PUTAWAYLST_UK1 UNIQUE (TASK_ID)
						USING INDEX PCTFREE 10
						STORAGE(INITIAL 64k NEXT 1M MINEXTENTS 1 MAXEXTENTS UNLIMITED PCTINCREASE 0)
						TABLESPACE "SWMS_ITS2"  ENABLE';
 
  
   END IF;
   
   
   SELECT COUNT(*)
   INTO v_column_exists_1
   FROM user_tab_cols
   WHERE column_name = 'LM_RCV_BATCH_NO'
     AND table_name  = 'PUTAWAYLST';

   IF (v_column_exists_1 = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST ADD LM_RCV_BATCH_NO VARCHAR2(13 CHAR)';
  
  
   END IF;
END;
/

