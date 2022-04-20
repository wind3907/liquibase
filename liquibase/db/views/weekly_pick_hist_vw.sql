REM
REM File : weekly_pick_hist_vw.sql
REM
REM sccs_id = %Z% %W% %G% %I% 
REM
REM MODIFICATION HISTORY
REM 05/07/10 prplhj   D#12581 Initial version. Just put it into CMVC and also
REM		      change the TRANS table to V_TRANS view.
REM
CREATE OR REPLACE VIEW swms.weekly_pick_hist_vw AS
  SELECT DECODE(MOD(t.qty, p.spc), 0, 2, 1) ship_uom,
         p.prod_id, p.cust_pref_vendor,
         TRUNC(DECODE(TO_CHAR(t.trans_date, 'D'),
                        1, t.trans_date,
                        7, t.trans_date - 6,
                        NEXT_DAY(t.trans_date, 'SUNDAY') - 7)) begin_date,
         0 avg_invs,
         SUM(DECODE(MOD(t.qty, p.spc), 0, t.qty / p.spc, t.qty)) ship_movements,
         COUNT(1) hits
  FROM v_trans t, pm p
  WHERE t.trans_type = 'PIK'
  AND   t.qty > 0
  AND   t.prod_id = p.prod_id
  AND   t.cust_pref_vendor = p.cust_pref_vendor
  GROUP BY p.prod_id,
           p.cust_pref_vendor,
           TRUNC(DECODE(TO_CHAR(t.trans_date, 'D'),
                        1, t.trans_date,
                        7, t.trans_date - 6,
                        NEXT_DAY(t.trans_date, 'SUNDAY') - 7)),
           DECODE(MOD(t.qty, p.spc), 0, 2, 1)
  UNION ALL
  -- This sums up each week's average inventory history which has inventory
  -- history but no picks and the item is not splitable
  SELECT 2 ship_uom,
         p.prod_id, p.cust_pref_vendor,
         TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)) begin_date,
         SUM(d.qoh / p.spc) / 7 avg_invs,
         0 ship_movements,
         0 hits
  FROM daily_inv_hist d, pm p
  WHERE d.prod_id = p.prod_id
  AND   d.cust_pref_vendor = p.cust_pref_vendor
  AND   p.split_trk = 'N'
  AND   NOT EXISTS (SELECT NULL
                    FROM v_trans t
                    WHERE trans_type = 'PIK'
                    AND   qty > 0
                    AND   prod_id = d.prod_id
                    AND   cust_pref_vendor = d.cust_pref_vendor
                    AND   TRUNC(DECODE(TO_CHAR(t.trans_date, 'D'),
                                        1, t.trans_date,
                                        7, t.trans_date - 6,
                                        NEXT_DAY(t.trans_date, 'SUNDAY') - 7)) =
                          TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                                        1, d.gen_date,
                                        7, d.gen_date - 6,
                                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)))
  GROUP BY p.prod_id,
           p.cust_pref_vendor,
           TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7))
  UNION ALL
  -- This sums up each week's average inventory history which has inventory
  -- history but no picks and the item is splitable and create a record for
  -- split uom
  SELECT 1 ship_uom,
         p.prod_id, p.cust_pref_vendor,
         TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)) begin_date,
         SUM(d.qoh / p.spc) / 7 avg_invs,
         0 ship_movements,
         0 hits
  FROM daily_inv_hist d, pm p
  WHERE d.prod_id = p.prod_id
  AND   d.cust_pref_vendor = p.cust_pref_vendor
  AND   p.split_trk = 'Y'
  AND   NOT EXISTS (SELECT NULL
                    FROM v_trans t
                    WHERE trans_type = 'PIK'
                    AND   qty > 0
                    AND   prod_id = d.prod_id
                    AND   cust_pref_vendor = d.cust_pref_vendor
                    AND   TRUNC(DECODE(TO_CHAR(t.trans_date, 'D'),
                                        1, t.trans_date,
                                        7, t.trans_date - 6,
                                        NEXT_DAY(t.trans_date, 'SUNDAY') - 7)) =
                          TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                                        1, d.gen_date,
                                        7, d.gen_date - 6,
                                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)))
  GROUP BY p.prod_id,
           p.cust_pref_vendor,
           TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7))
  UNION ALL
  -- This sums up each week's average inventory history which has inventory
  -- history but no picks and the item is splitable and create a record for
  -- case uom
  SELECT 2 ship_uom,
         p.prod_id, p.cust_pref_vendor,
         TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)) begin_date,
         SUM(d.qoh / p.spc) / 7 avg_invs,
         0 ship_movements,
         0 hits
  FROM daily_inv_hist d, pm p
  WHERE d.prod_id = p.prod_id
  AND   d.cust_pref_vendor = p.cust_pref_vendor
  AND   p.split_trk = 'Y'
  AND   NOT EXISTS (SELECT NULL
                    FROM v_trans t
                    WHERE trans_type = 'PIK'
                    AND   qty > 0
                    AND   prod_id = d.prod_id
                    AND   cust_pref_vendor = d.cust_pref_vendor
                    AND   TRUNC(DECODE(TO_CHAR(t.trans_date, 'D'),
                                        1, t.trans_date,
                                        7, t.trans_date - 6,
                                        NEXT_DAY(t.trans_date, 'SUNDAY') - 7)) =
                          TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                                        1, d.gen_date,
                                        7, d.gen_date - 6,
                                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7)))
  GROUP BY p.prod_id,
           p.cust_pref_vendor,
           TRUNC(DECODE(TO_CHAR(d.gen_date, 'D'),
                        1, d.gen_date,
                        7, d.gen_date - 6,
                        NEXT_DAY(d.gen_date, 'SUNDAY') - 7))
/

COMMENT ON TABLE weekly_pick_hist_vw IS 'VIEW sccs_id=%Z% %W% %G% %I%';

