CREATE OR REPLACE
PACKAGE      pl_symbotic_alerts AUTHID CURRENT_USER
IS
  /*===========================================================================================================
  -- Package
  -- pl_symbotic_alerts
  --
  -- Description
  --  This package is triggered by failures in Symbotic Messaging.
  --  This package analyses the severity of the message and inserts the records in
  --  swms_failure_event which raises an alert or creates a ticket.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 03/24/15        Sunil Ontipalli             1.0              Initial Creation
  -- 08/25/15        Sunil Ontipalli             1.1              Enhancement: Added more information to the alerts.
  ============================================================================================================*/

PROCEDURE raise_alert(i_interface_ref_doc  IN VARCHAR2,
                      i_msg_id             IN VARCHAR2,
                      i_batch_id           IN VARCHAR2,
                      i_error_msg          IN VARCHAR2);
  
END pl_symbotic_alerts;
/

CREATE OR REPLACE
PACKAGE BODY      pl_symbotic_alerts
IS
  /*===========================================================================================================
  -- Package
  -- pl_symbotic_alerts
  --
  -- Description
  --  This package is triggered by failures in Symbotic Messaging.
  --  This package analyses the severity of the message and inserts the records in
  --  swms_failure_event which raises an alert or creates a ticket.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 03/24/15        Sunil Ontipalli             1.0              Initial Creation
  -- 08/25/15        Sunil Ontipalli             1.1              Enhancement: Added more information to the alerts.
  ============================================================================================================*/
PROCEDURE raise_alert(i_interface_ref_doc  IN VARCHAR2,
                      i_msg_id             IN VARCHAR2,
                      i_batch_id           IN VARCHAR2,
                      i_error_msg          IN VARCHAR2)
/*===========================================================================================================
  -- Procedure
  -- raise_alert
  --
  -- Description
  --   This procedure determines whether to raise an alert or to send an email.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 03/24/15        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
PRAGMA AUTONOMOUS_TRANSACTION;
l_interface_ref_doc   VARCHAR2(10);
l_alert_id            NUMBER;
l_program_name        VARCHAR2(20);
l_error_type          VARCHAR2(4);
l_status              VARCHAR2(1);
l_msg_subject         VARCHAR2(100);
l_error_msg           VARCHAR2(400);
l_msg_id              VARCHAR2(30);
l_batch_id            VARCHAR2(30);
l_unique_id           VARCHAR2(48);
l_msg_body            VARCHAR2(1000);
l_prod_id             VARCHAR2(10);

BEGIN
-------------------Assigning the Initial Values---------------------------------
  l_interface_ref_doc := i_interface_ref_doc;
  l_msg_id            := i_msg_id;
  l_batch_id          := i_batch_id;
  l_error_msg         := nvl(i_error_msg, 'NOT AVAILABLE');

----------------Determining the Process based on Interface Ref Doc---------------
     IF l_interface_ref_doc = 'SYS03' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS03-Add Pallet Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;
        

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS03',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS01' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS01-Item Master Message';
        
        BEGIN
         
         SELECT prod_id
           INTO l_prod_id
           FROM matrix_pm_out
          WHERE sys_msg_id = l_msg_id
            AND rec_ind    = 'H';
           
        EXCEPTION
          WHEN OTHERS THEN
           l_prod_id := 'Not Available';
        END;
        
        
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Prod Id: '||l_prod_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS01',
                                SQLCODE, SQLERRM);
         END;

     ELSIF l_interface_ref_doc = 'SYS04' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS04-Add Order Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS04',
                                SQLCODE, SQLERRM);
         END;

     ELSIF l_interface_ref_doc = 'SYS05' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS05-Add Internal Order Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS05',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS06' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS06-Notify Case Removed From Spur Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS06',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS07' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS07-Notify Batch Status Changed Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS07',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS08' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS08-Update Pallet Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS08',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS09' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS09-Bulk Request Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS09',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS10' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS10-Bulk Notification Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS10',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS11' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS11-Update Order Batch Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS11',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS12' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS12-Cancel Order Batch Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS12',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS13' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS13-Cancel Order Detail Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS13',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS14' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS14-Add Order Detail Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS14',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYS15' THEN

        l_program_name := 'PL_XML_MATRIX_OUT';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Sending SYS15-Wave Status Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYS15',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM03' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM03-Notify Pallet Stored Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM03',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM05' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_batch_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM05-Notify Batch Ready For Selection Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM05',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM06' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM06-Notify Case Skipped Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM06',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM07' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM07-Notify Product Ready For Pickup Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM07',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM12' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM12-Notify Case Diverted to Spur Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM12',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM15' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'CRIT';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM15-Bulk Notification Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM15',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM16' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM16-Order Response Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM16',
                                SQLCODE, SQLERRM);

         END;

     ELSIF l_interface_ref_doc = 'SYM17' THEN

        l_program_name := 'PL_MX_STG_TO_SWMS';
        l_error_type   := 'WARN';
        l_alert_id     := failure_seq.NEXTVAL;
        l_unique_id    := l_msg_id;
        l_status       := 'N';
        l_msg_subject  := 'Symbotic Alert: Error Processing SYM17-Labor Interface Message';
        l_msg_body     := 'Msg ID: '||l_msg_id||chr(10)||'Batch Id: '||l_batch_id||chr(10)||l_error_msg;

         BEGIN

           INSERT INTO swms_failure_event (alert_id, modules, error_type, unique_id,
                                           status, msg_subject, msg_body, add_date, add_user)
                VALUES                    (l_alert_id, l_program_name, l_error_type, l_unique_id,
                                           l_status, l_msg_subject, SUBSTR(l_msg_body,1,400), SYSDATE, REPLACE(USER, 'OPS$'));
           COMMIT;

         EXCEPTION
          WHEN OTHERS THEN
           pl_text_log.ins_msg('INFO', 'pl_symbotic_alerts',
                               'Error Occurred while creating an Alert for SYM17',
                                SQLCODE, SQLERRM);

         END;

     END IF;

END raise_alert;

END pl_symbotic_alerts;
/

CREATE OR REPLACE PUBLIC SYNONYM pl_symbotic_alerts FOR swms.pl_symbotic_alerts;

grant execute on swms.pl_symbotic_alerts to swms_user;

grant execute on swms.pl_symbotic_alerts to swms_mx;