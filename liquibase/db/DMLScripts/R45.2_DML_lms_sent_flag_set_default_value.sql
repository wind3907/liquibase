/****************************************************************************

** File: R45.2_DML_lms_sent_flag_set_default_value.sql

*

** Desc: Script makes changes to table BATCH and ARCH_BATCH related to SWMS BY Integration

**

** Modification History:

**    Date        Designer           Comments

**    ----------- --------     -----------------------------------------------------

**    16/07/21     dgee3936     set default value for LMS_SENT_FLAG in table BATCH

**    16/07/21     dgee3936     set default value for LMS_SENT_FLAG in table  ARCH_BATCH

****************************************************************************/

BEGIN
    LOOP
      UPDATE BATCH
      SET LMS_SENT_FLAG = 'EXISTING'
       WHERE ROWNUM < 1000
         AND LMS_SENT_FLAG IS NULL;
      EXIT WHEN SQL%NOTFOUND;
      COMMIT;
   END LOOP;

   LOOP
      UPDATE ARCH_BATCH
      SET LMS_SENT_FLAG = 'EXISTING'
       WHERE ROWNUM < 1000
         AND LMS_SENT_FLAG IS NULL;
      EXIT WHEN SQL%NOTFOUND;
      COMMIT;
   END LOOP;
   COMMIT;
END;
