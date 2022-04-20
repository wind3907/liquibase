/****************************************************************************

** File: R45.2_DDL_add_lms_sent_flag.sql

*

** Desc: Script makes changes to table BATCH and ARCH_BATCH related to SWMS BY Integration

**

** Modification History:

**    Date        Designer           Comments

**    ----------- --------     ------------------------------------------

**    16/07/21     dgee3936     added LMS_SENT_FLAG column to table BATCH

**    16/07/21     dgee3936     added LMS_SENT_FLAG column to table ARCH_BATCH

****************************************************************************/


DECLARE
v_column_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
    WHERE column_name in ('LMS_SENT_FLAG')
      AND table_name = 'BATCH';

    IF (v_column_exists = 0)
    THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.BATCH ADD ( LMS_SENT_FLAG VARCHAR2(45 CHAR))';
      COMMIT;
    END IF;

    SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
    WHERE column_name in ('LMS_SENT_FLAG')
      AND table_name = 'ARCH_BATCH';

    IF (v_column_exists = 0)
    THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ARCH_BATCH ADD ( LMS_SENT_FLAG VARCHAR2(45 CHAR))';
      COMMIT;
    END IF;
END;
/
