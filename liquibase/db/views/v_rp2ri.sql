---------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_rp2ri.sql, swms, swms.9, 10.1.1 9/7/06 1.4
--
-- View:
--    v_rp2ri
--
-- Description:
--    This view is used in the return receiving report.
--
-- Used by:
--    Report rp2rioracle.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/10/04 prppxx   Add erm_line_id in the view for printing single
--					    return receiving label.
--    08/03/05 prphqb   Add obligation_no to print by invoice number   
---------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_rp2ri AS
SELECT e.erm_id           erm_id, 
       e.erm_type         erm_type,                     
       p.erm_line_id      erm_line_id,
       e.source_id        source_id, 
       e.status           status,   
       e.exp_arriv_date   exp_arriv_date,
       e.cmt              cmt,
       e.rec_date         rec_date,
       e.carr_id          carr_id, 
       p.pallet_batch_no  batch_no,
       p.lot_id           obligation_no
FROM putawaylst p, erm e
WHERE p.rec_id = e.erm_id
/

