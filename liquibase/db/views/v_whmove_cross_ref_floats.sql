CREATE OR REPLACE VIEW swms.v_whmv_cross_ref_floats AS     
 SELECT wh.prod_id,
	w.oldzone,
        w.newzone,
        wh.newloc minloc,
        wh.newloc maxloc
 FROM whmv_cross_ref_floats w,             
      whmove.zone z,                              
      whmove.lzone lz,
      whmveloc_floats wh,
      swms.pm p
 WHERE z.zone_id =lz.zone_id              
 AND   lz.logi_loc = wh.newloc
 AND   z.zone_id = w.newzone               
 AND   w.oldzone = p.zone_id
 AND   p.prod_id = wh.prod_id
 AND   z.zone_type = 'PUT' 
 AND   z.rule_id = 1;

