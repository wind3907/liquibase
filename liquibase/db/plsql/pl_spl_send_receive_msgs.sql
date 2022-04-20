CREATE OR REPLACE PACKAGE PL_SPL_SEND_RECEIVE_MSGS AS
  /*===========================================================================================================
  -- Package 
  -- PL_SPL_SEND_RECEIVE_MSGS
  --
  -- Description
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment

  -- 08/10/18        mc1213                                       make one version for FP and non-FP opco
  -- 09/04/18        mc1213                                       for sys_config table query for config_flag_name = 'ENABLE_FOODPRO'
  --                                                                and config_flag_val= 'Y';
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   08/10/18       mc1213        make one version for FP and non-FP opco
  --   09/04/18       mc1213        for sys_config table query for config_flag_name = 'ENABLE_FOODPRO'
  --                                and config_flag_val= 'Y';
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/
--
-- This procedue is called via job every minute, it sends all the non processed messages to respective mq servers
--
  --PROCEDURE send_message(i_job_group IN NUMBER );
  PROCEDURE send_message;
--
-- This procedue is called via job every minute, it receives all the messages from respective mq servers
--
  --PROCEDURE receive_message(i_job_group IN NUMBER);
  PROCEDURE receive_message;

END PL_SPL_SEND_RECEIVE_MSGS;






/


CREATE OR REPLACE PACKAGE BODY PL_SPL_SEND_RECEIVE_MSGS
  /*===========================================================================================================
  -- Package Body
  -- PL_SPL_SEND_RECEIVE_MSGS
  --
  -- Description
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 
  ============================================================================================================*/
IS

PROCEDURE send_message
--PROCEDURE send_message(i_job_group IN NUMBER)
  /*===========================================================================================================
  -- Procedure
  -- send_message
  --
  -- Description
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  -- 
  ============================================================================================================*/
IS

 This_Proc     CONSTANT  VARCHAR2(30)   := 'send_message';
 This_Message            VARCHAR2(2000);
 l_sequence_number       NUMBER; -- stagging table sequence no
 m_sequence_number       mq_queue_out.prim_seq_no%type;
 l_error_msg             VARCHAR2(100);
 l_error_code            VARCHAR2(100);

 --AQ parameters--
 l_enqueue_options       DBMS_AQ.enqueue_options_t;
 l_message_properties    DBMS_AQ.message_properties_t;
 l_message_handle        RAW(16);
 l_payload               queue_char_type; 

 l_payload_mq            sys.mgw_basic_msg_t;
 header                  sys.mgw_name_value_array_t;
 text_body               sys.mgw_text_value_t;

 rec_no                  number :=0;
 commit_no               number := 1000;
 l_que_name              mq_queue_out.queue_name%type;

 t_count                 number := 0; -- mcha1213 8/10/18

 ------------------------------------------------------
 CURSOR c_get_messages
     IS
 SELECT mqo.sequence_number sequence_number, mqo.queue_name queue_name, mqo.queue_data queue_data, mqo.prim_seq_no psn
   FROM mq_queue_out mqo, mq_interface_maint mim
  WHERE mqo.record_status     = 'N'
    AND mqo.queue_name        = mim.aq_queue_name
	AND mim.aq_queue_name like 'Q_SPL%'
	ORDER BY mqo.add_date,mqo.sequence_number;
    --AND mim.job_group         = i_job_group;

 send_error              EXCEPTION;

