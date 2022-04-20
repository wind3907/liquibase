rem   Trigger Name   : trg_ins_loc_reference_arow 
rem   Created By     : acpakp 
rem   Table Used     : LOC,LOC_REFERENCE,LZONE 
rem   Comments       : 
rem   This trigger will fire on insert on LOC_REFERENCE TABLE.
rem   On insert this will update the LOC Table. The Front Location
rem   will be updated with the value of put_aisle,put_slot,put_level,
rem   put_path of back location. Back Location will be updated with the
rem   perm,slot_type,pallet_type,cube,uom of front location. Also the back
rem   location is updated with status as BCK and description as BACK LOCATION.
rem   PUT Zone_id of LZONE table for the back location is updated with the 
rem   Zone_id of Pick location.

create or replace trigger swms.trg_ins_loc_reference_arow 
       after insert on swms.loc_reference
       for each row 
declare
l_loc loc%ROWTYPE;
b_loc loc%ROWTYPE;
begin  
  select put_aisle,put_slot,put_level,put_path
  into l_loc.put_aisle,l_loc.put_slot,l_loc.put_level,l_loc.put_path
  from loc
  where logi_loc = :new.bck_logi_loc;
  update loc
  set put_aisle = l_loc.put_aisle,
      put_slot = l_loc.put_slot,
      put_level = l_loc.put_level,
      put_path = l_loc.put_path
  where logi_loc = :new.plogi_loc;
  select perm,slot_type,pallet_type,cube,uom
  into b_loc.perm,b_loc.slot_type,b_loc.pallet_type,b_loc.cube,b_loc.uom
  from loc
  where logi_loc = :new.plogi_loc;

  update loc
  set perm      = b_loc.perm,
      slot_type = b_loc.slot_type,
      pallet_type= b_loc.pallet_type,
      status  = 'BCK',
      descrip = 'BACK LOCATION',
      cube = 1
  where logi_loc = :new.bck_logi_loc;
  --
  update lzone 
    set zone_id = (select z2.zone_id
		   from zone z2,lzone lz2
		   where z2.zone_id = lz2.zone_id
		   and   z2.zone_type = 'PUT'
		   and   lz2.logi_loc = :new.plogi_loc)
  where logi_loc = :new.bck_logi_loc
  and   exists (select 'x'
		from zone z1
		where z1.zone_id = lzone.zone_id
		and   z1.zone_type = 'PUT');
end;
/

