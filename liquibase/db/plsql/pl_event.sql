CREATE OR REPLACE PACKAGE SWMS.pl_event as
PROCEDURE ins_failure_event (modules  in swms_failure_event.MODULES%TYPE,
                              stats  in swms_failure_event.status%TYPE,
                               Err_type in swms_failure_event.ERROR_TYPE%TYPE,
                               Uniq_id  in swms_failure_event.UNIQUE_ID%TYPE,
                               subject in swms_failure_event.MSG_SUBJECT%TYPE,
                               msgbody in swms_failure_event.MSG_BODY%TYPE);

end pl_event;
/
CREATE OR REPLACE PACKAGE BODY SWMS.pl_event
AS
-- Modification History:                                                     
--    Date     Designer Comments                                             
--    -------- -------- -----------------------------------------------------
--    01/23/17 jluo6971 CRQ000000043826 - Added PRAGAM AUTONOMOUS
/* *********************************************************************** */
   PROCEDURE ins_failure_event (
      modules    IN   swms_failure_event.modules%TYPE,
      stats      IN   swms_failure_event.status%TYPE,
      err_type   IN   swms_failure_event.ERROR_TYPE%TYPE,
      uniq_id    IN   swms_failure_event.unique_id%TYPE,
      subject    IN   swms_failure_event.msg_subject%TYPE,
      msgbody    IN   swms_failure_event.msg_body%TYPE
   )
   IS
	PRAGMA AUTONOMOUS_TRANSACTION; 
   BEGIN
      INSERT INTO swms_failure_event
                  (alert_id, modules, ERROR_TYPE, unique_id, status,
                   msg_subject, msg_body, add_date, add_user)
         SELECT failure_seq.NEXTVAL, modules, err_type, uniq_id, stats,
                subject, msgbody, SYSDATE, REPLACE (USER, 'OPS$', NULL)
           FROM DUAL;
/* 6000010239-SWMS Exception email alert-Commenting the below validation           
          WHERE EXISTS (
                   SELECT 1
                     FROM sys_config
                    WHERE config_flag_name = 'HOST_TYPE'
                      AND config_flag_val = 'SAP'); */

      COMMIT;
   END;
END pl_event;
/
SHOW ERRORS
