create or replace trigger swms.trg_swms_upd_whmveloc_hist
 AFTER UPDATE OF MOV_STATUS ON WHMVELOC_HIST
 FOR EACH ROW
 when (new.mov_status = 'Y')

declare
  l_zone_id   zone.zone_id%type;
  l_qoh       inv.qoh%type;
  l_qty_planned  inv.qty_planned%type;
  l_qty_alloc    inv.qty_alloc%type;
  l_temp_area    varchar2(1);
  l_cpv          loc.cust_pref_vendor%type;
  l_rank         loc.rank%type;
  l_uom		 loc.uom%type;
  l_wh_type      varchar2(1);
  --
  cursor get_zone(c_newloc varchar2) is
  select z.zone_id
  from swms.lzone lz,swms.zone z
  where lz.zone_id = z.zone_id
  and   z.zone_type = 'PUT'
  and   lz.logi_loc = c_newloc;
  --
  cursor get_qty is
  select qoh,qty_planned,qty_alloc,l.cust_pref_vendor,l.rank,l.uom
  from swms.inv i,swms.loc l
  where i.prod_id = :new.prod_id
  and   i.prod_id = l.prod_id
  and   i.plogi_loc = l.logi_loc
  and   l.perm='Y'
  and   i.plogi_loc = :new.oldloc
  and   i.plogi_loc = i.logi_loc;
  --
  cursor cross_ref is
  select tmp_new_wh_area
  from whmveloc_area_xref
  where putback_wh_area = substr(:new.newloc,1,1);

begin 
   open cross_ref;
   fetch cross_ref into l_temp_area;
   if cross_ref%notfound then
      raise_application_error(-20010,'trg_swms_upd_whmveloc_hist cross ref not found.');
   end if;
   open get_qty;
   fetch get_qty into l_qoh,l_qty_planned,l_qty_alloc,l_cpv,l_rank,l_uom;
   if get_qty%NOTFOUND then
      raise_application_error(-20009,'trg_swms_upd_whmveloc_hist failed '||
       'GET_QTY CURSOR NOT FOUND');
   end if;
   close get_qty;
  
   begin
    select config_flag_val
    into l_wh_type
    from swms.sys_config
    where config_flag_name ='WAREHOUSE_MOVE_TYPE';
    exception
      when others then
        l_wh_type := 'N';
   end;
   if l_wh_type <> 'P' then
      update whmove.inv
        set qoh = l_qoh,
     	    qty_planned = l_qty_planned,
	    qty_alloc = l_qty_alloc
      where plogi_loc = :new.newloc
      and   prod_id = :new.prod_id
      and   plogi_loc = logi_loc;
   end if;
   update swms.inv
     set logi_loc = l_temp_area || substr(:new.newloc,2),
	 plogi_loc = l_temp_area || substr(:new.newloc,2)
   where prod_id = :new.prod_id
   and   plogi_loc = :new.oldloc
   and   logi_loc = :new.oldloc;

   update swms.loc
     set prod_id = null,
	 cust_pref_vendor = null,
	 uom = null, rank = null
   where logi_loc = :new.oldloc;

   update swms.loc
     set prod_id = :new.prod_id,
	 cust_pref_vendor = l_cpv,
	 uom = l_uom, rank = l_rank, perm = 'Y'
   where logi_loc = l_temp_area || substr(:new.newloc,2);

   open get_zone(l_temp_area || substr(:new.newloc,2));
   fetch get_zone into l_zone_id;
   if get_zone%NOTFOUND then
      l_zone_id := 'FRSPL';
   end if;
   close get_zone;
   --
   update swms.pm
    set ti = :new.ti,
	hi = :new.hi,
	zone_id = l_zone_id,
	pallet_type = :new.pallet,
	g_weight = :new.g_weight
   where prod_id = :new.prod_id
   and   l_uom in (0,2);
   --
   update swms.putawaylst
     set dest_loc = l_temp_area || substr(:new.newloc,2)
     where dest_loc = :new.oldloc;
   update replenlst
     set src_loc = l_temp_area || substr(:new.newloc,2)
     where src_loc = :new.oldloc;
   update replenlst
     set dest_loc = l_temp_area || substr(:new.newloc,2)
     where dest_loc = :new.oldloc;
   update cc
     set phys_loc = l_temp_area || substr(:new.newloc,2),
         logi_loc = l_temp_area || substr(:new.newloc,2)
     where phys_loc = :new.oldloc
     and   phys_loc = logi_loc;
   update cc_exception_list
     set phys_loc = l_temp_area || substr(:new.newloc,2),
         logi_loc = l_temp_area || substr(:new.newloc,2)
     where phys_loc = :new.oldloc
     and   logi_loc = phys_loc;
end;
/
