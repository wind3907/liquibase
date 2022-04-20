
rem   Trigger Name   : trg_insupd_arch_batch_arow 
rem   Created By     : acpakp 
rem   Table Used     : ARCH_BATCH 
rem   Comments       : 
rem   This trigger will fire on insert/update on ARCH_BATCH TABLE.
rem   This trigger will truncate the time from batch date after 
rem  insert or update of batch_date  

create or replace trigger swms.trg_insupd_arch_batch_brow
       before insert or update of batch_date on swms.arch_batch 
       for each row 
begin
  :new.batch_date := trunc(:new.batch_date);
end;
/

