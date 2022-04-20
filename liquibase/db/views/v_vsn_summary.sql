------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_vsn_summary.sql, swms, swms.9, 11.2 4/8/10 1.2
--
-- View:
--    v_vsn_summary
--
-- Description:
--    vsn pallet summary.
--
-- Modification History:
--	Date		Designer	Comments
--	-----------	--------	--------------------------------------
--	23-MAR-2010	CTVGG000	Created view v_vsn_summary for
--					vsn exception report.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SWMS.V_VSN_SUMMARY
AS 
-- select all pallet id's from put transaction records for a VN from TRANS and
-- matching pallets id's from erd_lpn and select null record from erd_lpn for
-- unmatching rows. i.e. select all pallets id that have been putaway.
(
SELECT 
'VSN'			po_type,
t.rec_id		po_no,
t.close_date		close_date,
e.pallet_id		vendor_pallet_id,
t.pallet_id		scanned_pallet_id,
t.source_id		supplier_suvc,
DECODE(e.pallet_id, NULL, 'S', 'V') pallet_created_by
FROM
(SELECT t.pallet_id,SUBSTR(t.rec_id,1,8) rec_id,m.close_date,m.source_id
FROM TRANS t, ERM m
WHERE t.rec_id = m.erm_id AND m.erm_type = 'VN' AND m.status IN ('CLO','VCH')
AND m.close_date > (sysdate - 7) AND t.TRANS_TYPE = 'PUT') t,
(SELECT l.pallet_id, SUBSTR(m.erm_id,1,8) erm_id, m.source_id
FROM ERD_LPN l, ERM m
WHERE  m.erm_id = l.sn_no AND m.erm_type = 'VN' AND m.status IN ('CLO','VCH')
AND m.close_date > (sysdate - 7)) e
WHERE
e.pallet_id(+) = t.pallet_id
AND e.erm_id(+) = t.rec_id
UNION
-- select all vendor pallet ids from erd_lpn for VN and matching pallets ids 
-- from trans and select null record from trans for unmatching rows.
-- i.e. select all Vendor pallets id's that have been putaway.
SELECT
'VSN' po_type,
e.erm_id	po_no,
e.close_date	close_date,
e.pallet_id	vendor_pallet_id,
t.pallet_id	scanned_pallet_id,
e.source_id	supplier_suvc,
DECODE(e.pallet_id, NULL, 'S', 'V') pallet_created_by
FROM
(SELECT t.pallet_id, SUBSTR(t.rec_id, 1,8) rec_id FROM TRANS t, ERM m
WHERE t.rec_id = m.erm_id AND m.erm_type = 'VN' AND m.status IN ('CLO','VCH')
AND m.close_date > (sysdate - 7) AND t.TRANS_TYPE = 'PUT') t,
(SELECT l.pallet_id, SUBSTR(m.erm_id,1,8) erm_id, m.close_date, m.source_id
FROM ERD_LPN l, ERM m
WHERE  m.erm_id = l.sn_no AND m.erm_type = 'VN' AND m.status IN ('CLO','VCH')
AND m.close_date > (sysdate - 7)) e
WHERE
e.pallet_id = t.pallet_id(+)
AND e.erm_id = t.rec_id(+))
order by close_date
/
