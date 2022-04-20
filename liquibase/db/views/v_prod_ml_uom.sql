------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_prod_ml_uom.sql, swms, swms.9, 10.1.1 3/23/07 1.1
--
-- View:
--    v_prod_ml_uom
--
-- Description:
--    View of valid miniload uom's for an item.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/06 prpbcb   DN: 12214
--                      Ticket: 326211
--                      Project: 326211-Miniload Induction Qty Incorrect
--
--                      Created this view to use in form mm3sa.fmb for
--                      the LOV and validation of the uom when the user
--                      is creating a miniload message to send to the
--                      miniloader.  It is also used in package
--                      pl_miniload_processing to determine if an item is
--                      in the miniloader
--                        
--                      Note:  At this time the user can only create
--                             an expected receipt message.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_prod_ml_uom
AS
SELECT prod_id, cust_pref_vendor, 1 uom, 'Splits' uom_descrip
  FROM pm 
 WHERE pm.miniload_storage_ind  IN ('B', 'S')
   AND pm.split_trk = 'Y'
UNION
SELECT prod_id, cust_pref_vendor, 2 uom, 'Cases' uom_descrip
  FROM pm 
 WHERE pm.miniload_storage_ind = 'B';


