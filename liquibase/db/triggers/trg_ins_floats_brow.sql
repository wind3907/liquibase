create or replace trigger swms.trg_ins_floats_brow
 BEFORE INSERT ON SWMS.FLOATS for each row
 when (new.pallet_pull = 'R')

 declare
   l_bck_dest_loc  loc.logi_loc%TYPE := 'NONE';
begin
   l_bck_dest_loc := pl_pflow.f_get_back_loc(:new.home_slot);
   if l_bck_dest_loc != 'NONE' then
      :new.home_slot := l_bck_dest_loc;
   end if;
   if (:new.float_seq = '0') then
      :new.float_seq := null;
   end if;
end;
/

