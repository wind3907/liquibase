set echo on
spool /tmp/swms/log/upd_pm_awm.lis
set timing on

BEGIN
 LOOP
    update swms.pm p
    set (wsh_begin_date,
      wsh_avg_invs,
      wsh_ship_movements,
      wsh_hits) = (select begin_date,avg_invs,ship_movements,hits 
		   from weekly_slot_hist w
		   where w.prod_id = p.prod_id
		   and   begin_date = (select max(begin_date) 
				       from weekly_slot_hist w2 
				       where w2.prod_id=w.prod_id)
	           and rownum=1)
     where wsh_begin_date is null
     and exists (select 1 
		 from weekly_slot_hist w2 
		 where w2.prod_id=p.prod_id
		 and   w2.begin_date is not null)
     and rownum < 1000;
     EXIT WHEN sql%notfound;
     COMMIT;
 END LOOP;

 LOOP
     update swms.pm p
        set expected_case_on_po = nvl((select sum(d.qty/p.spc)
                             from erm m,erd d
                             where m.erm_id=d.erm_id
                             and   m.status in ('NEW','SCH')
                             and   p.prod_id = d.prod_id
                             and   d.uom = 0),0)
       where expected_case_on_po is null
       and  rownum < 1000;
       EXIT WHEN SQL%NOTFOUND;
       COMMIT;
 END LOOP;
END;
/
spool off
