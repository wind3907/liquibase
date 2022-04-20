create or replace package swms.pl_rf_sys06_case_removal as
------------------------------------------------------------------
--  Modification History:
-- Date		Designer	Comments
-- ----------   -------------   -------------------------------------------------------------------
-- 05/25/2016   knha8378        need to set SYS06 Case Removal to Symbotic and then refresh SPUR
--				monitor screen 
 function VerifySOSBatch
 (
    i_rf_log_init_record            in swms.rf_log_init_record,
    i_batch_no			    in varchar2
 ) return swms.rf.STATUS;

 function RemoveCase
 (
    i_rf_log_init_record            in swms.rf_log_init_record,
    i_batch_no			    in varchar2,
    i_case_barcode                  in number
 ) return swms.rf.STATUS;
    
end pl_rf_sys06_case_removal;
/
show errors;


create or replace package body swms.pl_rf_sys06_case_removal as

 function VerifySOSBatch
 (
    i_rf_log_init_record            in swms.rf_log_init_record,
    i_batch_no			    in varchar2
 ) return swms.rf.STATUS
 IS
	rf_status                               swms.rf.STATUS := swms.rf.STATUS_NORMAL;
	l_count    number := 0;

  begin
	 -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
 	 rf_status := rf.Initialize(i_rf_log_init_record);
	 if rf_status = swms.rf.STATUS_NORMAL then
		-- Step 3: Main Business Logic
		select count(*)
		into l_count
		from mx_float_detail_cases
		where to_char(batch_no) = i_batch_no;

		if l_count = 0 then 
			rf_status := rf.STATUS_BATCH_NOT_FOUND;
		else
			select count(*)
			into l_count
			from mx_float_detail_cases
			where to_char(batch_no) = i_batch_no
				and   STATUS in ('DIV','NEW');

			if l_count = 0 then
				rf_status := rf.STATUS_LM_BATCH_NOT_READY;
			else
				rf_status := rf.STATUS_NORMAL;
			end if;
		end if;
	end if;
	
	-- Step 4:  Call rf.Complete() with final status
	rf.Complete(rf_status);
	return rf_status;

	exception
		when others then
			rf.LogException();	-- log it
			raise;				-- then throw up to next handler, if any
    end VerifySOSBatch;

 function RemoveCase
 (
    i_rf_log_init_record            in swms.rf_log_init_record,
    i_batch_no			    in varchar2,
    i_case_barcode                  in number
 ) return swms.rf.STATUS
  IS
       rf_status                               swms.rf.STATUS := swms.rf.STATUS_NORMAL;
       l_record_status                         matrix_out.record_status%TYPE;
       l_case_status                           mx_float_detail_cases.status%TYPE;
       l_spur_location                         mx_float_detail_cases.spur_location%TYPE;
       l_process_main_success                  BOOLEAN;
       l_prod_id                               pm.prod_id%type;
       l_hsShortInd				varchar2(1);
       l_order_seq				mx_float_detail_cases.order_seq%TYPE;
       l_float_detail_seq_no			mx_float_detail_cases.float_detail_seq_no%TYPE;
       l_iRc                                   number;
       l_send_sos_msg                          boolean := FALSE;



        cursor ck_sys06 is
	 select record_status
	  from matrix_out
	  where interface_ref_doc = 'SYS06'
	  and batch_id = to_char(i_batch_no)
	  and case_barcode = to_char(i_case_barcode);

        cursor ck_case_status is
	select status, spur_location,prod_id,substr(batch_no,1,1),order_seq,float_detail_seq_no
	from mx_float_detail_cases
	where to_char(batch_no) = i_batch_no
	and   case_id = i_case_barcode;
 
       l_selector    sos_batch.picked_by%TYPE;

       cursor get_selector is
       select replace(picked_by,'OPS$',null)
       from sos_batch
       where to_char(batch_no) = i_batch_no
       and   picked_by is not null
       and   status = 'A';

       BEGIN
	 -- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.
 	 rf_status := rf.Initialize(i_rf_log_init_record);
	 if rf_status = swms.rf.STATUS_NORMAL then
	 open ck_case_status;
		 fetch ck_case_status into l_case_status,l_spur_location,l_prod_id,l_hsShortInd,
					  l_order_seq,l_float_detail_seq_no;
		 if ck_case_status%NOTFOUND then
			rf_status := rf.STATUS_NOT_FOUND;
			 else
			if l_case_status in ('DIV','NEW') then  /* Valid barcode to continue for case diverted to spur */
								/* Virginia wanted NEW status as well for case going to jackpot lane */
				   l_iRc := pl_matrix_sys06.removing_case(i_batch_no,
												 i_case_barcode,
							 l_spur_location,
							 l_prod_id,
							 l_hsShortInd,
							 l_order_seq,
							 l_float_detail_seq_no,
							 l_case_status,
							 l_send_sos_msg);
			   if l_iRc = 0 then
			  open get_selector;
			  fetch get_selector into l_selector;
			  if get_selector%FOUND and l_send_sos_msg then
				 rf.SendUserMsg('Spur cases for batch ' || i_batch_no || ' have been removed from ' || l_spur_location,l_selector);
			  end if;
				  rf_status := rf.STATUS_NORMAL;
			   else
			  rf_status := rf.STATUS_SOS_E_SEND_BATCH;
			   end if;
			elsif l_case_status in ('PIK','STG') then
			   rf_status := rf.STATUS_TASK_ALREADY_PICKED; 
			else
			   rf_status := rf.STATUS_NOT_FOUND;    /* status is probably NEW */
			end if;
		 end if;
	end if;	/* rf.Initialize() returned NORMAL */
	
	rf.Complete(rf_status);
	return rf_status;
 
	exception
		when others then
			rf.LogException();	-- log it
			raise;				-- then throw up to next handler, if any
	END RemoveCase;
end pl_rf_sys06_case_removal;
/
show errors;
alter package swms.pl_rf_sys06_case_removal compile plsql_code_type = native;
grant execute on swms.pl_rf_sys06_case_removal to swms_user;
create or replace public synonym pl_rf_sys06_case_removal for swms.pl_rf_sys06_case_removal;


