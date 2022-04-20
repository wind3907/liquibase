/****************************/
---Package specification SYS06 is Symbotic Matrix CASE REMOVAL
/****************************/

CREATE OR REPLACE PACKAGE swms.pl_matrix_sys06 IS

g_jkpt_case_exists  BOOLEAN;
g_error             NUMBER :=0;
g_jackpot_loc       mx_float_detail_cases.spur_location%TYPE;
g_iRc               NUMBER := 0;
/* CONSTANT SOS_E_SEND_BATCH==>523 */

FUNCTION ck_jkpt_case_exists (i_batch_no IN VARCHAR2, 
			      i_case_id  IN NUMBER,
			      o_jackpot_loc  OUT VARCHAR2) RETURN BOOLEAN;

FUNCTION removing_case (i_batch_no      IN VARCHAR2, 
		        i_case_id       IN NUMBER,
		        i_spur_location IN VARCHAR2,
                        i_prod_id       IN VARCHAR2,
			i_hsShortInd    IN VARCHAR2,
			i_order_seq     IN NUMBER,
			i_float_detail_seq_no IN NUMBER,
			i_status        IN VARCHAR2,
			o_send_sos_msg  OUT BOOLEAN) RETURN NUMBER;

END pl_matrix_sys06;
/
show errors

--Package Body SYS06 INTERFACE IS CASE REMOVAL FROM SPUR AS SELECTOR SCAN
CREATE OR REPLACE PACKAGE BODY swms.pl_matrix_sys06 IS

FUNCTION removing_case (i_batch_no      IN VARCHAR2, 
		        i_case_id       IN NUMBER,
		        i_spur_location IN VARCHAR2,
		        i_prod_id       IN VARCHAR2,
			i_hsShortInd    IN VARCHAR2,
			i_order_seq     IN NUMBER,
			i_float_detail_seq_no IN NUMBER,
			i_status        IN VARCHAR2,
			o_send_sos_msg  OUT BOOLEAN) RETURN NUMBER IS

 l_remaining_case   number := 0;
 l_tot_fd_rec		number;
 l_picked_fd_rec	number;
 l_short_fd_rec		number;
 l_stage_fd_rec		number;
 l_cnt_msg              number;
 l_spur_location        loc.logi_loc%TYPE;

 cursor get_src_loc is
 select src_loc
 from float_detail 
 where order_seq = i_order_seq
 and   seq_no = i_float_detail_seq_no;