BEGIN

		begin

          select count(*)
          into t_count
          from sys_config
          where config_flag_name = 'ENABLE_FOODPRO'
		  and config_flag_val= 'Y';

          /*
          pl_log.ins_msg('INFO', 'PL_SPL_SEND_RECEIVE_MSGS.send_message',
                        't_count =' ||to_char(t_count),
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N'); 
          */

          /*
          if t_count >= 1 then

             l_payload := queue_char_type(c_get.queue_data);	

              --dbms_output.put_line(' this is foodpro');
          elsif t_count = 0 then

		     text_body := sys.mgw_text_value_t(NULL, c_get.queue_data);

             l_payload_mq := sys.mgw_basic_msg_t(header,     --can be null(settings) 
	                                    text_body,  --actual text
										NULL);  
        --dbms_output.put_line(' this is NONE foodpro');
          end if;

          */

        exception
        WHEN OTHERS THEN
    --dbms_output.put_line(' in when others exception '||SUBSTR(SQLERRM,1,100));
           l_error_msg:= 'Error: pl_spl_send_receive_msgs.send_message checking FP or not when others Exception ';
           l_error_code:= SUBSTR(SQLERRM,1,100);   
           pl_log.ins_msg(pl_log.ct_fatal_msg, 'send_message', l_error_msg,
											SQLCODE, SQLERRM,
											'send_message',
											'pl_spl_send_receive_msgs',
											'N');
           RAISE send_error;											
        end;							



 FOR c_get IN c_get_messages
 LOOP

   begin -- 8/16/18 

     l_sequence_number := c_get.sequence_number;

     m_sequence_number := c_get.psn;
     l_que_name := c_get.queue_name;



        BEGIN

	       --l_payload := queue_char_type(c_get.queue_data);

           dbms_output.put_line('in pl_spl_send_receive_msgs.send_message before enqueue'); 


          if t_count >= 1 then

             l_payload := queue_char_type(c_get.queue_data);

            DBMS_AQ.enqueue(queue_name          => c_get.queue_name,        
                       enqueue_options     => l_enqueue_options,     
                       message_properties  => l_message_properties,   
                       payload             => l_payload,             
                       msgid               => l_message_handle);


          elsif t_count = 0 then

		     text_body := sys.mgw_text_value_t(NULL, c_get.queue_data);

             l_payload_mq := sys.mgw_basic_msg_t(header,     --can be null(settings) 
	                                    text_body,  --actual text
										NULL);  

            DBMS_AQ.enqueue(queue_name          => c_get.queue_name,        
                       enqueue_options     => l_enqueue_options,     
                       message_properties  => l_message_properties,   
                       payload             => l_payload_mq,             
                       msgid               => l_message_handle);                                        

          end if;


           dbms_output.put_line('in pl_spl_send_receive_msgs.sned_message after enqueue');                        

        EXCEPTION
	       WHEN OTHERS THEN

              l_error_msg := 'Error: Enqueing the message to the Oracle AQ for the prim_seq_no:'||m_sequence_number;
              l_error_code:= SUBSTR(SQLERRM,1,100);
              pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                        l_error_msg,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');    
               RAISE send_error;
        END;	                       


        BEGIN

           UPDATE mq_queue_out
                SET record_status    = 'S'
                WHERE prim_seq_no  = m_sequence_number;


        EXCEPTION
           WHEN OTHERS THEN

             l_error_msg := 'Error: Updating the Record status to S after sending the message for stagging table '||c_get.queue_name||
                   ' sequence number '||to_char(l_sequence_number);
             l_error_code:= SUBSTR(SQLERRM,1,100);
             pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                        l_error_msg,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');         

            RAISE send_error;
        END;                       


        rec_no := rec_no + 1;

        if (rec_no = commit_no) then

          commit;

              /*
	      pl_log.ins_msg('INFO', 'PL_SPL_SEND_RECEIVE_MSGS.send_message',
                        'after commit for number of records '||rec_no|| ' for queue:'||c_get.queue_name,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');              
              */
          rec_no :=0; 

         end if;    

    exception   
       WHEN send_error THEN
          UPDATE mq_queue_out
            SET record_status   = 'F',
            error_msg       = l_error_msg,
            error_code      = l_error_code
          WHERE prim_seq_no = m_sequence_number;

          COMMIT;

       WHEN OTHERS THEN
          pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                  'Unexpected Error Obtained while processing send_message',
                  SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N'); 
    END;           

 END LOOP;

 commit;

EXCEPTION
  WHEN OTHERS THEN
    pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                  'Unexpected Error Obtained while processing send_message',
                  SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');

END send_message;

PROCEDURE receive_message
--PROCEDURE receive_message(i_job_group IN NUMBER)
  /*===========================================================================================================
  -- Procedure
  -- receive_message
  --
  -- Description
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  -- 
  ============================================================================================================*/
IS

 This_Proc     CONSTANT  VARCHAR2(30)   := 'receive_message';
 This_Message            VARCHAR2(2000);
 l_queue_name            mq_interface_maint.aq_queue_name%TYPE;
 l_error_msg             VARCHAR2(100);
 l_error_code            VARCHAR2(100);
 l_data                  CLOB;
 l_exit_loop             NUMBER := 0;

 --AQ parameters--
 l_dequeue_options       dbms_aq.dequeue_options_t;
 l_message_properties    dbms_aq.message_properties_t;
 l_message_handle        RAW(16);
 l_payload               queue_char_type; --sys.mgw_basic_msg_t;
 l_payload_mq            sys.mgw_basic_msg_t;

 --text_body               sys.mgw_text_value_t;
 commit_no               number := 1000;
 rec_no                  number :=0;

 t_count                 number := 0; -- mcha1213 8/10/18

 ------------------------------------------------------
 No_Messages             EXCEPTION;
 PRAGMA EXCEPTION_INIT( No_Messages, -25228 ) ;

 CURSOR c_get_queue_name
     IS
 SELECT aq_queue_name
   FROM mq_interface_maint
  WHERE propagation_type  =  1
   and aq_queue_name like 'Q_SPL%';
    --AND job_group         =  i_job_group;

