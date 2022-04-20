------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_dock.sql, swms, swms.9, 10.1.1 4/22/08 1.1
--
-- View:
--    v_dock
--
-- Description:
--     View of the DOCK table which includes the dock location description.
--
--     The main reason to create this view is for the dock location
--     description.  The DOCK table has a column called LOCATION, VARCHAR(1),
--     which designates if the dock is a front dock, back dock or side dock.
--     The valid values are:
--        F    For front dock
--        B    For back dock
--        S    For side dock
--     Currently there is not a code table for the dock location.  The DOCK
--     table has a check constraint checking that the value is F, B or S.
--     This view will set the dock location description as follows:
--       LOCATION         LOCATION_DESCRIP
--       -------------    ----------------
--          F             FRONT DOCK
--          B             BACK DOCK
--          S             SIDE DOCK
--       anything else    UNKNOWN
--     
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/17/08 prpbcb   DN 12363
--                      Project: 587073-Forklift Labor Distance Fix
--                      Created.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_dock
AS
SELECT d.dock_no    dock_no,
       d.descrip    descrip,
       d.location   location,
       DECODE(d.location, 'F', 'FRONT DOCK',
                          'B', 'BACK DOCK',
                          'S', 'SIDE DOCK',
                          'UNKNOWN') location_descrip
  FROM dock d
/



--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM v_dock FOR swms.v_dock;