begin
   l_spur_location := i_spur_location;

   if i_status = 'NEW' and nvl(l_spur_location,'XX') not like 'SP%' then
      /* i_spur_location will be null if status is NEW */
      open get_src_loc;
      fetch get_src_loc into l_spur_location;
      if get_src_loc%NOTFOUND then
            Pl_Text_Log.ins_msg ('WARN', 'pl_matrix_sys06.sql', 'Failed to find spur location in float_detail for get_src_loc cursor. Batch# '||i_Batch_No, SQLCODE, SQLERRM);
      end if;
      close get_src_loc;
   end if;
   UPDATE mx_float_detail_cases
       SET status = 'STG',
           selector_id = replace(USER,'OPS$',null)
       WHERE case_id = i_case_id
         AND order_seq = i_order_seq
             AND float_detail_seq_no = i_float_detail_seq_no ;

  g_jkpt_case_exists := ck_jkpt_case_exists(i_batch_no,i_case_id,g_jackpot_loc);



  /*Check the remaining cases for the batch_no, if 0 update the batch complete for spur monitor*/         
  SELECT COUNT(*)
   INTO l_remaining_case
   FROM mx_float_detail_cases
  WHERE status NOT IN ('PIK' , 'SHT', 'STG') /* adding STG for staging */
    AND float_no IN (SELECT float_no 
                       FROM floats
                      WHERE batch_no = i_batch_no);  
                  
   if  l_remaining_case = 0 then
       UPDATE mx_batch_info
          SET status = 'PIK'
        WHERE batch_no = i_batch_no
          AND batch_type = 'O';   
   end if;           

   /*Refresh SPUR monitor*/   
       BEGIN
           /*if case picked from Jackpot lane, find the actual spur location of batch and refresh*/
           IF TRIM(l_spur_location) LIKE 'SP%J%' THEN
               DECLARE
                   l_spur_location     mx_batch_info.spur_location%TYPE;
                   l_cnt               NUMBER;
               BEGIN
                   SELECT COUNT(*)
                     INTO l_cnt
                     FROM mx_float_detail_cases
                    WHERE batch_no = i_batch_no
                      AND case_id = i_case_id;
                               
                   IF l_cnt > 0 THEN  
                       SELECT spur_location
                         INTO l_spur_location
                         FROM mx_batch_info
                        WHERE batch_no =  i_batch_no
                          AND batch_type = 'O';
                   ELSE    
                       SELECT spur_location
                         INTO l_spur_location
                         FROM mx_batch_info
                        WHERE batch_no = i_batch_no
                          AND batch_type = 'R';
                   END IF;
                   
                   COMMIT;
                   
                   pl_matrix_common.refresh_spur_monitor(l_spur_location);
               EXCEPTION
                   WHEN NO_DATA_FOUND THEN
              Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_sys06.sql', 'Failed to refresh SPUR monitor, unable to find SPUR location of batch '||i_Batch_No, SQLCODE, SQLERRM);
               END;  
           ELSE    
               /*Making the batch active on SPUR monitor, if it is not*/ 
               DECLARE
                   l_cnt               NUMBER;
                   l_min_seq_number    NUMBER;
               BEGIN
                   SELECT COUNT(*)
                     INTO l_cnt
                     FROM mx_batch_info 
                    WHERE spur_location = l_spur_location
                      AND batch_no = i_batch_no
                      AND batch_type = 'O'
                      AND status = 'AVL'
                      AND sequence_number IN (SELECT MIN(sequence_number) 
                                       FROM mx_batch_info 
                                               WHERE status = 'AVL' 
                                                 AND spur_location = l_spur_location);
                                   
                   /*Batch is not active on SPUR*/             
                   IF l_cnt = 0 THEN
                       Pl_Text_Log.ins_msg ('I', 'pl_matrix_sys06.sql', 'Making Batch '||i_batch_no||' active on SPUR MOnitor '||l_spur_location, NULL, NULL);
                                
                       SELECT MIN(sequence_number) - 1 
                         INTO l_min_seq_number
                         FROM mx_batch_info;
                         
                       UPDATE mx_batch_info 
                          SET sequence_number = l_min_seq_number
                        WHERE batch_no = i_batch_no
                          AND batch_type = 'O';
                   END IF;
               EXCEPTION
                   WHEN OTHERS THEN
                       Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_sys06.sql', 'Failed to Update mx_batch_info for batch '||i_batch_no, SQLCODE, SQLERRM);
               END;
               
               COMMIT;
               pl_matrix_common.refresh_spur_monitor(l_spur_location);    
           END IF;
       END;

 if g_jkpt_case_exists then
     /* Refresh Jackpot Monitor*/
         DECLARE
             l_result        NUMBER;
             l_msg_text      VARCHAR2(512);
             l_err_msg       VARCHAR2(32767);
         BEGIN          
                l_result:= pl_digisign.BroadcastJackpotUpdate (g_jackpot_loc, l_err_msg);
 
                IF l_result != 0 THEN
                   l_msg_text := 'Error calling pl_digisign.BroadcastJackpotUpdate from pl_matrix_sys06.sql';
                   Pl_Text_Log.ins_msg ('FATAL', 'pl_matrix_sys06.sql', l_msg_text, NULL, l_err_msg);
                END IF;                               
         END;
 end if;

     /*SEND message SYS06 - Case removed form SPUR to Matrix*/
        DECLARE 
           l_ret_val    NUMBER;
           l_sys_msg_id NUMBER;
       BEGIN
         g_error := 0;
         l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                         
         l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                           i_interface_ref_doc => 'SYS06',
                                                           i_rec_ind => 'S',     
                                                           i_batch_id => i_batch_no, 
                                                           i_prod_id => i_prod_id,
                                                           i_case_barcode => i_case_id,
                                                           i_spur_loc => l_spur_location,
                                                           i_case_grab_tstamp => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')); 
                
            IF l_ret_val = 1 THEN  
                g_error := 1;
            ELSE       
                COMMIT;
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                            
                IF l_ret_val = 1 THEN  
                    g_error := 1;                            
                END IF;
            END IF; 
        END;
                
    if g_error = 1 then
       Pl_Text_log.ins_msg('FATAL','pl_matrix_sys06.sql',
                'Failed to send SYS06-Case removed from SPUR message to Matrix. Case_id: ' || 
                 to_char(i_case_id) || '  Prod ID: ' || i_prod_id || '  Batch ID:' || i_batch_no, SQLCODE, SQLERRM);
        /* iRc = SOS_E_SEND_BATCH==>523; */
       g_iRc := 523; 
    else 
       g_iRc := 0;
    end if;

    /* Initialize variable to determine to send message or not. Send selector message if TRUE */
    o_send_sos_msg := FALSE;

 /* Check the number of cases are picked up for batch, if first case picked then 
    then send batch started SYS07 message and if this is last case then send batch completed SYS07 message*/ 

        SELECT COUNT(a), COUNT(b)
          INTO l_tot_fd_rec, l_picked_fd_rec
          FROM ( SELECT 1 a, DECODE(status, 'PIK', 1, 'SHT', 1, 'STG', 1, NULL) b
                   FROM mx_float_detail_cases fd
                  WHERE (  (i_hsShortInd <> 'S'
               AND float_no in (SELECT float_no 
                                  FROM floats
                                 WHERE batch_no =  RTRIM (i_Batch_No)))
                         OR (i_hsShortInd = 'S'
                           AND float_no in (SELECT f.float_no 
                                              FROM floats f,sos_short s
                                             WHERE f.batch_no = to_number(s.batch_no)
                                               AND s.short_batch_no=  RTRIM (i_Batch_No)
                                               AND fd.order_seq = s.orderseq))
                        )
               );
                
    if (l_picked_fd_rec = 1) then  /*First case picked then send batch started SYS07 message*/
        /*SEND message SYS07 - Batch started message to Symbotic*/
            DECLARE 
                l_ret_val    NUMBER;
                l_sys_msg_id NUMBER;
            BEGIN
		o_send_sos_msg := TRUE;
                g_error := 0;
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                 
                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                      i_interface_ref_doc => 'SYS07',
                                                      i_rec_ind => 'S',         
                                                      i_batch_id => i_Batch_No,
                                                      i_batch_comp_tstamp =>  TO_CHAR(SYSTIMESTAMP, 'DD-MM-YYYY HH:MI:SS:ff9 AM'),
                                                      i_batch_status => 'STARTED');                                                       
                        
                IF l_ret_val = 1 THEN  
                    g_error := 1;
    		ELSE       
                    COMMIT;
                    l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                                
                    IF l_ret_val = 1 THEN  
                        g_error := 1;                            
                    END IF;
                END IF; 
            END;
               if (g_error = 1) then
                  Pl_Text_log.ins_msg('FATAL','pl_matrix_sys06.sql','Failed to send SYS07-Batch started message to Matrix. Batch#:' || i_batch_no,SQLCODE, SQLERRM);
                        --iRc = SOS_E_SEND_BATCH==>523;
                  g_iRc := 523;
               end if;
    end if; /* l_picked_fd_rec = 1 condition */
                
      SELECT COUNT(*)
        INTO l_cnt_msg
        FROM matrix_out
       WHERE batch_id = i_Batch_No
         AND interface_ref_doc = 'SYS07'
         AND batch_status = 'COMPLETED';
                   
      /*Last case picked then send batch completed SYS07 message*/
      if l_tot_fd_rec=l_picked_fd_rec and l_tot_fd_rec != 0 and l_cnt_msg = 0 then
          UPDATE mx_batch_info
             SET status = 'PIK'
           WHERE batch_no = i_Batch_No
             AND batch_type = 'O';   
                       
                
          /*SEND message SYS07 - Batch Completed message to Symbotic*/
              DECLARE 
                  l_ret_val    NUMBER;
                  l_sys_msg_id NUMBER;
              BEGIN
                 g_error := 0;
                  l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                   
                  l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                    i_interface_ref_doc => 'SYS07',
                                                                    i_rec_ind => 'S',         
                                                                    i_batch_id => i_Batch_No,
                            i_batch_comp_tstamp =>  TO_CHAR(SYSTIMESTAMP, 'DD-MM-YYYY HH:MI:SS:ff9 AM'),
                                                          i_batch_status => 'COMPLETED');                                                         
                        
                  IF l_ret_val = 1 THEN  
                      g_error := 1;
                  ELSE       
                      COMMIT;
                      l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                                
                      IF l_ret_val = 1 THEN  
                          g_error := 1;                            
                      END IF;
                  END IF; 
              END;
                
          if (g_error = 1) then
              Pl_Text_log.ins_msg('FATAL','pl_matrix_sys06.sql','Failed to send SYS07-Batch COMPLETED message to Matrix. Batch#:' || i_batch_no,SQLCODE, SQLERRM);
                        --iRc = SOS_E_SEND_BATCH==>523;
                  g_iRc := 523;
          end if; 
    end if; /* l_tot_fd_rec=l_picked_fd_rec and l_tot_fd_rec != 0 and l_cnt_msg = 0 */
    return(g_iRc);
end removing_case;


FUNCTION ck_jkpt_case_exists (i_batch_no     IN VARCHAR2, 
			      i_case_id      IN NUMBER,
			      o_jackpot_loc  OUT VARCHAR2) RETURN BOOLEAN IS

  l_cnt_jackpot_cases  number := 0;

BEGIN

            /*Delete from jackpot spur monitor if exists*/
                SELECT COUNT(*)
                  INTO l_cnt_jackpot_cases
                  FROM digisign_jackpot_monitor
                 WHERE case_barcode = i_case_id;
            
            if  l_cnt_jackpot_cases > 0 then
                    SELECT location
                      INTO o_jackpot_loc
                      FROM digisign_jackpot_monitor
                      WHERE case_barcode = i_case_id
                       AND ROWNUM = 1;                   
                      
                /*Delete from jackpot spur monitor if exists*/
                    DELETE FROM digisign_jackpot_monitor
                      WHERE case_barcode = i_case_id;
                     
                return(TRUE);
            else
		o_jackpot_loc := 'NA';
		return(FALSE);
            end if;
END ck_jkpt_case_exists;

END pl_matrix_sys06;
/
show errors;
