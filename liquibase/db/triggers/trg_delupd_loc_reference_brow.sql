create or replace trigger swms.trg_delupd_loc_reference_brow
 BEFORE DELETE OR UPDATE ON SWMS.LOC_REFERENCE for each row

declare
  l_status  varchar2(3);
  cursor ck_put (c_dest_loc varchar2) is
  select 'x'
  from putawaylst
  where dest_loc = c_dest_loc;

  cursor ck_replen (c_dest_loc varchar2) is
  select 'x'
  from replenlst
  where dest_loc = c_dest_loc;

  cursor ck_floats (c_home_slot varchar2) is
  select status
  from floats
  where home_slot = c_home_slot;

begin
  open ck_put (:old.bck_logi_loc); 
  fetch ck_put into l_status;
  if ck_put%FOUND then
     raise_application_error(-20201,'Put pending record still exists for 
			  location: ' || :old.bck_logi_loc);
  end if;
  close ck_put;
  open ck_replen (:old.bck_logi_loc);
  fetch ck_replen into l_status;
  if ck_replen%FOUND then
     raise_application_error(-20202,'Replenishment list pending 
	  record still exists for location: ' || :old.bck_logi_loc);
  end if;
  close ck_replen;
  open ck_floats (:old.bck_logi_loc);
  fetch ck_floats into l_status;
  if ck_floats%FOUND and l_status != 'DRP' then
     raise_application_error(-20202,'Floating 
	  record still exists for location: ' || :old.bck_logi_loc);
  end if;
  close ck_floats;
end;
/

