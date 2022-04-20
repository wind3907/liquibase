REM
REM File : v_las_pallet.sql
REM
REM sccs_id = @(#) src/schema/views/v_las_pallet.sql, swms, swms.9, 10.1.1 1/2/09 1.2 
REM
REM MODIFICATION HISTORY
REM 07/31/08 prplhj D#12402 Initial version. It's created to allow the 
REM                 combinations of LAS_PALLET, BATCH, and LAS_PALLET_SORT
REM                 tables.
REM 12/09/08 prplhj D#12446 Use outer-join from batch for missing batches.
REM
CREATE OR REPLACE VIEW swms.v_las_pallet AS
  SELECT p.truck truck,
         p.palletno palletno,
         p.truck_zone truck_zone,
         p.loader_status loader_status,
         p.selection_status selection_status,
         NVL(p.batch, b.batch_no) batch,
         p.map_zone map_zone,
         p.max_stop max_stop,
         p.min_stop min_stop,
         p.add_user add_user,
         p.add_date add_date,
         p.upd_user upd_user,
         p.upd_date upd_date,
         TO_NUMBER(s.sort_seq) sort_seq,
         b.status,
         b.user_id selector_id
  FROM las_pallet p, las_pallet_sort s, batch b
  WHERE RTRIM(SUBSTR(p.palletno, 1, 1)) = s.pallettype
  AND   'S' || p.batch = b.batch_no (+)
/

COMMENT ON TABLE v_las_pallet IS 'VIEW sccs_id=@(#) src/schema/views/v_las_pallet.sql, swms, swms.9, 10.1.1 1/2/09 1.2';

