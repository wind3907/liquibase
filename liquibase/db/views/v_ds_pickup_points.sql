------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ds_pickup_points.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- View:
--    v_ds_pickup_points
--
-- Description:
--    This view is used for the LOV for field pickup_point in form ds1sd.fmb
--    which is for discrete selection.  The LOV for this field will display
--    the doors in the DOOR table and the locations in the LOC table.
--
--    The pickup point is a designated point where wood pallets, plastic
--    pallets, totes, etc are picked up by the selector before picking the
--    selection batch.  The point can be an existing door or slot or can be
--    a user defined point.  If it is a user defined point then within a 
--    dock distances need to be setup between each user defined point, from
--    each user defined point to each aisle and from each user defined point
--    to each door.
--
-- Used by:
--    Form ds1sd.fmb
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/15/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Created for discrete selection.
------------------------------------------------------------------------------

PROMPT Create view v_ds_pickup_points

CREATE OR REPLACE VIEW swms.v_ds_pickup_points
AS
SELECT 'DOOR'      point_descrip,
       pd.door_no  point
  FROM door pd
UNION
SELECT 'SLOT'      point_descrip,
       l.logi_loc  point
  FROM loc l
/