BEGIN

   begin

     select count(*)
     into t_count
     from sys_config
     where config_flag_name = 'ENABLE_FOODPRO'
	 and config_flag_val= 'Y';

     /*
     pl_log.ins_msg('INFO', 'PL_SPL_SEND_RECEIVE_MSGS.receive_message',
                        't_count =' ||to_char(t_count),
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');  
     */

     /*
     if t_count >= 1 then
        l_data := l_payload.que_message;			    
        --dbms_output.put_line(' this is foodpro');
     elsif t_count = 0 then
	    l_data := l_payload_mq.text_body.small_value;
        --dbms_output.put_line(' this is NONE foodpro');
     end if;
     */

   exception
   WHEN OTHERS THEN
    --dbms_output.put_line(' in when others exception '||SUBSTR(SQLERRM,1,100));
    l_error_msg:= 'Error: pl_spl_send_receive_msgs.receive_message checking FP or not when others Exception ';
    l_error_code:= SUBSTR(SQLERRM,1,100);   
    pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_im', l_error_msg,
											SQLCODE, SQLERRM,
											'receive_message',
											'pl_spl_send_receive_msgs',
											'N');
   end;							


 FOR I IN c_get_queue_name
 LOOP

     l_queue_name := I.aq_queue_name;

	/* header := sys.mgw_name_value_array_t(
       sys.mgw_name_value_t.construct_integer(?MGW_MQ_characterSet?, ?1208?),
       sys.mgw_name_value_t.construct_integer(?MGW_MQ_priority?, ?7?)
                                            );*/ --Not needed
     l_dequeue_options.wait       := DBMS_AQ.NO_WAIT;
     --l_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;



	   BEGIN 
        LOOP 


         if t_count >=1 then
    	  --dequeing the message
          DBMS_AQ.dequeue(queue_name          => l_queue_name,
                          dequeue_options     => l_dequeue_options,
                          message_properties  => l_message_properties,
                          payload             => l_payload,
                          msgid               => l_message_handle);

          l_data := l_payload.que_message;	

         elsif t_count = 0 then   

            DBMS_AQ.dequeue(queue_name          => l_queue_name,
                          dequeue_options     => l_dequeue_options,
                          message_properties  => l_message_properties,
                          payload             => l_payload_mq,
                          msgid               => l_message_handle);

            /*  SMOD-446: 
                small_value of MGW_TEXT_VALUE_T received as NULL when the String length is greater than 4000. 
                In this scenario, we need to extract the value from large_value of MGW_TEXT_VALUE_T.
            */
             l_data := NVL(l_payload_mq.text_body.small_value, l_payload_mq.text_body.large_value);

         end if;    



          INSERT 
		    INTO mq_queue_in(queue_name, queue_data) 
		  VALUES            (l_queue_name, l_data);

		  -- m.c put after the loop COMMIT;

		  l_data := NULL;

		  -- exit condition(for uncertain events just to make sure it is not stuck for ever)
		  l_exit_loop := l_exit_loop + 1;
		  IF l_exit_loop > 10000 THEN
		   EXIT;
		  END IF; 

          rec_no := rec_no +1;

          if (rec_no = commit_no) then

             commit;
          
             /*
             pl_log.ins_msg('INFO', 'PL_SPL_SEND_RECEIVE_MSGS.receive_message',
                        'after commit for number of records '||rec_no|| ' for queue:'||l_queue_name,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N'); 
             */

             rec_no :=0;
          end if;   


		END LOOP;

		commit;

	   EXCEPTION
	    WHEN No_Messages THEN
	     pl_log.ins_msg('INFO', 'PL_SPL_SEND_RECEIVE_MSGS',
                        'End of fetch: No more messages to get for the Queue:'||l_queue_name,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');
	    WHEN OTHERS THEN
	     --ROLLBACK;
	     l_error_msg := 'Error: Dequeing the message from the Oracle AQ for the queue:'||l_queue_name;
         pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                        l_error_msg,
                         SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');
       END;

 END LOOP;

 commit; -- 7/12/18

EXCEPTION
  WHEN OTHERS THEN
   pl_log.ins_msg('WARN', 'PL_SPL_SEND_RECEIVE_MSGS',
                  'Unexpected Error Obtained while processing receive_message',
                  SQLCODE, SQLERRM, 'INTERFACES', This_Proc, 'N');
END receive_message;

END PL_SPL_SEND_RECEIVE_MSGS;

/
