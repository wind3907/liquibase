CREATE OR REPLACE VIEW swms.V_Missing_OP_Batches (
	route_batch_no,
	route_no,
	batch_no,
	pallet_pull,
	drop_qty,
	recreate)
AS
SELECT	DISTINCT r.route_Batch_no, r.route_no, f.batch_no,
	f.pallet_pull, f.drop_qty, r.sel_lock
  from route r, floats f, batch b
 where r.route_no = f.route_no
   and r.status in ('SHT', 'OPN')
   AND b.batch_NO (+) = DECODE (f.pallet_pull, 'R', 'FR' || FLOAT_NO,
					'Y', 'FB' || FLOAT_NO,
					'N', 'S' || f.batch_no, '-')
   AND b.batch_no IS NULL
   AND f.pallet_pull != 'B'
   AND f.batch_no != 0
UNION
SELECT	DISTINCT r.route_Batch_no, r.route_no, f.batch_no,
	f.pallet_pull, f.drop_qty, r.sel_lock
  FROM route r, floats f
 WHERE r.route_no = f.route_no
   AND r.status in ('SHT', 'OPN')
   AND pallet_pull = 'B'
   AND ((f.drop_qty > 0 AND NOT EXISTS (SELECT 0 FROM batch b1 WHERE b1.batch_no = 'FD' || f.float_no))
	OR (NOT EXISTS (SELECT 0 FROM batch b1 WHERE b1.batch_no = 'FU' || f.float_no)))
   AND f.batch_no != 0
/

