REM
REM File : daily_inv_hist_vw.sql
REM
REM sccs_id = %Z% %W% %G% %I% 
REM
REM MODIFICATION HISTORY
REM 05/07/10 prplhj   D#12581 Initial version. Just check the view to CMVC.
REM
CREATE OR REPLACE VIEW swms.daily_inv_hist_vw AS
  SELECT p.prod_id, p.cust_pref_vendor,
	 DECODE(TO_CHAR(d.gen_date, 'D'),
		1, d.gen_date,
		7, d.gen_date - 6,
		NEXT_DAY(d.gen_date, 'SUNDAY') - 7) begin_date,
         SUM(d.qoh / p.spc) / 7 avg_invs,
         0 ship_movements,
         0 hits
  FROM daily_inv_hist d, pm p
  WHERE d.prod_id = p.prod_id
  AND   d.cust_pref_vendor = p.cust_pref_vendor
  GROUP BY DECODE(TO_CHAR(d.gen_date, 'D'),
		  1, d.gen_date,
		  7, d.gen_date - 6,
		  NEXT_DAY(d.gen_date, 'SUNDAY') - 7),
           p.prod_id,
           p.cust_pref_vendor
/

COMMENT ON TABLE daily_inv_hist_vw IS 'VIEW sccs_id=%Z% %W% %G% %I%';

