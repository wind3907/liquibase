-- 7/9/21 mcha1213 add :new.task_id
create or replace TRIGGER swms.trg_ins_putawaylst_status
BEFORE INSERT
ON swms.putawaylst
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
DECLARE
   l_object_name  VARCHAR2(30) := 'trg_ins_putawaylst_status';
Begin
    -- if status = 'DMG'
    -- set value for print_status as 'N'
    -- otherwise set it to 'Y'

    if (:new.status = 'DMG')
    then
        :new.print_status := 'N';
    else
        :new.print_status := 'Y' ;
    end if;

    -- if tti_trk is 'NULL'
    -- set tti_trk to 'Y' if it is tti_tracked_item
    -- otherwise set it to 'N'
    if (:new.tti_trk is NULL)
    then
        if (swms.pl_putaway_utilities.f_is_tti_tracked_item(:new.prod_id, :new.cust_pref_vendor)) then
            :new.tti_trk := 'Y';
        else
            :new.tti_trk := 'N';
        end if;
    end if;

    if (:new.catch_wt is NULL) then
        :new.catch_wt := 'N';
    end if;

    if (:new.clam_bed_trk is NULL) then
        :new.clam_bed_trk := 'N';
    end if;

    if (:new.task_id is NULL) then    
		:new.task_id := repl_id_seq.nextval;
    end if;		

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

End;
/