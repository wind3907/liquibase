-- USE THIS SCRIPT for creating and starting FoodPro que tables
DECLARE
  This_Message                      VARCHAR2(2000 CHAR);
  
  CURSOR get_queue_details
      IS 
      
  SELECT queue_table, propagation_type, port, outbound_log_queue,
         mq_queue_name, mq_queue_manager, linkname, inbound_log_queue, 
         hostname, channel, aq_queue_name
    FROM mq_interface_maint
   WHERE  queue_table IS NULL;

BEGIN
   --ORACLE_HOME/mgw/log    logging install errors
    This_Message := 'Script to create AQ queues started' ;
    pl_log.ins_msg('INFO', 'DECLARE',
                      This_Message,
                        NULL, NULL, 'INSTALL', 'INSTALL', 'N');

    FOR I IN get_queue_details
    LOOP
       DECLARE
        v_options sys.mgw_properties;
        v_prop    sys.mgw_mqseries_properties;
       BEGIN
         DBMS_AQADM.CREATE_QUEUE_TABLE (Queue_table =>  'QT_'||substr(i.aq_queue_name, 3),  --'Q_'||I.aq_queue_name, 
                                          multiple_consumers => FALSE,
                                          Queue_payload_type => 'QUEUE_CHAR_TYPE'); --'sys.mgw_basic_msg_t');

         DBMS_AQADM.CREATE_QUEUE(Queue_name  => I.aq_queue_name,
                                 Queue_table => 'QT_'||substr(i.aq_queue_name, 3) ); --'Q_'||I.aq_queue_name);
                                 
         DBMS_AQADM.START_QUEUE(Queue_name => I.aq_queue_name);
         
         UPDATE mq_interface_maint 
            SET queue_table   = 'QT_'||substr(i.aq_queue_name, 3)
          WHERE aq_queue_name = I.aq_queue_name;
         
 
         COMMIT;                   
       EXCEPTION
        WHEN OTHERS THEN
           pl_log.ins_msg('WARN', 'DECLARE',
                  'Error Creating queue:'||I.aq_queue_name,
                  SQLCODE, SQLERRM, 'INSTALL', 'INSTALL', 'N');  
       END;

    END LOOP;
    
/*EXCEPTION
WHEN OTHERS THEN
  pl_log.ins_msg('WARN', 'DECLARE',
                  This_Message,
                  NULL, NULL, 'INSTALL', 'INSTALL', 'N');*/
END ;
/
