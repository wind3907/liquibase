create or replace procedure swp_nonperfm_task_on_hold  IS

    cursor u_lst is     
    select batch_no, seq_no, task_id, labor_batch_no, prod_id, type, status, src_loc, dest_loc, pallet_id, gen_date,add_date
    from replenlst
    where type = 'SWP'    
    and seq_no = 1
    and status in ('PRE', 'NEW')
    order by batch_no, seq_no;


    swp_start sys_config.config_flag_val%type;
    swp_end sys_config.config_flag_val%type;
    o_no_batches_deleted  PLS_INTEGER;
    new_cnt number;
    pre_cnt number;
    message                   VARCHAR2(2000);
    l_no_batches_deleted  PLS_INTEGER;
    t_labor_batch_no     replenlst.labor_batch_no%type;


begin

    select nvl(min(config_flag_val),'07:00') , nvl(max(config_flag_val),'17:00')
    --min(config_flag_val), max(config_flag_val)
    into swp_start, swp_end
    from sys_config s
    where s.application_func = 'INVENTORY CONTROL'
    and s.config_flag_name in ('SWAP_WINDOW_START', 'SWAP_WINDOW_END');

     -- this is for production if to_char(sysdate, 'HH24:MI') not between swp_start and swp_end then 

     
     if (to_char(sysdate, 'HH24:MI') not between swp_start and swp_end ) then

        dbms_output.put_line('time to update to HLD for unperform tasks'); 
        
         pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'time to update to HLD for unperform tasks',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 

        for r_lst in u_lst loop

            --begin

            if r_lst.status = 'NEW' then

                begin

                    dbms_output.put_line('in r_lst loop batch '||r_lst.batch_no||' seq '||r_lst.seq_no||' status is NEW');
                    
                     pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'in r_lst loop batch '||r_lst.batch_no||' seq '||r_lst.seq_no||' status is NEW',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
                           
                    select labor_batch_no 
                    into t_labor_batch_no
                    from replenlst
                    where type = 'SWP'    
                    and seq_no = 2
                    and status = r_lst.status
                    and batch_no = r_lst.batch_no;  
                    
                    dbms_output.put_line('in r_lst loop batch '||r_lst.batch_no||' seq 1 status is NEW, seq2 labor_batch_no is '||t_labor_batch_no);  
                    
                     pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'in r_lst loop batch '||r_lst.batch_no||' seq 1 status is NEW, seq2 labor_batch_no is '||t_labor_batch_no,
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
                           
                                        
                      update replenlst
                      set status = 'HLD'
                      where batch_no = r_lst.batch_no
                      and seq_no in (1,2)
                      and status = 'NEW';

                      dbms_output.put_line('updated batch '||r_lst.batch_no||' seq 1,2 to HLD from NEW'); 
                      
                     pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'updated batch '||r_lst.batch_no||' seq 1,2 to HLD from NEW',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
                           
                        pl_lmf.delete_swap_batch(i_batch_no => t_labor_batch_no,
                                            o_no_batches_deleted  => l_no_batches_deleted);

                        dbms_output.put_line('after pl_lmf.delete_swap_batch 2nd seq labor_batch_no '||t_labor_batch_no||
                                  ' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted');
                       
                        pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'after pl_lmf.delete_swap_batch 2nd seq labor_batch_no '||t_labor_batch_no||
                                  ' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
                           
                     pl_lmf.delete_swap_batch(i_batch_no => r_lst.labor_batch_no,
                           o_no_batches_deleted  => l_no_batches_deleted);

                     dbms_output.put_line('after pl_lmf.delete_swap_batch 1st seq labor_batch_no '||r_lst.labor_batch_no||' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted');                             
                           
                     pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'after pl_lmf.delete_swap_batch 1st seq labor_batch_no '||r_lst.labor_batch_no||' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           );      
                exception
                    when no_data_found then
                       dbms_output.put_line('updated batch '||r_lst.batch_no||' seq 1 to HLD from NEW');
                      
                       pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'updated batch '||r_lst.batch_no||' seq 1 to HLD from NEW',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
                           
                      update replenlst
                      set status = 'HLD'
                      where batch_no = r_lst.batch_no
                      and seq_no =1
                      and status = 'NEW';                    
                    
                      dbms_output.put_line('updated batch '||r_lst.batch_no||' seq 1 to HLD from NEW');
                      
                       pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'updated batch '||r_lst.batch_no||' seq 1 to HLD from NEW',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           );
                           
                     pl_lmf.delete_swap_batch(i_batch_no => r_lst.labor_batch_no,
                           o_no_batches_deleted  => l_no_batches_deleted);

                     dbms_output.put_line('after pl_lmf.delete_swap_batch 1st seq labor_batch_no '||r_lst.labor_batch_no||' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted');                             
                           
                     pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'after pl_lmf.delete_swap_batch 1st seq labor_batch_no '||r_lst.labor_batch_no||' of batch no '||r_lst.batch_no||' '||l_no_batches_deleted||' deleted',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           );      
                   when others then 
      
							   message := 'WOT error from batch '||r_lst.batch_no||' NEW status'||sqlcode||' '||sqlerrm; 
							   dbms_output.put_line('message= '||message); 
                        
                                             pl_log.ins_msg(
								'FATAL',
								'swp_nonperfm_task_on_hold',
                        'in r_lst LOOP status is NEW WOT error ',
 								sqlcode,
								sqlerrm,
								'ORDER PROCESSING',
								'swp_nonperfm_task_on_hold',
								'u'
							    ); 

                end;


            elsif r_lst.status = 'PRE' then
            
               dbms_output.put_line('in r_lst loop batch '||r_lst.batch_no||' seq '||r_lst.seq_no||' status is PRE'); 

                    begin

                        select count(*)
                        into pre_cnt
                        from replenlst
                        where type = 'SWP'    
                        and seq_no = 2
                        and status = r_lst.status
                        and batch_no = r_lst.batch_no;

                        if pre_cnt =1 then
                        
                           update replenlst
                           set status = 'HLD'
                           where batch_no = r_lst.batch_no
                           and seq_no in (1,2)
                           and status = r_lst.status; 

                           dbms_output.put_line('will update batch '||r_lst.batch_no||' seq 1,2 to HLD from PRE');
                           
                        elsif pre_cnt=0 then
                    
                           update replenlst
                           set status = 'HLD'
                           where batch_no = r_lst.batch_no
                           and seq_no =1
                           and status = r_lst.status;                    
                    
                           dbms_output.put_line('updated batch '||r_lst.batch_no||' seq 1 to HLD from PRE'); 
                           
                         end if;   

                    exception
                        WHEN OTHERS THEN


                           message := 'WOT error from batch '||r_lst.batch_no||' PRE status'||sqlcode||' '||sqlerrm; 
                           dbms_output.put_line('message= '||message);  
                           
                           pl_log.ins_msg(
                           'FATAL',
                           'swp_nonperfm_task_on_hold',
                           'in r_lst LOOP status is PRE WOT error '||r_lst.batch_no,
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 


                    end;               



            end if;  -- r_lst.status NEW
            
         end loop; -- end r_lst loop   
         
       else
                   dbms_output.put_line('not time to update ');
                   
                   pl_log.ins_msg(
                           'INFO',
                           'swp_nonperfm_task_on_hold',
                           'not time to update to HLD for unperform tasks',
                           sqlcode,
                           sqlerrm,
                           'ORDER PROCESSING',
                           'swp_nonperfm_task_on_hold',
                           'u'
                           ); 
       end if;
        
        commit;                      
     
EXCEPTION
        WHEN OTHERS THEN

            message := 'WOT error from swp_nonperfm_task_on_hold '||sqlcode||' '||sqlerrm; 
            dbms_output.put_line('message= '||message);   
            
                                       
            pl_log.ins_msg(
                  'FATAL',
                  'swp_nonperfm_task_on_hold',
                  'WOT error from swp_nonperfm_task_on_hold ',
                  sqlcode,
                  sqlerrm,
                  'ORDER PROCESSING',
                  'swp_nonperfm_task_on_hold',
                  'u'
                  ); 



end;
/

create or replace public synonym swp_nonperfm_task_on_hold for swms.swp_nonperfm_task_on_hold;
