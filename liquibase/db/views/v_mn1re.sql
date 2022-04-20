REM @(#) src/schema/views/v_mn1re.sql, swms, swms.9, 10.1.1 9/7/06 1.2
REM File : @(#) src/schema/views/v_mn1re.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_mn1re.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM 01/17/06 prppxx D#12033 Added the INV|UOM for WAI change.
REM

CREATE OR REPLACE VIEW swms.v_mn1re AS
SELECT DISTINCT i.logi_loc logi_loc,
              p.buyer buyer,
              i.prod_id prod_id,
              i.cust_pref_vendor cust_pref_vendor,
              i.plogi_loc plogi_loc,
              i.qoh qoh,
              i.inv_date inv_date,
              p.spc spc,
              p.descrip descrip,
              l.aisle_side aisle_side,
              i.status status,
	      i.inv_uom inv_uom
       FROM loc l, pm p, inv i
       WHERE ( (sysdate - i.inv_date) > 90)
       AND   i.plogi_loc != i.logi_loc
       AND   i.plogi_loc = l.logi_loc
       AND   i.prod_id = p.prod_id
       AND   i.cust_pref_vendor = p.cust_pref_vendor
       AND   l.perm = 'N'
       AND   EXISTS (SELECT 'x' FROM zone, lzone
                     WHERE zone.rule_id != 1
                     AND   lzone.zone_id = zone.zone_id
                     AND   lzone.logi_loc = l.logi_loc
                    );

