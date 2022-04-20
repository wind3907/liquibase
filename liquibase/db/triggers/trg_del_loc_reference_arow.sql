rem   Trigger Name   : trg_del_loc_reference_arow 
rem   Created By     : acpakp 
rem   Table Used     : LOC,LOC_REFERENCE 
rem   Comments       : 
rem   This trigger will fire on delete on LOC_REFERENCE TABLE.
rem   On delete this will update the LOC Table. The Front Location
rem   put_aisle,put_slot,put_level and put_path  will be updated with the
rem   pik_aisle,pik_slot,pik_level and pik_path.

create or replace trigger swms.trg_del_loc_reference_arow 
       after delete on swms.loc_reference
       for each row 
begin  
  update loc
  set put_aisle = pik_aisle,
      put_slot = pik_slot,
      put_level = pik_level,
      put_path = pik_path
  where logi_loc = :old.plogi_loc;
end;
/

