CREATE OR REPLACE PACKAGE swms.pl_matrix_order IS
    PROCEDURE send_wave(i_wave_number IN NUMBER);

    PROCEDURE send_batch(i_wave_number IN NUMBER, i_batch_id IN VARCHAR2);

    FUNCTION wait_for_SYS15_response(i_sys_msg_id IN VARCHAR2, i_max_wait_time IN NUMBER)
      RETURN NUMBER;

    FUNCTION wait_for_SYS04_response(i_wave_number IN NUMBER, i_max_wait_time IN NUMBER)
      RETURN NUMBER;
END;
/

CREATE OR REPLACE PACKAGE BODY swms.pl_matrix_order IS

    PROCEDURE send_wave(i_wave_number IN NUMBER)
    IS
        CURSOR c_sys15 IS
        SELECT sys_msg_id, wave_number, batch_status
          FROM matrix_out
         WHERE interface_ref_doc = 'SYS15'
           AND record_status = 'N'
         ORDER BY add_date, sequence_number;

        CURSOR c_sys04 (p_wave_number NUMBER) IS
        SELECT distinct sys_msg_id
          FROM matrix_out
         WHERE interface_ref_doc = 'SYS04'
           AND wave_number = p_wave_number
           AND record_status = 'N'
         ORDER BY sys_msg_id;

        l_ret_val  NUMBER;
        l_msg_text VARCHAR2(132);
        l_fname    VARCHAR2 (50)   := 'send_orders_to_matrix';
        ct_program_code VARCHAR2(30) := 'pl_matrix_order.send_wave';

        e_fail     EXCEPTION;   

        max_sys04_wait_time NUMBER := 300;
        max_sys15_wait_time NUMBER := 60;
    BEGIN
        FOR r_sys15 IN c_sys15 LOOP
            IF r_sys15.wave_number != NVL(i_wave_number,r_sys15.wave_number) THEN
                l_msg_text := 'Prog Code: ' || l_fname || '  ' ||
                              'Unable to process wave ' || TO_CHAR(i_wave_number) || '.  Wave ' ||
                              TO_CHAR(r_sys15.wave_number) || ' is already in progress.';

                pl_symbotic_alerts.raise_alert('SYS15', r_sys15.sys_msg_id, NULL, l_msg_text);

                dbms_scheduler.create_job (job_name    =>  dbms_scheduler.generate_job_name('MX_ORD_W'||
                                                           TO_CHAR(i_wave_number)||'_'),  
                                           job_type    =>  'PLSQL_BLOCK',  
                                           job_action  =>  'BEGIN swms.pl_matrix_order.send_wave('||
                                                           TO_CHAR(i_wave_number)||'); END;',  
                                           start_date  =>  SYSDATE + (5 / (24 * 60)),  -- Retry job in 5 minutes.
                                           enabled     =>  TRUE,  
                                           auto_drop   =>  TRUE,  
                                           comments    =>  'Submitting a job to invoke MX_ORD_W'||TO_CHAR(i_wave_number)||
                                                           ' in five minutes.');

                RAISE e_fail;
            END IF;

            IF r_sys15.batch_status = 'STARTED' THEN
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys15.sys_msg_id);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Unable to send the SYS15 Started message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                l_ret_val := wait_for_SYS15_response(r_sys15.sys_msg_id, max_sys15_wait_time);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Timeout waiting for response to SYS15 Started message for wave_number ' ||
                                  TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                FOR r_sys04 IN c_sys04 (r_sys15.wave_number) LOOP
                    l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys04.sys_msg_id);
                    IF l_ret_val = 1 THEN
                        l_msg_text := 'Prog Code: ' || l_fname ||
                                      ' Unable to send the message SYS15 Started for wave_number ' || TO_CHAR(r_sys15.wave_number);
                        RAISE e_fail;
                    END IF;
                END LOOP;

                l_ret_val := wait_for_SYS04_response(r_sys15.wave_number, max_sys04_wait_time);
                IF l_ret_val = 1 THEN
                   l_msg_text := 'Prog Code: ' || l_fname ||
                                 ' Timeout waiting for response to SYS04 messages for wave_number ' || TO_CHAR(r_sys15.wave_number);
                   RAISE e_fail;
                END IF;
            ELSIF r_sys15.batch_status = 'COMPLETED' THEN
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys15.sys_msg_id);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Unable to send the SYS15 Completed message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                l_ret_val := wait_for_SYS15_response(r_sys15.sys_msg_id, max_sys15_wait_time);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Timeout waiting for response to SYS15 Completed message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN e_fail THEN
             pl_text_log.ins_msg('WARN',Ct_Program_Code,l_msg_text, 0, NULL);      
    END send_wave;


    PROCEDURE send_batch(i_wave_number IN NUMBER, i_batch_id IN VARCHAR2)
    IS
        CURSOR c_sys15 IS
        SELECT sys_msg_id, wave_number, batch_status
          FROM matrix_out
         WHERE interface_ref_doc = 'SYS15'
           AND wave_number = i_wave_number
           AND record_status = 'N'
         ORDER BY add_date, sequence_number;

        CURSOR c_sys04 IS
        SELECT distinct sys_msg_id
          FROM matrix_out
         WHERE interface_ref_doc = 'SYS04'
           AND batch_id = i_batch_id
           AND record_status = 'N'
         ORDER BY sys_msg_id;

        l_ret_val  NUMBER;
         l_time    VARCHAR2(6);
        l_msg_text VARCHAR2(132);
        l_fname    VARCHAR2 (50)   := 'send_orders_to_matrix';
        ct_program_code VARCHAR2(30) := 'pl_matrix_order.send_batch';

        e_fail     EXCEPTION;   

        max_sys04_wait_time NUMBER := 300;
        max_sys15_wait_time NUMBER := 60;
    BEGIN
        FOR r_sys15 IN c_sys15 LOOP
            IF r_sys15.wave_number != NVL(i_wave_number,r_sys15.wave_number) THEN
                l_time := TO_CHAR(SYSDATE,'HH24MI');
                l_msg_text := 'Prog Code: ' || l_fname || '  ' ||
                              'Unable to process wave ' || TO_CHAR(i_wave_number) || '.  Wave ' ||
                              TO_CHAR(r_sys15.wave_number) || ' is already in progress.';

                pl_symbotic_alerts.raise_alert('SYS15', r_sys15.sys_msg_id, NULL, l_msg_text);

                dbms_scheduler.create_job (job_name    =>  dbms_scheduler.generate_job_name('MX_ORD_B'||i_batch_id||
                                                           '_'||l_time),  
                                           job_type    =>  'PLSQL_BLOCK',  
                                           job_action  =>  'BEGIN swms.pl_matrix_order.send_batch('||
                                                           TO_CHAR(i_wave_number)||','''||i_batch_id||'''); END;',  
                                           start_date  =>  SYSDATE + (5 / (24 * 60)),  -- Retry job in 5 minutes.
                                           enabled     =>  TRUE,  
                                           auto_drop   =>  TRUE,  
                                           comments    =>  'Submitting a job to invoke MX_ORD_B'||TO_CHAR(i_wave_number)||
                                                           '_'||l_time||' in five minutes.');

                RAISE e_fail;
            END IF;

            IF r_sys15.batch_status = 'STARTED' THEN
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys15.sys_msg_id);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Unable to send the SYS15 Started message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                l_ret_val := wait_for_SYS15_response(r_sys15.sys_msg_id, max_sys15_wait_time);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Timeout waiting for response to SYS15 Started message for wave_number ' ||
                                  TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                FOR r_sys04 IN c_sys04 LOOP
                    l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys04.sys_msg_id);
                    IF l_ret_val = 1 THEN
                        l_msg_text := 'Prog Code: ' || l_fname ||
                                      ' Unable to send the message SYS15 Started for wave_number ' || TO_CHAR(r_sys15.wave_number);
                        RAISE e_fail;
                    END IF;
                END LOOP;

                l_ret_val := wait_for_SYS04_response(r_sys15.wave_number, max_sys04_wait_time);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Timeout waiting for response to SYS04 messages for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;
            ELSIF r_sys15.batch_status = 'COMPLETED' THEN
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => r_sys15.sys_msg_id);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Unable to send the SYS15 Completed message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;

                l_ret_val := wait_for_SYS15_response(r_sys15.sys_msg_id, max_sys15_wait_time);
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Timeout waiting for response to SYS15 Completed message for wave_number ' || TO_CHAR(r_sys15.wave_number);
                    RAISE e_fail;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN e_fail THEN
             pl_text_log.ins_msg('WARN',Ct_Program_Code,l_msg_text, 0, NULL);      
    END send_batch;


    FUNCTION wait_for_SYS15_response(i_sys_msg_id IN VARCHAR2, i_max_wait_time IN NUMBER)
      RETURN NUMBER IS
        l_wait_cnt     NUMBER;
        l_ret_val      NUMBER;
        l_start_time   DATE;
        l_current_time DATE;
        l_elapsed_time NUMBER;
    BEGIN
        l_ret_val := 0;

        SELECT SYSDATE INTO l_current_time FROM DUAL;
        dbms_lock.sleep(3);  -- sleep 3 seconds;

        LOOP
            SELECT COUNT(*) INTO l_wait_cnt
              FROM matrix_out
             WHERE sys_msg_id = i_sys_msg_id
               AND record_status IN ('N','Q');

            IF l_wait_cnt = 0 THEN
                EXIT;
            END IF;

            SELECT SYSDATE INTO l_current_time FROM DUAL;

            l_elapsed_time := FLOOR((l_current_time - l_start_time) * 24 * 60 * 60);
            IF l_elapsed_time >= i_max_wait_time THEN
                dbms_output.put_line('Max time expired: ' || TO_CHAR(l_elapsed_time));
                l_ret_val := 1;
                EXIT;
            END IF;

            dbms_lock.sleep(5);  -- sleep 5 seconds;
        END LOOP;

        RETURN l_ret_val;
    END wait_for_SYS15_response;

    FUNCTION wait_for_SYS04_response(i_wave_number IN NUMBER, i_max_wait_time IN NUMBER)
      RETURN NUMBER IS
        l_wait_cnt     NUMBER;
        l_ret_val      NUMBER;
        l_start_time   DATE;
        l_current_time DATE;
        l_elapsed_time NUMBER;
    BEGIN
        l_ret_val := 0;

        SELECT SYSDATE INTO l_current_time FROM DUAL;
        dbms_lock.sleep(3);  -- sleep 3 seconds;

        LOOP
            SELECT COUNT(*)
              INTO l_wait_cnt
              FROM matrix_in i, matrix_out o
             WHERE i.batch_id(+) = o.batch_id
               AND i.rec_ind(+) = o.rec_ind
               AND NVL(i.prod_id(+),' ') = NVL(o.prod_id,' ')
               AND i.interface_ref_doc(+) = 'SYM16'
               AND o.interface_ref_doc = 'SYS04'
               AND NVL(o.rec_count,1) > 0
               AND o.record_status IN ('N','Q','S')
               AND i.add_date IS NULL
               AND o.wave_number = i_wave_number;

            IF l_wait_cnt = 0 THEN
                EXIT;
            END IF;

            SELECT SYSDATE INTO l_current_time FROM DUAL;

            l_elapsed_time := FLOOR((l_current_time - l_start_time) * 24 * 60 * 60);
            IF l_elapsed_time >= i_max_wait_time THEN
                dbms_output.put_line('Max time expired: ' || TO_CHAR(l_elapsed_time));
                l_ret_val := 1;
                EXIT;
            END IF;

            dbms_lock.sleep(5);  -- sleep 5 seconds;
        END LOOP;

        RETURN l_ret_val;
    END wait_for_SYS04_response;

END;
/
