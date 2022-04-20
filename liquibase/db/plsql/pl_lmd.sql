

PROMPT Create package specification: pl_lmd

/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lmd
IS

   -- sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmd
   --
   -- Description:
   --    Labor management distance calculations.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/15/05 prpbcb   Oracle 9 rs239b swms8 DN 11490
   --                      Created.
   --                      PL/SQL package version of PRO*C program
   --                      lm_distance.pc.  Initially created to use
   --                      for discrete selection.
   --
   --                      The equipment accelerate distance and decelerate
   --                      distance were added to the distance record if in
   --                      the future these distances are defined at the
   --                      equipment level.  At this time for discrete
   --                      selection these distances are syspars.
   --
   --    03/28/08  prpbcb    DN 12363
   --                        Project: 587073-Forklift Labor Distance Fix
   --                        Added procedure set_travel_docks() that will set
   --                        what dock the forklift operator is leaving from
   --                        and what dock the forklift operator will arrive at
   --                        when traveling from one forklift labor mgmt
   --                        section to another.  A forklift labor mgmt section
   --                        is how the warehouse is split up when defining
   --                        the forklift distances.  By default the distance
   --                        calculation is expecting the travel between two
   --                        sections will be from front dock to front dock
   --                        but this is not necessarily the case (ie OpCo 96
   --                        Abbott).
   --
   --                        Example:
   --
   -- Abbott, OpCo 96, has the cooler broken into two sections which we will
   -- call Cooler 1 and Cooler 2.  Cooler 1 has the C1 dock.  Cooler 2 has the
   -- E1 and E2 docks.
   -- 
   -- C1 is a front dock.
   -- E1 is a front dock.
   -- E2 is a back dock.
   -- P1 is a front dock.
   -- F1 is a front dock.
   --
   -- The E2 dock is setup with a dummy door number called E299 because every
   -- dock needs at least one door.
   -- 
   -- When traveling from Cooler 1 to Cooler 2 you enter at the
   -- E2 back dock.  The change made is to be able to specify what dock you are
   -- leaving fron and entering when traveling from one section to another.
   -- Before SWMS would assume you would always leave the front dock and
   -- enter at the front dock when traveling between sections.
-- 
--                                                                     Freezer 
--                                                                     Section
--                                                                          |
--                                                                          |
--                                                                          V
--                                        +-----------------------------+ +----
--                                        |                             | |
--                                        |                             | |
--                                        |       Cooler 1 Section      | |
--                                        |                             | |
--                                        |                             | |
--                                        |                             | |
--                                        |                             | |
--                                        |                             +-+  
--                                        |                                
--                                        +   +-------------------------+-+----
--                                        |   |      C1 Dock                F1
--                                        |   |                             Dock
--      +-------------------------------+ |   |
--      |                               | | R |
--      |                               | | A |
--      |       Cooler 2 Section        | | M |
-- E1   |                          E2   | | P |
-- Dock |                          Dock | |   |
--      |                               | |   |
--      |                               | |   | 
--      |                               +-+   |
--      |                                     |
--      |                               +-----+
--      +  +----------------------------+
--      |  |
--      +  +----------------------------+
--      |                               |
--      |        Produce Section        |
-- P1   |                               |
-- Dock |                               |
--      |                               |
--      |                               |
--      |                               |
--      +-------------------------------+
   --
   --
   --
   --
   --
   --    05/27/10  prpbcb  DN 12580
   --                      Project:
   --                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
   --
   --                      Added procedure get_next_point().
   --
   --    06/16/10  prpbcb  DN 12580
   --                      Project:
   --                          CRQ16476-Complete Not Suspend Labor Mgmt Batch
   --
   --                      Bug fixes found in beta phase.
   --                      Change audit message.   
   --
   --    07/19/10  prpbcb  Activity: SWMS12.0.0_0000_QC11345
   --                      Project:  QC11345
   --                      Copy from rs239b.
   --   
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   -- Point information.
   TYPE t_point_info_rec IS RECORD
        (pt_type     point_distance.point_type%TYPE,  -- Point type
         area        swms_areas.area_code%TYPE,       -- Area
         dock_num    point_distance.point_dock%TYPE,  -- Dock number
         point       VARCHAR2(10));                   -- Point
   -- A note about the area.  The area for the point is the first character
   -- in the dock_num.  For an aisle or bay the area is not necessarily the
   -- same as the swms area.
   -- Example: There is no freezer dock.  Freezer items are received and
   --          loaded at the cooler dock.   The defined docks are D1 and C1.
   --          The doors are all D1 and C1 doors.
   --          The door to aisle distances for the freezer aisles are setup
   --          under dock C1 and the door is a cooler door (C1..)
   --          There warehouse freezer aisle to aisle distances and bay
   --          distances are setup under the C1 dock.
   --
   --          For location FB08A1 the point info rec will have 'C' as the
   --          area and 'C1' as the dock.
   --
   --          For aisle FB the point info rec will have 'C' as the
   --          area and 'C1' as the dock.
      

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ----------------------------------------------------
   -- Designators for the front, back and side dock.
   -- These are the values in column "location" in the
   -- DOCK table.
   ----------------------------------------------------
   ct_front_dock  CONSTANT VARCHAR2(1) := 'F';       -- Front dock
   ct_back_dock   CONSTANT VARCHAR2(1) := 'B';       -- Back dock
   ct_side_dock   CONSTANT VARCHAR2(1) := 'S';       -- Side dock

   ----------------------------------------------------
   -- Aisle directions.  The direction designates how
   -- the locations are assigned.  0 designates the
   -- locations are ascending order starting at the
   -- front of the warehouse.  1 designates the
   -- locations are descending order starting at the
   -- front of the warehouse.
   ----------------------------------------------------
   ct_aisle_direction_down   BINARY_INTEGER  := 0;
   ct_aisle_direction_up     BINARY_INTEGER  := 1;

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_ds_get_bay_to_bay_dist
   --
   -- Description:
   --    This function gets distance from a bay to a bay taking into account
   --    the aisle direction when the bays are on different aisles.  Used when
   --    the bays are on different aisles.
   --
   --    Note: The bays have to be in the same area.
   --
   --    The bay to bay distance is broken up into three distances:
   --       - bay to aisle end distance
   --       - aisle to aisle distance
   --       - beginning of aisle to the bay
   --
   --    Note: Function f_get_bay_to_bay_dist function is used for forklift
   --          labor manamgent.  The aisle direction does not matter for
   --          forklift labor management but it does for selection.
   ---------------------------------------------------------------------------
   FUNCTION f_ds_get_bay_to_bay_dist
                    (i_dock_num             IN point_distance.point_dock%TYPE,
                     i_from_aisle           IN bay_distance.aisle%TYPE,
                     i_from_bay             IN bay_distance.bay%TYPE,
                     i_from_aisle_direction IN aisle_info.direction%TYPE,
                     i_to_aisle             IN bay_distance.aisle%TYPE,
                     i_to_bay               IN bay_distance.bay%TYPE,
                     i_to_aisle_direction   IN aisle_info.direction%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_direction
   --
   -- Description:
   --    This function finds the direction of an aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_direction(i_aisle  IN aisle_info.name%TYPE)
   RETURN aisle_info.direction%TYPE;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_length
   --
   -- Description:
   --    This function finds the length of an aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_length(i_aisle  IN bay_distance.aisle%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_first_bay
   --
   -- Description:
   --    This function finds the first bay on an aisle closest to the front
   --    of the warehouse.  The aisle direction is used to determine what bay
   --    is closest.  The bay is taken from the bay distance setup.
   --
   --    If the aisle does not have a direction defined in the aisle info
   --    then 0 is used as the direction.
   ---------------------------------------------------------------------------
   FUNCTION f_get_first_bay(i_aisle  IN bay_distance.aisle%TYPE)
   RETURN VARCHAR2;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between two aisles on the
   --    specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_to_aisle_dist
                        (i_dock_num     IN point_distance.point_dock%TYPE,
                         i_from_aisle   IN point_distance.point_a%TYPE,
                         i_to_aisle     IN point_distance.point_a%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the specified aisle and bay
   --    on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_aisle                 IN point_distance.point_a%TYPE,
                 i_to_bay                     IN loc.logi_loc%TYPE,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_cross_aisle_dist
   --
   --  Description:
   --    This function calculates the minimum cross aisle path from specified
   --    starting and ending bays on the specified dock.
   --
   --  Parameters:
   --    i_dock_num   - Dock number.
   --    i_from_aisle - Starting aisle (aisle only).  Example: DA
   --    i_from_bay   - Starting bay (bay only).  Example: 23
   --    i_to_aisle   - Ending aisle (aisle only).  Example: DE
   --    i_to_bay     - Ending bay (bay only).  Example: 48
   ---------------------------------------------------------------------------
   FUNCTION f_get_cross_aisle_dist
                            (i_dock_num IN  point_distance.point_dock%TYPE,
                             i_from_aisle   IN bay_distance.aisle%TYPE,
                             i_from_bay     IN bay_distance.bay%TYPE,
                             i_to_aisle     IN bay_distance.aisle%TYPE,
                             i_to_bay       IN bay_distance.bay%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between two bays on the specified
   --    dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_bay                   IN VARCHAR2,
                 i_to_bay                     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_bay_on_aisle_dist
   --
   -- Description:
   --    This function finds the distance between two bays on the same aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_bay_on_aisle_dist
                        (i_aisle    IN bay_distance.aisle%TYPE,
                         i_from_bay IN bay_distance.bay%TYPE,
                         i_to_bay   IN bay_distance.bay%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_end_dist
   --
   -- Description:
   --    This function finds the distance between the specified bay and the
   --    end cap of the specified aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_end_dist(i_aisle  IN bay_distance.aisle%TYPE,
                                  i_bay    IN bay_distance.bay%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and aisle
   --    on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_aisle_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_aisle   IN point_distance.point_b%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_pup_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and
   --    pickup point on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_pup_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_pup     IN point_distance.point_b%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_bay_direct_dist
   --
   -- Description:
   --    This subroutine finds the straight line distance between the specified
   --    door and bay.
   --
   --    By knowing the following we can calculate the distance using the
   --    law of cosines.
   --       1.  Distance from the door to the bay at the start of the aisle.
   --       2.  Distance from the door to the bay at the end of the aisle.
   --       3.  Distance from the start of the aisle to the bay in 2.
   --       4.  Distance from the start of the aisle to the destination bay.
   --
   --   It is possible the door to bay distances setup are not direct line
   --   distances which will prevent the distance from being calculated by
   --   this function.  This is not an error.
   --
   --  Parameters:
   --      i_dock_num     - Specified dock number.
   --      i_from_door    - Specified door.
   --      i_to_bay       - Destination bay.  It can be the complete location or
   --                       just the aisle and bay (ie. from haul).
   --                       Examples: DA20, DA24A3
   --      i_min_bay      - Lowest bay number closest to the destination bay
   --                       that has a door to bay distance setup for
   --                       i_from_door.  It includes the aisle and bay.
   --                       Example: DA03
   --      i_max_bay      - Highest bay number closest to the destination bay
   --                       that has a door to bay distance setup for
   --                       i_from_door.  It includes the aisle and bay.
   --                       Example: DA57
   --      i_min_bay_dist - Distance from i_from_door to i_min_bay.
   --      i_max_bay_dist - Distance from i_from_door to i_max_bay.
   --      o_dist         - Direct line distance from i_from_door to i_to_bay.
   --
   --      i_to_bay, i_min_bay and i_max_bay must be on the same aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_bay_direct_dist
                          (i_dock_num      IN point_distance.point_dock%TYPE,
                           i_from_door     IN point_distance.point_a%TYPE,
                           i_to_bay        IN VARCHAR2,
                           i_min_bay       IN VARCHAR2,
                           i_max_bay       IN VARCHAR2,
                           i_min_bay_dist  IN NUMBER,
                           i_max_bay_dist  IN NUMBER)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_dist_using_door_bay_dist
   --
   -- Description:
   --    This fuction finds the shortest distance between the specified door
   --    and bay on the specified dock using door to bay point distances.
   --    This comes into play for docks that run parallel to the aisles.
   --    When door to bay distances are setup, point type DB, there should
   --    be a distance from the door to the front of the aisle and a distance
   --    from the door to the end of the aisle.
   ---------------------------------------------------------------------------
   FUNCTION f_get_dist_using_door_bay_dist 
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_bay     IN VARCHAR2)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and bay
   --    on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_door                  IN point_distance.point_a%TYPE,
                 i_to_bay                     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_door_dist
   --
   -- Description:
   --    This function finds the distance between two doors within the
   --    same area.  The doors can be on different docks but the docks need
   --    to be in the same area.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_door_dist
                         (i_from_dock_num  IN point_distance.point_dock%TYPE,
                          i_to_dock_num    IN point_distance.point_dock%TYPE,
                          i_from_door      IN point_distance.point_a%TYPE,
                          i_to_door        IN point_distance.point_a%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_dr_to_dr_dist_diff_dock
   --
   -- Description:
   --    This function finds the distance between two doors within the
   --    same area but on different docks.
   --
   --    The following distances are calculated then added together to get
   --    the door to door distance.
   --       - Determine the aisle closest to the from door and get the
   --       - length of this aisle.
   --       - Distance from the from door to the closest aisle.
   --       - Distance from the to door to the closest aisle.
   --
   --    Called by f_get_door_to_door_dist.
   ---------------------------------------------------------------------------
   FUNCTION f_get_dr_to_dr_dist_diff_dock
                         (i_from_dock_num  IN point_distance.point_dock%TYPE,
                          i_to_dock_num    IN point_distance.point_dock%TYPE,
                          i_from_door      IN point_distance.point_a%TYPE,
                          i_to_door        IN point_distance.point_a%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between the specified pickup point
   --    and aisle on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_aisle_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_pup   IN point_distance.point_a%TYPE,
                           i_to_aisle   IN point_distance.point_b%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the specified pickup point
   --    and bay on the specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_bay_dist
                (i_dock_num   IN point_distance.point_dock%TYPE,
                 i_from_pup   IN point_distance.point_a%TYPE,
                 i_to_bay     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_pup_dist
   --
   -- Description:
   --    This function finds the distance between two pickup points on the
   --    specified dock.
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_pup_dist
                        (i_dock_num     IN point_distance.point_dock%TYPE,
                         i_from_pup     IN point_distance.point_a%TYPE,
                         i_to_pup       IN point_distance.point_b%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    add_distance
   --
   -- Description:
   --    This procedure adds the distances in the second distance record
   --    to the first distance record.
   ---------------------------------------------------------------------------
   PROCEDURE add_distance(io_rec1   IN OUT pl_lmc.t_distance_rec,
                          i_rec2    IN     pl_lmc.t_distance_rec);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_point_type
   --
   -- Description:
   --    This procedure determines the type of the specified point and the
   --    dock it is at.  The valid point type are:
   --       - A  Aisle
   --       - B  Bay  (example DA05)
   --       - D  Door
   --       - P  Pickup point
   --       - W  Warehouse.  This could be referring to a warehouse as
   --            designated by D, C or F or could be referring to a dock
   --            such as D1 or C1.
   ---------------------------------------------------------------------------
   PROCEDURE get_point_type(i_point      IN VARCHAR2,
                            o_point_type OUT point_distance.point_type%TYPE,
                            o_dock_num   OUT point_distance.point_dock%TYPE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_travel_docks
   --
   -- Description:
   --    This procedure sets what dock the forklift operator is leaving from
   --    and what dock the forklift operator will arrive at when traveling
   --    from one forklift labor mgmt section to another.  A forklift labor
   --    mgmt section is how the warehouse is split up when defining the
   --    forklift distances.  By default the distance calculation is expecting
   --    the travel between two sections will be from front dock to front dock
   --    but this is not necessarily the case (ie OpCo 96 Abbott).
   --    Table TRAVEL_DOCK is used to specify the travel docks.
   --    If nothing is setup then the the dock parameters are left unchanged.
   --    See the package specification modification history dated 3/28/08
   --    for more information.
   ---------------------------------------------------------------------------
   PROCEDURE set_travel_docks
                (io_r_src_point   IN OUT  pl_lmd.t_point_info_rec,
                 io_r_dest_point  IN OUT  pl_lmd.t_point_info_rec);


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_pt_to_pt_dist
   --
   -- Description:
   --    This function calculates the distance between two points.
   ---------------------------------------------------------------------------
   PROCEDURE get_pt_to_pt_dist
                (i_src_point                  IN     VARCHAR2,
                 i_dest_point                 IN     VARCHAR2,
                 i_equip_rec                  IN     pl_lmc.t_equip_rec,
                 i_follow_aisle_direction_bln IN     BOOLEAN,
                 io_dist_rec                  IN OUT pl_lmc.t_distance_rec);

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_same_area_dist
   --
   -- Description:
   --    This function calculates the distance between two points in the
   --    same area.
   ---------------------------------------------------------------------------
   FUNCTION f_get_same_area_dist
               (i_src_pt_rec                 IN t_point_info_rec, 
                i_dest_pt_rec                IN t_point_info_rec,
                i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_diff_area_dist
   --
   -- Description:
   --    This function calculates the distance between two points that are
   --    in different areas.
   ---------------------------------------------------------------------------
   FUNCTION f_get_diff_area_dist
               (i_src_pt_rec                 IN t_point_info_rec, 
                i_dest_pt_rec                IN t_point_info_rec,
                i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_whse_to_aisle_dist
   --
   -- Description:
   --    This procedure finds the aisle in one dock closest to another dock
   --    and the distance from this aisle to the other dock.
   ---------------------------------------------------------------------------
   PROCEDURE get_whse_to_aisle_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE,
                           o_first_aisle   OUT point_distance.point_a%TYPE,
                           o_dist          OUT NUMBER);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_whse_to_door_dist
   --
   -- Description:
   --    This procedure finds the door in one dock closest to another dock
   --    and the distance from this door to the other dock.
   ---------------------------------------------------------------------------
   PROCEDURE get_whse_to_door_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE,
                           o_first_door    OUT point_distance.point_a%TYPE,
                           o_dist          OUT NUMBER);

   ---------------------------------------------------------------------------
   -- Function:
   --    get_whse_to_pup_dist
   --
   -- Description:
   --    This function finds the distance from a pickup point on the "from"
   --    dock to the point in the travel lane on the "from" dock where we
   --    are just leaving the dock on the way to the "to" dock.
   ---------------------------------------------------------------------------
   FUNCTION get_whse_to_pup_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_pup_point     IN  point_distance.point_a%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    segment_distance
   --
   -- Description:
   --    This procedure segments the distance in total distance into three 
   --    distances for KVI calculations.
   ---------------------------------------------------------------------------
   PROCEDURE segment_distance(io_dist_rec  IN OUT pl_lmc.t_distance_rec);

   ---------------------------------------------------------------------------
   -- Function:
   --    get_whse_to_whse_dist
   --
   --    specified docks.
   -- Description:
   --    This function finds the distance between the two warehouses for the
   --    specified docks.  A warehouse is the dry, cooler or freezer areas
   --    at the company.
   --
   --    This distance can be the distance between docks in different 
   --    warehouses (the preferred setup) or can be the distance between
   --    the warehouses.  If there is more than one dock in a warehouse then
   --    the distance between docks needs to be specified otherwise the 
   --    distance calculated will be incorrrect.
   ---------------------------------------------------------------------------
   FUNCTION f_get_whse_to_whse_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE)
   RETURN NUMBER;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_next_point
   --
   -- Description:
   --    This function fetches the ending point for the batch being completed.
   --    The ending point will be one of the following:
   --       - The kvi_from_loc of the batch the user is signing onto.
   --       - The kvi_to_loc of the batch the user is signing onto.
   --       - The last completed drop point of a suspended batch which the user
   --         is in the process of reattaching to.
   ---------------------------------------------------------------------------
   PROCEDURE get_next_point
                (i_batch_no        IN  arch_batch.batch_no%TYPE,
                 i_user_id         IN  arch_batch.user_id%TYPE,
                 o_point           OUT arch_batch.kvi_from_loc%TYPE);

END pl_lmd;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lmd

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lmd
IS
   -- sccs_id=%Z% %W% %G% %I%

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_lmd
   --
   -- Description:
   --    Labor management distance calculation package.
   --
   --    Date     Designer Comments
   --    -------- -------  ----------------------------------------------------
   --    05/31/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
   --                      This may one day replace the
   --                      PRO*C program lm_forklift.pc.  The initial use is
   --                      for calculating distances for discrete selection.
   --
   --    06/21/02 prpbcb   Change function f_get_cross_aisle_dist() to not
   --                      error out when the previous aisle record "to"
   --                      location is the the same as the current aisle
   --                      record "from" location.  The aisle to aisle setup
   --                      can cause this to happen but this is not an error.
   --                      We ran into this situation at co. 35.
   -- 
   --                      Changed cursor c_aisle in function get_point_type()
   --                      that determines if the point is an aisle to look at
   --                      aisle to aisle distances.  Before it looked at door
   --                      to aisles distances.  It is possible to have a dock
   --                      with aisles that have no door to aisle distances
   --                      which is why this change was made.  This means that
   --                      if a dock has only one aisle then this aisle
   --                      needs an aisle to aisle distance setup to itself
   --                      with a distance of 0.
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_lmd';   -- Package name.  Used in
                                             -- error messages.

   gl_e_numeric_error  EXCEPTION;
   PRAGMA EXCEPTION_INIT(gl_e_numeric_error, -6502);

   gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                    -- function is null.



   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   -- Divider for audit messages to make the audit report easier to read.
   ct_audit_msg_divider CONSTANT VARCHAR2(80) :=
              '------------------------------------------------------------';

   ------------------------
   -- Valid point types.  
   ------------------------
   ct_pt_type_aisle      CONSTANT VARCHAR(1) := 'A';    -- Aisle
   ct_pt_type_bay        CONSTANT VARCHAR(1) := 'B';    -- Bay
   ct_pt_type_door       CONSTANT VARCHAR(1) := 'D';    -- Door
   ct_pt_type_pup        CONSTANT VARCHAR(1) := 'P';    -- Pickup point
   ct_pt_type_warehouse  CONSTANT VARCHAR(1) := 'W';    -- Warehouse (area) or
                                                        -- could be a dock.

   -- Used to flag if a pt to pt distance was found in a function.  Used
   -- instead of boolean variables.
   ct_big_number     CONSTANT NUMBER := 9999999999;

   -- Value of pi.  From math.h.
   ct_m_pi           CONSTANT NUMBER :=  3.14159265358979323846264338327950288;

   -- Forklift accelerate, decelerate distances.
   ct_accelerate_distance   CONSTANT NUMBER := 9;  -- Accelerate distance
   ct_decelerate_distance   CONSTANT NUMBER := 11; -- Decelerate distance


   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_dock_location
   --
   -- Description:
   --    This function finds the location of a dock.
   --
   --  Parameters:
   --    i_dock   -  Aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_dock_not_found  - Dock not found in DOCK table.
   --    pl_exc.e_database_error     - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/22/02 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_dock_location(i_dock  IN dock.dock_no%TYPE)
   RETURN dock.location%TYPE IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_dock_location';

      l_dock_location  dock.location%TYPE;   -- Dock location

      -- This cursor selects the location of the dock.
      CURSOR c_dock_location(cp_dock IN dock.dock_no%TYPE) IS
         SELECT location
           FROM dock
          WHERE dock_no = cp_dock;
   BEGIN

      l_message_param := l_object_name || '(' || i_dock || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_dock_location(i_dock);
      FETCH c_dock_location INTO l_dock_location;
    
      IF (c_dock_location%NOTFOUND) THEN
         CLOSE c_dock_location;
         l_message := l_object_name || '  TABLE=dock  ACTION=SELECT' ||
            '  MESSAGE="Dock ' || i_dock ||
            ' not found in dock table."';
         RAISE pl_exc.e_lm_dock_not_found;
      END IF;

      CLOSE c_dock_location;

      -- Check the value of the dock location.  If it is not the value of one
      -- of the constants the designate the dock location the write an aplog
      -- message and set the dock location to a front dock.

      IF (l_dock_location NOT IN (ct_front_dock, ct_back_dock,
                                  ct_side_dock)) THEN
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, 
             'Have an unhandled value[' || l_dock_location ||
             '] for the dock location.  Handling it as a FRONT DOCK.',
             pl_exc.ct_data_error, NULL);

         l_dock_location := ct_front_dock;
      END IF;

      RETURN(l_dock_location);

   EXCEPTION
      WHEN pl_exc.e_lm_dock_not_found THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_dock_location;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    find_closest_aisles
   --
   -- Description:
   --    This procedure finds the aisle before and the aisle after a
   --    specified aisle but in the opposite direction.
   --
   --    If the direction is null in the AISLE INFO table then the results
   --    probably will not be what is desired.
   --
   -- Parameters:
   --    i_aisle           - Specified aisle.
   --    o_aisle_before    - The aisle before.
   --    o_aisle_after     - The aisle after.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Database error.
   --
   -- Called by:
   --    
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/20/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE find_closest_aisles(i_aisle        IN  aisle_info.name%TYPE,
                                 o_aisle_before OUT aisle_info.name%TYPE,
                                 o_aisle_after  OUT aisle_info.name%TYPE)
   IS
      l_message       VARCHAR2(128);    -- Message buffer
      l_message_param VARCHAR2(128);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.find_closest_aisles';

      -- This cursor finds the closest aisle before the specified aisle but
      -- in the opposite direction.
      CURSOR c_aisle_before(cp_aisle IN  aisle_info.name%TYPE) IS
         SELECT ai1.name
           FROM aisle_info ai1, aisle_info ai2
          WHERE ai2.name = cp_aisle
            AND ai1.sub_area_code = ai2.sub_area_code
            AND ai1.direction != ai2.direction
            AND (ai1.physical_aisle_order < ai2.physical_aisle_order
                 OR ai1.name < ai2.name)
          ORDER BY NVL(LPAD(TO_CHAR(ai1.physical_aisle_order), 10, '0'),
                   ai1.name) DESC;

      CURSOR c_aisle_after(cp_aisle IN  aisle_info.name%TYPE) IS
         SELECT ai1.name
           FROM aisle_info ai1, aisle_info ai2
          WHERE ai2.name = cp_aisle
            AND ai1.sub_area_code = ai2.sub_area_code
            AND ai1.direction != ai2.direction
            AND (ai1.physical_aisle_order > ai2.physical_aisle_order
                 OR ai1.name > ai2.name)
          ORDER BY NVL(LPAD(TO_CHAR(ai1.physical_aisle_order), 10, '0'),
                   ai1.name) ASC;

   BEGIN

      l_message_param := l_object_name || '(i_aisle[' || i_aisle || '],' ||
                            'o_aisle_before,o_aisle_after)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_aisle_before(i_aisle);
      FETCH c_aisle_before INTO o_aisle_before;
      IF (c_aisle_before%NOTFOUND) THEN
         o_aisle_before := NULL;
      END IF;
      CLOSE c_aisle_before;

      OPEN c_aisle_after(i_aisle);
      FETCH c_aisle_after INTO o_aisle_after;
      IF (c_aisle_after%NOTFOUND) THEN
         o_aisle_after := NULL;
      END IF;
      CLOSE c_aisle_after;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END find_closest_aisles;


   ---------------------------------------------------------------------------
   -- Function:
   --    myacos
   --
   -- Description:
   --    This function returns the arccosine.
   --    PL/SQL included Oracle 7 did not have the acos implemented.
   --
   -- Parameters:
   --    z      - Value to return the arccosine for.  Must be between -1 and 1.
   --
   -- Return Value:
   --    The arccosine.  Will be between 0 and pi.
   --
   -- Exceptions raised:
   --    pl_exc.e_numeric_error        Unable to determine the arccosine 
   --                                  or z not between -1 and 1.
   --    pl_exc.e_database_error       Some kind of error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/27/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION myacos (z IN NUMBER)
   RETURN NUMBER IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.myacos';

      l_ct_tolerance            CONSTANT NUMBER := .0000001;
      l_ct_initialize_guess     CONSTANT NUMBER := ct_m_pi / 2;   -- 90 degrees
      l_max_iterations CONSTANT BINARY_INTEGER := 30;
      -- Getting to the tolerance will not take more than 30
      -- iterations using a binary search.
     
      l_counter  BINARY_INTEGER := 0;
      l_diff     NUMBER;
      l_upper_y  NUMBER := ct_m_pi;
      l_lower_y  NUMBER := 0;
      x          NUMBER;
      y          NUMBER := l_ct_initialize_guess;
   BEGIN

      l_message_param := l_object_name || '(z = ' || TO_CHAR(z) || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (z NOT BETWEEN -1 and 1) THEN
         RAISE gl_e_numeric_error;
      END IF;

      LOOP
         l_counter := l_counter + 1;
         x := COS(y);
         l_diff := z - x;
         EXIT WHEN ABS(l_diff) <= l_ct_tolerance
                   OR l_counter > l_max_iterations;

         IF (l_diff >= 0) THEN
            l_upper_y := y;
         ELSE
            l_lower_y := y;
         END IF;

         y := (l_upper_y + l_lower_y) / 2;

      END LOOP;

      IF (l_counter > l_max_iterations) THEN
         RAISE gl_e_numeric_error;
      END IF;

      RETURN(y);

   EXCEPTION
      WHEN gl_e_numeric_error THEN
         RAISE;     -- To be handled by the calling function.
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);

   END;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_ab_angle
   --
   -- Description:
   --    This function calculates the angle in radians between sides a and b
   --    of a triangle when the lengths of all sides are known.
   --    Law of cosines is used.  If side a or side b is zero then an
   --    aplog message is output and 0 is returned.
   --
   --    READ THIS.  Function "acos" is not implemented in Oracle 7.2 so
   --    function "myacos" was written to get the arccosine.  "acos" is
   --    implemnted in Oracle 8 so once we get to Oracle the "myacos" 
   --    in the function can be changed to "acos".
   --
   -- Parameters:
   --    i_side_a - Length of side a.
   --    i_side_b - Length of side b.
   --    i_side_c - Length of side c.
   --
   -- Return Value:
   --    If side a or side b is zero then 0 returned.
   --    If an error occurs when determining then angle the -1 is returned.
   --    Otherwise angle between sides a and b in radians returned.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error        Some kind of error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/27/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_ab_angle(i_side_a  IN NUMBER,
                           i_side_b  IN NUMBER,
                           i_side_c  IN NUMBER)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_ab_angle';

      l_angle          NUMBER := 0;

   BEGIN

      l_message_param := l_object_name || '  side_a[' || i_side_a || ']' ||
            ' side_b[' || i_side_b || '] side_c[' || i_side_c || '].';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (i_side_a = 0 OR i_side_b = 0) THEN
         l_message := l_object_name || '  side_a[' || i_side_a || ']' ||
            ' side_b[' || i_side_b || '] side_c[' || i_side_c || '].' ||
            '  side_a and/or side_b is 0.  Unable to calculate the angle ' ||
            ' between them.  Using 0 as the angle.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message, NULL,
                        NULL);

         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         END IF;  -- end audit
      ELSE
         BEGIN
            l_angle := myacos(((i_side_a * i_side_a) + (i_side_b * i_side_b) -
                          (i_side_c * i_side_c)) / (2 * i_side_a * i_side_b));
         EXCEPTION
            WHEN gl_e_numeric_error THEN
               -- myacos returned gl_e_numeric_error.
               -- Unable to calculate the angle most likely because the
               -- values for the sides are not physically possible.
               -- Set angle to -1 to indicate to the calling object that
               -- unable to determine angle.
               l_angle := -1;
        
               l_message := l_object_name || '  side_a[' || i_side_a || ']' ||
                  ' side_b[' || i_side_b || '] side_c[' || i_side_c || '].' ||
                  '  Got numeric error when calculate angle between sides a '||
                  ' and b because the lengths cannot for a triangle.' ||
                  '  Setting angle to ' || TO_CHAR(l_angle);  

               pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                              NULL, NULL);

               IF (pl_lma.g_audit_bln) THEN
                  l_message := 'Unable to determine angle between sides a' ||
                     ' and  b of triangle.  Lengths: side a: ' ||
                     i_side_a ||   'side b: ' || i_side_b || '  side c: ' ||
                     i_side_c || '.  The lengths cannot form a triangle.';
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
               END IF;  -- end audit
         END;
      END IF;

      RETURN(l_angle);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);

   END f_get_ab_angle;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_side_a_length
   --
   -- Description:
   --    This function calulates the length of side a of a triangle when given
   --    sides b and c and the angle between sides b and c.
   --    Law of cosines is used.
   --
   -- Parameters:
   --    i_side_b   - Length of side b
   --    i_side_c   - Length of side c
   --    i_bc_angle - Angle between sides b and c in radians.
   --
   -- Return Value:
   --     If unable to determine the distance then -1 is returned othewise
   --     the length of side a is returned.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Some kind of error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/27/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_side_a_length(i_side_b    IN NUMBER,
                                i_side_c    IN NUMBER,
                                i_bc_angle  IN NUMBER)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_side_a_length';

      l_side_a  NUMBER := 0;
   BEGIN 

      l_message_param := l_object_name || '  i_side_b[' || i_side_b ||
                   '] i_side_c[' || i_side_c || ']  bc_angle[' ||
                   TO_CHAR(i_bc_angle);
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      BEGIN
         l_side_a := sqrt(((i_side_b * i_side_b) + (i_side_c * i_side_c)) -
                            (2.0 * i_side_b * i_side_c * cos(i_bc_angle)));

      EXCEPTION
         WHEN OTHERS THEN
            -- Got some kinda error.  Set the return value to -1 and write an
            -- aplog message.
            l_side_a := -1;     -- -1 denotes error occured
            l_message := l_object_name || '  i_side_b[' || i_side_b ||
               '] i_side_c[' || i_side_c || ']  bc_angle[' ||
               TO_CHAR(i_bc_angle) ||
               '  Error occurred in the calculation.  Will use ' ||
               l_side_a || ' as the length of side a';
   
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
   
            IF (pl_lma.g_audit_bln) THEN
                pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                 pl_lma.ct_detail_level_2);
            END IF;  -- end audit
      END;

      RETURN(l_side_a);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);

   END f_get_side_a_length;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    parse_location
   --
   -- Description:
   --    This procedure parses a location into the aisle, bay, position and
   --    level components.
   --
   -- Parameters:
   --    i_location    - The location to parse.
   --    o_aisle       - Location aisle.
   --    o_bay         - Location bay.
   --    o_position    - Location position.
   --    o_level       - Location level.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Some kind of error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/29/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   PROCEDURE parse_location(i_location  IN  VARCHAR2,
                            o_aisle     OUT VARCHAR2,
                            o_bay       OUT VARCHAR2,
                            o_position  OUT VARCHAR2,
                            o_level     OUT VARCHAR2)
   IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.parse_location';

   BEGIN

      l_message_param  := l_object_name || '(' || i_location || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      o_aisle    := SUBSTR(i_location, 1,2);
      o_bay      := SUBSTR(i_location, 3,2);
      o_position := SUBSTR(i_location, 5,1);
      o_level    := SUBSTR(i_location, 6,1);
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);
   END parse_location;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    segment_distance
   --
   -- Description:
   --    This procedure segments the distance in total distance into three 
   --    distances for KVI calculations.
   --
   -- Parameters:
   --    io_dist_rec  - Distance record
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Some kind of error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/08/01 prpbcb   Created.  
   --
   --    10/08/00 prpbcb   History from PRO*C program.
   --    03/23/99 prpbcb   Changed decel distance from 5 to 11.
   --    06/11/99 prpbcb   Added l_include_accel_decel local variable.
   --                      This was first setup as a parameter to indicate if
   --                      to include or not to include accelerate and
   --                      decelerate for a segment between two points.  Now I
   --                      just put it as a local variable.  Only one call to
   --                      lmd_segment_distance is made which is in
   --                      lmd_get_pt_to_pt_dist.  The function calls in the
   --                      functions that calculate a segment distance have
   --                      been commented out.  They may been deleted for
   --                      PL/SQL.
   --                      The valid values for l_include_accel_decel are:
   --                         - A  Include accelerate distance.
   --                         - D  Include decelerate distance.
   --                         - B  Include both accelerate and
   --                              decelerate distances.
   --                         - N  Do not include accelerate and
   --                              decelerate distances.
   --    12/03/99 prpbcb   Modified function to handle the acccelerate and
   --                      decelerate distances as floats.
   ---------------------------------------------------------------------------
   PROCEDURE segment_distance(io_dist_rec  IN OUT pl_lmc.t_distance_rec)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(512);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.segment_distance';

      l_include_accel_decel  VARCHAR2(1) := 'B';

   BEGIN

      l_message_param := l_object_name ||
         '  l_include_accel_decel=' || l_include_accel_decel ||
     '  io_dist_rec.accel_distance=' || TO_CHAR(io_dist_rec.accel_distance) ||
     '  io_dist_rec.decel_distance=' || TO_CHAR(io_dist_rec.decel_distance) ||
     '  io_dist_rec.travel_distance=' || TO_CHAR(io_dist_rec.travel_distance) ||
     '  io_dist_rec.total_distance=' || TO_CHAR(io_dist_rec.total_distance) ||
     '  io_dist_rec.distance_time=' || TO_CHAR(io_dist_rec.distance_time);

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (l_include_accel_decel = 'B') THEN
         -- Include both the accelerate and decelerate distance.  If the
         -- total distance is less than the accelerate and decelerate distances
         -- then prorate the distances.
         IF (io_dist_rec.total_distance >
                  (io_dist_rec.equip_accel_distance +
                   io_dist_rec.equip_decel_distance)) THEN
            io_dist_rec.accel_distance := io_dist_rec.equip_accel_distance; 
            io_dist_rec.decel_distance := io_dist_rec.equip_decel_distance;
            io_dist_rec.travel_distance := io_dist_rec.total_distance -
                     (io_dist_rec.accel_distance + io_dist_rec.decel_distance);
         ELSE
            IF (io_dist_rec.equip_accel_distance +
                        io_dist_rec.equip_decel_distance = 0) THEN
               io_dist_rec.accel_distance := 0;
            ELSE
               io_dist_rec.accel_distance :=
                      io_dist_rec.total_distance *
                            (io_dist_rec.equip_accel_distance /
                                  (io_dist_rec.equip_accel_distance +
                                   io_dist_rec.equip_decel_distance));
            END IF;

            io_dist_rec.decel_distance := io_dist_rec.total_distance -
                                                   io_dist_rec.accel_distance;
            io_dist_rec.travel_distance := 0;
         END IF;
      ELSIF (l_include_accel_decel = 'A') THEN
         -- Include only the accelerate distance.
         IF (io_dist_rec.total_distance > io_dist_rec.equip_accel_distance) THEN
            io_dist_rec.accel_distance := io_dist_rec.equip_accel_distance;
         ELSE
            io_dist_rec.accel_distance := io_dist_rec.total_distance;
         END IF;

         io_dist_rec.decel_distance := 0;
         io_dist_rec.travel_distance := io_dist_rec.total_distance -
                                               io_dist_rec.accel_distance;
      ELSIF (l_include_accel_decel = 'D') THEN
         -- Include only the decelerate distance.
         IF (io_dist_rec.total_distance > io_dist_rec.equip_decel_distance) THEN
            io_dist_rec.decel_distance := io_dist_rec.equip_decel_distance;
         ELSE
            io_dist_rec.decel_distance := io_dist_rec.total_distance;
         END IF;

        io_dist_rec.accel_distance := 0;
        io_dist_rec.travel_distance := io_dist_rec.total_distance -
                                             io_dist_rec.decel_distance;
      ELSIF (l_include_accel_decel = 'N') THEN
         -- Do not include the accelerate and decelerate distances.
         io_dist_rec.accel_distance := 0;
         io_dist_rec.decel_distance := 0;
         io_dist_rec.travel_distance := io_dist_rec.total_distance;
      ELSE
         -- Variable l_include_accel_decel has an unhandled value.
         -- Do not stop processing but write an aplog message.
         l_message := 'Variable l_include_accel_decel has an unhandled' ||
            ' value of[' || l_include_accel_decel || ']';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message, NULL,
                        NULL);
      END IF;

      l_message := l_object_name || '  Leaving procedure' ||
     '  l_include_accel_decel=' || l_include_accel_decel ||
     '  io_dist_rec.accel_distance=' || TO_CHAR(io_dist_rec.accel_distance) ||
     '  io_dist_rec.decel_distance=' || TO_CHAR(io_dist_rec.decel_distance) ||
     '  io_dist_rec.travel_distance=' || TO_CHAR(io_dist_rec.travel_distance) ||
     '  io_dist_rec.total_distance=' || TO_CHAR(io_dist_rec.total_distance) ||
     '  io_dist_rec.distance_time=' || TO_CHAR(io_dist_rec.distance_time);

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);

   END segment_distance;


   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_ds_get_bay_to_bay_dist
   --
   -- Description:
   --    This function gets distance from a bay to a bay taking into account
   --    the aisle direction when the bays are on different aisles.  Used when
   --    the bays are on different aisles.
   --
   --    Note: The bays have to be in the same area.
   --
   --    The bay to bay distance is broken up into three distances:
   --       - bay to aisle end distance
   --       - aisle to aisle distance
   --       - beginning of aisle to the bay
   --
   --    Note: Function f_get_bay_to_bay_dist function is used for forklift
   --          labor manamgent.  The aisle direction does not matter for
   --          forklift labor management but it does for selection.
   --
   -- Parameters:
   --    i_dock_num              - The dock for i_from aisle and i_to_aisle.
   --    i_from_aisle            - From aisle.
   --    i_from_bay              - From bay.
   --    i_from_aisle_direction  - Direction of i_from_aisle.
   --    i_to_aisle              - To aisle.
   --    i_to_bay                - To bay.
   --    i_to_aisle_direction    - Direction of i_to_aisle.
   --  
   -- Return Value:
   --    Distance between the bays.
   --
   -- Exceptions raised:
   --    User defined exception   - A called object returned an user defined
   --                               error.
   --    pl_exc.e_database_error  - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/20/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_ds_get_bay_to_bay_dist
                    (i_dock_num             IN point_distance.point_dock%TYPE,
                     i_from_aisle           IN bay_distance.aisle%TYPE,
                     i_from_bay             IN bay_distance.bay%TYPE,
                     i_from_aisle_direction IN aisle_info.direction%TYPE,
                     i_to_aisle             IN bay_distance.aisle%TYPE,
                     i_to_bay               IN bay_distance.bay%TYPE,
                     i_to_aisle_direction   IN aisle_info.direction%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                              '.f_ds_get_bay_to_bay_dist';

      l_aisle_to_aisle_dist  NUMBER := 0;
      l_bay_to_end_dist      NUMBER := 0;
      l_aisle_to_bay_dist    NUMBER := 0;
      l_bay_to_bay_dist      NUMBER := 0;
      l_aisle_length         NUMBER := 0;
   BEGIN

      l_message_param := l_object_name || '(' ||
                         i_dock_num    || ',' ||
                         i_from_aisle  || ',' ||
                         i_from_bay    || ',' ||
                         TO_CHAR(i_from_aisle_direction) || ',' ||
                         i_to_aisle    || ',' ||
                         i_to_bay      || ',' ||
                         TO_CHAR(i_to_aisle_direction) || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (i_from_aisle != i_to_aisle) THEN
         -- The from and to bays are on different aisles.

         IF (i_from_aisle_direction = pl_lmd.ct_aisle_direction_down) THEN   
            l_bay_to_end_dist := pl_lmd.f_get_bay_to_end_dist(i_from_aisle,
                                                              i_from_bay);
         ELSE
            l_bay_to_end_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dock_num,
                                      i_from_aisle, i_from_aisle||i_from_bay);
         END IF;

         l_aisle_to_aisle_dist :=
                    pl_lmd.f_get_aisle_to_aisle_dist(i_dock_num, i_from_aisle,
                                              i_to_aisle);

         -- If the "from" and "to" aisles are going in the same direction then
         -- give time to travel to the beginning of the "to" aisle.
         IF (i_from_aisle_direction = i_to_aisle_direction) THEN
            l_aisle_length := pl_lmd.f_get_aisle_length(i_to_aisle);

            IF (pl_lma.g_audit_bln) THEN
               l_message := 'Aisle ' || i_from_aisle ||
                  ' and ' || i_to_aisle || ' same direction.' ||
                  '  Give time to travel' || ' to beginning of aisle ' ||
                  i_to_aisle  ||
                  ' which will be the length of the aisle which is ' ||
                  TO_CHAR(l_aisle_length) || ' feet.';
               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit

         END IF;

         IF (i_to_aisle_direction = pl_lmd.ct_aisle_direction_down) THEN   
            l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dock_num,
                                      i_to_aisle, i_to_aisle||i_to_bay);
         ELSE
            l_aisle_to_bay_dist := pl_lmd.f_get_bay_to_end_dist(i_to_aisle,
                                                               i_to_bay);
         END IF;

         l_bay_to_bay_dist := l_bay_to_end_dist + l_aisle_to_aisle_dist +
                              l_aisle_length + l_aisle_to_bay_dist;
      ELSE
         -- The from and to bays are on the same aisle.  Get the distance
         -- between the bays.
         l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                     (i_from_aisle, i_from_bay, i_to_bay);
      END IF;  

      RETURN(l_bay_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_ds_get_bay_to_bay_dist;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_direction
   --
   -- Description:
   --    This function finds the direction of an aisle.
   --
   --  Parameters:
   --    i_aisle   -  Aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_invalid_aisle   - Aisle not found in AISLE_INFO table.
   --    pl_exc.e_database_error  - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/21/02 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_direction(i_aisle  IN aisle_info.name%TYPE)
   RETURN aisle_info.direction%TYPE IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_aisle_direction';

      l_aisle_direction  aisle_info.direction%TYPE;

      -- This cursor selects the direction of an aisle.
      CURSOR c_aisle_direction(cp_aisle IN aisle_info.name%TYPE) IS
         SELECT direction
           FROM aisle_info
          WHERE name = cp_aisle;
   BEGIN
      l_message_param := l_object_name || '(' || i_aisle || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_aisle_direction(i_aisle);
      FETCH c_aisle_direction INTO l_aisle_direction;
    
      IF (c_aisle_direction%NOTFOUND) THEN
         CLOSE c_aisle_direction;
         l_message := l_object_name || '  TABLE=aisle_info  ACTION=SELECT' ||
            '  MESSAGE="Aisle ' || i_aisle ||
            ' not found in aisle_info table."';
         RAISE pl_exc.e_invalid_aisle;
      END IF;

      CLOSE c_aisle_direction;

      -- If the direction is null use 0 as the value and write an
      -- aplog message.  Ideally the direction should not be null.
      IF (l_aisle_direction IS NULL) THEN
         l_aisle_direction := 0;
         l_message := l_object_name || '  TABLE=aisle_info  ACTION=SELECT' ||
            '  MESSAGE="Direction for aisle ' || i_aisle ||
            ' is null.  This can result in an incorrect distance.' ||
            '  Using 0 as the value."';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
      END IF;

      RETURN(l_aisle_direction);

   EXCEPTION
      WHEN pl_exc.e_invalid_aisle THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_aisle_direction;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_length
   --
   -- Description:
   --    This function finds the length of an aisle.
   --
   --  Parameters:
   --    i_aisle   -  Aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_bay_dist_aisle_not_found - Aisle not found in bay_distance
   --                                           table.
   --    User defined exception   - A called object returned an user defined
   --                               error.
   --    pl_exc.e_database_error  - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/18/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_length(i_aisle  IN bay_distance.aisle%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_aisle_length';

      l_aisle_length  NUMBER;   -- Length of the aisle.

      -- This cursor selects the length of an aisle.
      CURSOR c_aisle_length(cp_aisle IN bay_distance.aisle%TYPE) IS
         SELECT bay_dist
           FROM bay_distance
          WHERE aisle = cp_aisle
            AND bay = 'END';
   BEGIN

      l_message_param := l_object_name || '(' || i_aisle || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_aisle_length(i_aisle);
      FETCH c_aisle_length INTO l_aisle_length;
    
      IF (c_aisle_length%NOTFOUND) THEN
         CLOSE c_aisle_length;
         l_message := l_object_name || '  TABLE=bay_distance  ACTION=SELECT' ||
            '  MESSAGE="Aisle ' || i_aisle ||
            ' not found in bay_distance table."';
         RAISE pl_exc.e_lm_bay_dist_aisle_not_found;
      END IF;

      CLOSE c_aisle_length;

      RETURN(l_aisle_length);

   EXCEPTION
      WHEN pl_exc.e_lm_bay_dist_aisle_not_found THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_aisle_length;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_first_bay
   --
   -- Description:
   --    This function finds the first bay on an aisle closest to the front
   --    of the warehouse.  The aisle direction is used to determine what bay
   --    is closest.  The bay is taken from the bay distance setup.
   --
   --    If the aisle does not have a direction defined in the aisle info
   --    then 0 is used as the direction.
   --
   --  Parameters:
   --    i_aisle   -  Aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_bay_dist_aisle_not_found - Aisle not found in bay_distance
   --                                           table.
   --    User defined exception   - A called object returned an user defined
   --                               error.
   --    pl_exc.e_database_error  - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/18/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_first_bay(i_aisle  IN bay_distance.aisle%TYPE)
   RETURN VARCHAR2 IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_first_bay';

      l_first_bay  bay_distance.bay%TYPE;   -- First bay on the aisle.

      -- This cursor selects the first bay on the aisle that has a bay
      -- distance.  The MIN(ai.direction) is always the same value since
      -- only one record is selected from aisle_info.
      CURSOR c_first_bay(cp_aisle bay_distance.aisle%TYPE) IS
         SELECT DECODE(MIN(ai.direction), 1, MAX(bd.bay),
                       MIN(bd.bay)) first_bay
           FROM aisle_info ai, bay_distance bd
          WHERE bd.aisle = cp_aisle
            AND bd.bay != 'END'
            AND ai.name = bd.aisle;

   BEGIN
      l_message_param := l_object_name || '(' || i_aisle || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_first_bay(i_aisle);
      FETCH c_first_bay INTO l_first_bay;
    
      IF (c_first_bay%NOTFOUND) THEN
         CLOSE c_first_bay;
         l_message := l_object_name || '  TABLE=bay_distance,aisle_info' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Aisle ' || i_aisle ||
            ' not found.  Check bay_distance and aisle_info tables."';
         RAISE pl_exc.e_lm_bay_dist_aisle_not_found;
      END IF;

      CLOSE c_first_bay;

      RETURN(l_first_bay);

   EXCEPTION
      WHEN pl_exc.e_lm_bay_dist_aisle_not_found THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_first_bay;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between two aisles on a dock.
   --
   --  Parameters:
   --    i_dock_num    - The dock the aisles are on.
   --    i_from_aisle  - Starting aisle.
   --    i_to_aisle    - Ending aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_ata - Aisle(s) not setup.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/18/01 prpbcb   Created.  
   --
   --    07/30/00 prpbcb   History from PRO*C program.
   --                      DN 10343
   --                      Changed the selection of the aisles to use column
   --                      PHYSICAL_AISLE_ORDER in the AISLE_INFO table.
   --                      This is a new column used to designate the
   --                      physical aisle order in a warehouse.  Before it was
   --                      expected the aisles to be physically ordered by the
   --                      aisle name which is not always the case which would
   --                      result in incorrect distances.
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_to_aisle_dist
                        (i_dock_num     IN point_distance.point_dock%TYPE,
                         i_from_aisle   IN point_distance.point_a%TYPE,
                         i_to_aisle     IN point_distance.point_a%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.f_get_aisle_to_aisle_dist';

      l_aisle_to_aisle_dist  NUMBER;           -- Aisle to aisle distance
      l_from_seq             BINARY_INTEGER := NULL;
      l_temp_from_seq        BINARY_INTEGER;
      l_temp_to_seq          BINARY_INTEGER;
      l_to_seq               BINARY_INTEGER := NULL;
      hold                   BINARY_INTEGER := 0;

      e_no_aisle_info_from_aisle  EXCEPTION;  -- From aisle not in aisle info.
      e_no_aisle_info_to_aisle    EXCEPTION;  -- To aisle not in aisle info.

      CURSOR c_aisle_order(cp_aisle VARCHAR2) IS
         SELECT physical_aisle_order
           FROM aisle_info
          WHERE name = cp_aisle;

      -- This cursor selects the aisle to aisle distance.
      CURSOR c_aa_dist IS
         SELECT NVL(sum(pd.point_dist), 0)
           FROM point_distance pd, aisle_info ai1, aisle_info ai2
          WHERE pd.point_type = 'AA'
            AND pd.point_dock = i_dock_num
            AND pd.point_a    = ai1.name
            AND pd.point_b    = ai2.name
            AND DECODE(l_from_seq,
                       NULL, (ASCII(SUBSTR(pd.point_a,1,1))*100) +
                                            ASCII(SUBSTR(pd.point_a,2,1)),
                       ai1.physical_aisle_order)
                BETWEEN l_temp_from_seq AND l_temp_to_seq
            AND DECODE(l_from_seq,
                       NULL, (ASCII(SUBSTR(pd.point_b,1,1))*100) +
                                            ASCII(SUBSTR(pd.point_b,2,1)),
                       ai2.physical_aisle_order)
                BETWEEN l_temp_from_seq AND l_temp_to_seq;

   BEGIN

      l_message_param := l_object_name ||
                   '(i_dock_num[' || i_dock_num || ']' ||
                   ',i_from_aisle[' || i_from_aisle || ']' ||
                   ',i_to_aisle[' || i_to_aisle || '])';
   
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Get the distance between the aisles.  If they are the same aisle
      -- the distance will be zero.
      IF (i_from_aisle != i_to_aisle) THEN
         OPEN c_aisle_order(i_from_aisle);
         FETCH c_aisle_order INTO l_from_seq;
         IF (c_aisle_order%NOTFOUND) THEN
            CLOSE c_aisle_order;
            RAISE e_no_aisle_info_from_aisle;
         END IF;
         CLOSE c_aisle_order;

         OPEN c_aisle_order(i_to_aisle);
         FETCH c_aisle_order INTO l_to_seq;
         IF (c_aisle_order%NOTFOUND) THEN
            CLOSE c_aisle_order;
            RAISE e_no_aisle_info_to_aisle;
         END IF;
         CLOSE c_aisle_order;

         IF (l_from_seq IS NULL OR l_to_seq IS NULL) THEN
            l_temp_from_seq := (ASCII(SUBSTR(i_from_aisle,1,1)) * 100) +
                                     ASCII(SUBSTR(i_from_aisle,2,1));
            l_temp_to_seq := (ASCII(SUBSTR(i_to_aisle,1,1)) * 100) +
                                   ASCII(SUBSTR(i_to_aisle,2,1));

            l_from_seq := NULL;
            l_to_seq := NULL;

            IF (l_temp_from_seq > l_temp_to_seq) THEN
               hold := l_temp_to_seq;
               l_temp_to_seq := l_temp_from_seq;
               l_temp_from_seq := hold;
            END IF;
         ELSIF (l_from_seq > l_to_seq) THEN
            l_temp_from_seq := l_to_seq;
            l_temp_to_seq := l_from_seq;
         ELSE
            l_temp_from_seq := l_from_seq;
            l_temp_to_seq := l_to_seq;
         END IF;

         OPEN c_aa_dist;
         FETCH c_aa_dist INTO l_aisle_to_aisle_dist;

         IF (c_aa_dist%NOTFOUND) THEN
            CLOSE c_aa_dist;
            RAISE pl_exc.e_lm_pt_dist_badsetup_ata;
         END IF;

         CLOSE c_aa_dist;
      ELSE 
         l_aisle_to_aisle_dist := 0;  -- The source and destination aisles
                                      -- are the same.
      END IF;

      IF (     pl_lma.g_audit_bln
           AND pl_lma.g_suppress_audit_message_bln = FALSE) THEN
         l_message := 'Aisle to Aisle Distance  Dock: ' || i_dock_num ||
            ' From Aisle: ' || i_from_aisle || '  To Aisle: ' || i_to_aisle;
         pl_lma.audit_cmt(l_message, l_aisle_to_aisle_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      l_message := 'aisle to aisle dist: ' || TO_CHAR(l_aisle_to_aisle_dist);

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);

      RETURN(l_aisle_to_aisle_dist);

   EXCEPTION
      WHEN e_no_aisle_info_from_aisle THEN
         l_message := l_message_param || '  TABLE=aisle_info  ACTION=SELECT' ||
                      '  MESSAGE="From aisle not found in aisle info."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_ata, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_ata, l_message);

      WHEN e_no_aisle_info_to_aisle THEN
         l_message := l_message_param || '  TABLE=aisle_info  ACTION=SELECT' ||
                      '  MESSAGE="To aisle not found in aisle info."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_ata, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_ata, l_message);

      WHEN pl_exc.e_lm_pt_dist_badsetup_ata THEN
         l_message := l_message_param ||
            '  Aisle to aisle distance not setup for from and/or to aisle.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_aisle_to_aisle_dist;  


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_aisle_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the specified aisle and bay
   --    on the specified dock.
   --
   -- Parameters:
   --    i_dock_num   - Dock aisle is on.
   --    i_from_aisle - Starting aisle.
   --    i_to_bay     - Ending bay.  Can either be a location or the aisle
   --                    and bay only (ie. from haul).  It cannot be just
   --                    the bay.  Examples: DA01, DA10B3.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_bay_dist_bad_setup   - Aisle to bay distance not found.
   --    pl_exc.e_lm_dock_not_found       - Dock not in DOCK table.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/28/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_aisle_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_aisle                 IN point_distance.point_a%TYPE,
                 i_to_bay                     IN loc.logi_loc%TYPE,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                            '.f_get_aisle_to_bay_dist';

      l_aisle_to_aisle_dist  NUMBER := 0;  -- Distance between the
                                           -- source and destination aisles.
      l_aisle_to_bay_dist    NUMBER := 0;  -- Aisle to bay distance

      l_dock_location  dock.location%TYPE;      -- Dock location 
      l_level          loc.logi_loc%TYPE;       -- Location level.  Extracted
                                                -- from i_to_bay
      l_position       loc.logi_loc%TYPE;       -- Location position.  Extracted
                                                -- from i_to_bay
      l_to_aisle       bay_distance.aisle%TYPE; -- "To" aisle extracted from
                                                -- i_to_bay
      l_to_bay         bay_distance.bay%TYPE;   -- "To" bay extracted from
                                                -- i_to_bay

      l_save_suppress_audit_msg_bln BOOLEAN; -- For saving current value of
                                        -- pl_lma.g_suppress_audit_message_bln

      -- This cursor selects the distance from the beginning of an aisle
      -- to a bay on the aisle.
      CURSOR c_aisle_to_bay_dist IS
         SELECT bay_dist
           FROM bay_distance
          WHERE aisle = l_to_aisle
            AND bay   = l_to_bay;

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
                         '(i_dock_num[' || i_dock_num || ']' ||
                         ',i_from_aisle[' || i_from_aisle || ']' ||
                         ',i_to_bay[' || i_to_bay || ']' ||
                         ',i_follow_aisle_direction[' || l_message || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      pl_lmd.parse_location(i_to_bay, l_to_aisle, l_to_bay, l_position,
                            l_level);

      IF (pl_lma.g_audit_bln AND
                     pl_lma.g_suppress_audit_message_bln = FALSE) THEN
         l_message := 'Calculate aisle to bay distance.' ||
            '  Dock: ' || i_dock_num || '  Aisle: ' || i_from_aisle ||
            '  To Bay: ' || l_to_aisle || l_to_bay;
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF; -- end audit

      -- Get the dock location.
      l_dock_location := f_get_dock_location(i_dock_num);

      -- If the source and destination aisles are different then
      -- get the distance between the two aisles.
      IF (i_from_aisle != l_to_aisle) THEN
         l_aisle_to_aisle_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dock_num,
                                              i_from_aisle, l_to_aisle);
      END IF;
      
      --
      -- Get the distance from the "to" aisle to the "to" bay.
      --
      IF (l_dock_location = pl_lmd.ct_front_dock OR
          l_dock_location = pl_lmd.ct_side_dock) THEN

         -- Get the distance from the start of the aisle to the bay.
         OPEN c_aisle_to_bay_dist;
         FETCH c_aisle_to_bay_dist INTO l_aisle_to_bay_dist;

         IF (c_aisle_to_bay_dist%NOTFOUND) THEN
            CLOSE c_aisle_to_bay_dist;
            RAISE pl_exc.e_lm_bay_dist_bad_setup;
         END IF;

         CLOSE c_aisle_to_bay_dist;

      ELSIF (l_dock_location = pl_lmd.ct_back_dock) THEN
         -- Get the distance from the end of the aisle to the bay.

         -- Suppress audit messages in lmd_get_bay_to_end_dist because
         -- they are output in this function.
         l_save_suppress_audit_msg_bln := pl_lma.g_suppress_audit_message_bln;
         pl_lma.g_suppress_audit_message_bln := TRUE;

         l_aisle_to_bay_dist := pl_lmd.f_get_bay_to_end_dist(l_to_aisle,
                                                             l_to_bay);

         pl_lma.g_suppress_audit_message_bln := l_save_suppress_audit_msg_bln;

      ELSE
         -- Have a unhandled value for the dock location.  Treat it as
         -- a front dock so processing can continue and write a message
         -- to aplog.
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, 
             'Have an unhandled value[' || l_dock_location ||
             '] for the dock location.  Handling it as a FRONT_DOCK.',
             NULL, NULL);

         OPEN c_aisle_to_bay_dist;
         FETCH c_aisle_to_bay_dist INTO l_aisle_to_bay_dist;

         IF (c_aisle_to_bay_dist%NOTFOUND) THEN
            CLOSE c_aisle_to_bay_dist;
            RAISE pl_exc.e_lm_bay_dist_bad_setup;
         END IF;

         CLOSE c_aisle_to_bay_dist;

      END IF;

      IF (     pl_lma.g_audit_bln
           AND pl_lma.g_suppress_audit_message_bln = FALSE) THEN
         IF (    (l_dock_location = pl_lmd.ct_front_dock)
              OR (l_dock_location = pl_lmd.ct_side_dock)) THEN
            l_message := 'Bay Distance  Start of Aisle: ' || l_to_aisle ||
                         '  To Bay: ' || l_to_bay;
         ELSIF (l_dock_location = pl_lmd.ct_back_dock) THEN
            l_message := 'Bay Distance  End of Aisle: ' || l_to_aisle ||
                         '  To Bay: ' || l_to_bay;
         ELSE
            l_message := 'Bay Distance  Start/End ?? of Aisle: ' ||
               l_to_aisle || '  To Bay: ' || l_to_bay ||
               '  Unhandled value for l_dock_location['||l_dock_location||']';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                   l_message || 'Batch#[' || pl_lma.g_batch_no || ']',
                     NULL, NULL);

            -- Write audit comment.  This will somewhat duplicate the next
            -- audit comment but we want the user to see it on the audit
            -- report at the lowest detail level.
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_1);
         END IF;

         pl_lma.audit_cmt(l_message,
                          (l_aisle_to_aisle_dist + l_aisle_to_bay_dist),
                          pl_lma.ct_detail_level_2);
      END IF; -- end audit

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name,
         'aisle to aisle dist: ' || TO_CHAR(l_aisle_to_aisle_dist) ||
         '  aisle to bay dist: ' || l_aisle_to_bay_dist, NULL, NULL);

      RETURN(l_aisle_to_aisle_dist + l_aisle_to_bay_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_bay_dist_bad_setup THEN
         l_message := l_message_param || '  TABLE=bay_distance  ACTION=SELECT'||
                      '  MESSAGE="Aisle and/or bay not setup"';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_aisle_to_bay_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_cross_aisle_dist
   --
   --  Description:
   --    This function calculates the distance between two bays using
   --    cross aisles.
   --
   --  Parameters:
   --    i_dock_num   - Dock number.
   --    i_from_aisle - Starting aisle (aisle only).  Example: DA
   --    i_from_bay   - Starting bay (bay only).  Example: 23
   --    i_to_aisle   - Ending aisle (aisle only).  Example: DE
   --    i_to_bay     - Ending bay (bay only).  Example: 48
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_aca - Problem selecting the starting
   --                                       and ending aisles.
   --    pl_exc.e_cross_aisle_sel_fail    - Problem selecting the cross aisles.
   --    User defined exception           - A called object returned an user
   --                                       defined error.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Return value:
   --    Cross aisle distance or ct_big_number if there are no cross aisles
   --    between the bays.
   --
   --
   --   Example setup of cross aisles and calculating distance
   --   from DC20B4 to DF9A1:
   --          
   --  +--------------------------------------------------+
   --  |                                                  |
   --  |      Aisle DB                                    |
   --  |   +-----------------------------|--|------+      |
   --  |                                  20              +
   --  |      Aisle DC                                    |Door     Front Dock
   --  |                      47                          +
   --  |   +-----------------+   +-----------------+      |
   --  |                      43                          +
   --  |      Aisle DD                                    |Door
   --  |                   50                             +
   --  |   +--------------+   +-----------------+         |
   --  |                   40                             +
   --  |      Aisle DE                                    |Door
   --  |                      45                          +
   --  |   +-----------------+   +-----------|--|--+      |
   --  |                      49              09            +
   --  |      Aisle DF                                    |Door
   --  |                                                  +
   --  |                       ^                          |
   --  +-----------------------|--------------------------+
   --                          |
   --                     Cross Aisle
   --
   --     Records in FORKLIFT_CROSS_AISLE table:
   --
   --      from_aisle  from_bay  to_aisle  to_bay
   --      ----------  --------  --------  ------
   --         DC         47         DD       43
   --         DD         50         DE       40
   --         DE         45         DF       49
   --
   --    The distance from DC20B4 to DF9A1 will be the sum of:
   --       - Bay to bay distance  Aisle DC  Bay 20  Bay 47
   --       - Bay to bay distance  Aisle DD  Bay 43  Bay 50
   --       - Bay to bay distance  Aisle DE  Bay 40  Bay 45
   --       - Bay to bay distance  Aisle DF  Bay 49  Bay 09
   --       - Aisle to aisle distance from aisle DC to aisle DF
   --
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/01/01 prpbcb   Created.  
   --
   --    10/01/01 prpbcb   History from PRO*C program:
   --    07/30/00 prpbcb   DN 10343
   --                      Changed the selection of the aisles use column
   --                      PHYSICAL_AISLE_ORDER in the AISLE_INFO table.
   --                      This is a new column is used to designate the
   --                      physical aisle order in a warehouse.  Before it was
   --                      expected the aisles to be physically ordered by the
   --                      aisle name which is not always the case which would
   --                      result in incorrect distances.
   --
   ---------------------------------------------------------------------------
   FUNCTION f_get_cross_aisle_dist
                            (i_dock_num IN  point_distance.point_dock%TYPE,
                             i_from_aisle   IN bay_distance.aisle%TYPE,
                             i_from_bay     IN bay_distance.bay%TYPE,
                             i_to_aisle     IN bay_distance.aisle%TYPE,
                             i_to_bay       IN bay_distance.bay%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_cross_aisle_dist';

      l_cross_aisle_dist  NUMBER := 0;  -- Distance using cross aisles
      l_done_bln          BOOLEAN;      -- while loop flag
      l_bay_to_bay_dist   NUMBER;
      l_total_aisle_aisle_dist   NUMBER := 0;  -- Running sum of the aisle to
                                               -- aisle distances.
      l_aisle_to_aisle_dist   NUMBER;        -- Distance between aisles
      l_buf               VARCHAR2(512);     -- Work area
      l_cross_aisle_found_bln BOOLEAN;       -- Flag indicating if cross
                                             -- aisle found between aisles.
      l_first_fetch_bln    BOOLEAN;          -- Flag indicating if first fetch
      l_from_aisle         bay_distance.aisle%TYPE;
      l_from_bay           bay_distance.bay%TYPE;
      l_from_cross_aisle   forklift_cross_aisle.from_aisle%TYPE;
      l_from_cross_bay     forklift_cross_aisle.from_bay%TYPE;
      l_hold               BINARY_INTEGER := 0;  -- Work area
      l_previous_to_aisle  forklift_cross_aisle.from_aisle%TYPE; -- Previous "to" aisle
      l_previous_to_bay    forklift_cross_aisle.from_bay%TYPE;   -- Previous "to" bay
      l_to_aisle           bay_distance.aisle%TYPE;
      l_to_bay             bay_distance.bay%TYPE;
      l_to_cross_aisle     forklift_cross_aisle.to_aisle%TYPE;
      l_to_cross_bay       forklift_cross_aisle.to_bay%TYPE;
      l_use_aisle_name     VARCHAR2(1);  -- Designates if to use the aisle name
                                         -- or aisle_info.physical_aisle_order
                                         -- when finding the aisles between the
                                         -- from aisle and the to aisles.

      -- Variables used in ordering records
      l_from_seq          NUMBER := 0;
      l_to_seq            NUMBER := 0;

      -- This cursor selects the aisles between the "from" and
      -- "to" aisles.
      CURSOR c_aisle IS
         SELECT pd.point_a, pd.point_b, NVL(point_dist, 0) point_dist
           FROM point_distance pd, aisle_info ai1, aisle_info ai2
          WHERE pd.point_type = 'AA'
            AND pd.point_dock = i_dock_num
            AND pd.point_a    = ai1.name
            AND pd.point_b    = ai2.name
            AND DECODE(l_use_aisle_name,
            'Y', (ASCII(SUBSTR(pd.point_a,1,1))*100) + ASCII(SUBSTR(pd.point_a,2,1)),
            ai1.physical_aisle_order)
                   BETWEEN l_from_seq AND l_to_seq
                AND DECODE(l_use_aisle_name,
            'Y', (ASCII(SUBSTR(pd.point_b,1,1))*100) + ASCII(SUBSTR(pd.point_b,2,1)),
            ai2.physical_aisle_order)
                   BETWEEN l_from_seq AND l_to_seq
        ORDER BY ai1.physical_aisle_order, pd.point_a;

      -- This cursor selects the cross bays between two aisles.
      -- The records entered in the forklift_cross_aisle table should
      -- have the "from" aisle and the "to" aisle for a record in ascending
      -- order but this cursor will handle them if they are in descending order.
      -- Example:
      --    Ascending:  
      --      from_aisle  from_bay  to_aisle  to_bay
      --      ----------  --------  --------  ------
      --         DC         47         DD       43
      --         DD         50         DE       40
      --         DE         45         DF       49
      --
      --     Descending:  
      --      from_aisle  from_bay  to_aisle  to_bay
      --      ----------  --------  --------  ------
      --         DF         49         DE       45
      --         DE         40         DD       50
      --         DD         43         DC       47
      --
      CURSOR c_cross_aisle IS
         SELECT from_bay, to_bay
           FROM forklift_cross_aisle
          WHERE from_aisle = l_from_cross_aisle
            AND to_aisle   = l_to_cross_aisle
         UNION
         SELECT to_bay, from_bay
           FROM forklift_cross_aisle
          WHERE from_aisle = l_to_cross_aisle
            AND to_aisle   = l_from_cross_aisle;

      -- This cursor selects the physical aisle order for an aisle.  Note that
      -- the value can be null.
      CURSOR c_physical_aisle_order(cp_aisle VARCHAR2) IS
         SELECT physical_aisle_order
           FROM aisle_info
          WHERE name = cp_aisle;

   BEGIN
      l_message_param := l_object_name || '(' || i_dock_num || ',' ||
         i_from_aisle || ',' || i_from_bay || ',' || i_to_aisle || ',' ||
         i_to_bay || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                          pl_lma.ct_detail_level_2);

         l_message := 'Calculate cross aisle distance.  Dock: ' || i_dock_num ||
            '  From Aisle: ' || i_from_aisle || '  From Bay: ' || i_from_bay ||
            '  To Aisle: ' || i_to_aisle || '  To Bay: ' || i_to_bay;

         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      -- Determine the values to use in selecting the aisles between the
      -- "from" aisle and the "to" aisle.
      BEGIN
         OPEN c_physical_aisle_order(i_from_aisle);
         FETCH c_physical_aisle_order INTO l_from_seq;
         CLOSE c_physical_aisle_order;

         OPEN c_physical_aisle_order(i_to_aisle);
         FETCH c_physical_aisle_order INTO l_to_seq;
         CLOSE c_physical_aisle_order;

         IF (l_from_seq IS NULL OR l_to_seq IS NULL) THEN
            l_from_seq := (ASCII(SUBSTR(i_from_aisle,1,1)) * 100) +
                                    ASCII(SUBSTR(i_from_aisle,2,1));
            l_to_seq := (ASCII(SUBSTR(i_to_aisle,1,1)) * 100) +
                                  ASCII(SUBSTR(i_to_aisle,2,1));
            l_use_aisle_name := 'Y';
         ELSE
            l_use_aisle_name := 'N';
         END IF;

         -- We need the "from" aisle sequence to be less than the "to" aisle
         -- sequence.
         IF (l_from_seq > l_to_seq) THEN
            l_hold := l_to_seq;
            l_to_seq := l_from_seq;
            l_from_seq := l_hold;
            l_from_aisle := i_to_aisle;
            l_from_bay := i_to_bay;
            l_to_aisle := i_from_aisle;
            l_to_bay := i_from_bay;
         ELSE
            l_from_aisle := i_from_aisle;
            l_from_bay := i_from_bay;
            l_to_aisle := i_to_aisle;
            l_to_bay := i_to_bay;
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            l_message := l_object_name || '  TABLE=aisle_info' ||
                '  i_dock_aisle=' || i_dock_num ||
                '  i_from_aisle=' || i_from_aisle ||
                '  i_to_aisle='   || i_to_aisle ||
                '  ACTION=SELECT'||
                '  MESSAGE="Failed to get the physical aisle order"';
            RAISE pl_exc.e_lm_pt_dist_badsetup_aca;
      END;

      -- Loop through the aisle between the "from" and "to" aisles and
      -- find the cross aisle distance between the aisles if it exists.
      BEGIN
         l_done_bln := FALSE;
         l_first_fetch_bln := TRUE;
         l_cross_aisle_found_bln := FALSE;

         OPEN c_aisle;

         LOOP
            EXIT WHEN l_done_bln = TRUE;
            FETCH c_aisle INTO l_from_cross_aisle, l_to_cross_aisle,
                               l_aisle_to_aisle_dist;
            EXIT WHEN c_aisle%NOTFOUND;

            IF (pl_lma.g_audit_bln) THEN
               l_message := 'Aisle to Aisle Distance  Dock: ' || i_dock_num ||
                  '  From Aisle: ' || l_from_cross_aisle ||
                  '  To Aisle: ' || l_to_cross_aisle;

               pl_lma.audit_cmt(l_message, l_aisle_to_aisle_dist,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit

            BEGIN
               OPEN c_cross_aisle;
               FETCH c_cross_aisle INTO l_from_cross_bay, l_to_cross_bay;

               IF (c_cross_aisle%NOTFOUND) THEN
                  -- Did not find a cross aisle which is OK.
                  CLOSE c_cross_aisle;
                  l_cross_aisle_found_bln := FALSE;
                  l_done_bln := TRUE;
               ELSE
                  -- Found a cross aisle.  Get the bay to bay distance.
                  CLOSE c_cross_aisle;
                  l_cross_aisle_found_bln := TRUE;

                  IF (l_first_fetch_bln) THEN
                     -- Get the distance from the starting bay to the cross
                     -- bay on the starting aisle.
                     l_first_fetch_bln := FALSE;
                     l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                          (l_from_cross_aisle, l_from_bay,
                                           l_from_cross_bay);
                  ELSE
                     -- Get the distance between the cross aisle bays
                     -- on the aisle.

                     -- Check that current record "from" aisle is the same
                     -- as the previous record "to" aisle.  If not then
                     -- we are done processing as there is not a continuous
                     -- cross aisle between the source and destination
                     -- aisles or the aisle setup could be incorrect.
                     IF (l_previous_to_aisle != l_from_cross_aisle) THEN
                        CLOSE c_cross_aisle;
                        l_cross_aisle_found_bln := FALSE;
                        l_done_bln := TRUE;

                        l_buf := 'The previous aisle record "to" aisle[' ||
                           l_previous_to_aisle || '] is not the same as' ||
                           ' the current aisle record "from" aisle[ ' ||
                           l_from_cross_aisle || '].  Causes could be' ||
                           ' incorrect aisle to aisle distance setup' ||
                           ' or the aisle_info.physical_aisle_order has not' ||
                           ' been entered.';

                        l_message := l_message_param || ' ' || l_buf;
                        pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                                       l_message, NULL, NULL);
                     ELSE
                        l_bay_to_bay_dist :=
                                    pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                       (l_from_cross_aisle, l_previous_to_bay,
                                        l_from_cross_bay);
                     END IF;

                  END IF;

                  l_previous_to_aisle := l_to_cross_aisle;
                  l_previous_to_bay := l_to_cross_bay;

                  l_cross_aisle_dist := l_cross_aisle_dist + l_bay_to_bay_dist;
                  l_total_aisle_aisle_dist := l_total_aisle_aisle_dist +
                                                      l_aisle_to_aisle_dist;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  -- Got an oracle error processing the cross aisles.
                  l_message := l_object_name ||
                         '  TABLE=forklift_cross_aisle' ||
                         '  i_dock_aisle=' || i_dock_num ||
                         '  i_from_aisle=' || i_from_aisle ||
                         '  i_to_aisle='   || i_to_aisle ||
                         '  ACTION=SELECT'||
                         '  MESSAGE="Error processing the cross aisles."';
                  RAISE pl_exc.e_cross_aisle_sel_fail;

            END;  -- end processing the cross aisles

         END LOOP;

         CLOSE c_aisle;

      EXCEPTION
         WHEN pl_exc.e_cross_aisle_sel_fail THEN
            RAISE;
         WHEN OTHERS THEN
            l_message := l_object_name || '  TABLE=aisle_info' ||
                '  i_dock_aisle=' || i_dock_num ||
                '  i_from_aisle=' || i_from_aisle ||
                '  i_to_aisle='   || i_to_aisle ||
                '  ACTION=SELECT'||
                '  MESSAGE="Unable to find aisles for cross aisle processing"';
            RAISE pl_exc.e_lm_pt_dist_badsetup_aca;

      END;  -- end fetching the aisles

      -- If cross aisles have been found upto the destination aisle then get
      -- the distance from the destination aisle cross bay to the destination
      -- bay.
      IF (l_cross_aisle_found_bln) THEN
         IF (l_to_aisle = l_to_cross_aisle) THEN
            -- Found cross aisles up to the destination aisle.
            l_cross_aisle_dist := l_cross_aisle_dist + l_total_aisle_aisle_dist;

            l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                          (l_to_cross_aisle, l_previous_to_bay, l_to_bay);

            l_cross_aisle_dist := l_cross_aisle_dist + l_bay_to_bay_dist;
         ELSE
            -- The last aisle processed was not the destination aisle.
            -- Causes could be incorrect aisle to aisle distance setup or
            -- the aisle_info.physical_aisle_order has not been entered.
            -- This is not a fatal error.  Write an aplog message
            -- and set the cross aisle distance to a large value that will
            -- effectively cause the distance not to be used.
            l_buf := 'The last aisle processed was not the destination aisle.'||
               '  Causes could be incorrect aisle to aisle distance setup' ||
               ' or the aisle_info.physical_aisle_order has not been entered.';

            l_message := l_object_name || '  i_dock_num=' || i_dock_num ||
               '  i_from_aisle=' || i_from_aisle ||
               '  i_to_aisle=' || i_to_aisle ||
               '  l_from_aisle=' || l_from_aisle ||
               '  l_to_aisle=(destination aisle)' || l_to_aisle ||
               '  l_to_cross_aisle(last aisle processed)=' || l_to_cross_aisle||
               '  REASON="' || l_buf ||'"';
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message, NULL,
                           NULL);

            l_cross_aisle_dist := ct_big_number;

            IF (pl_lma.g_audit_bln) THEN
               l_message := 'The last aisle processed[' || l_to_cross_aisle ||
                 '] was not the destination aisle[' || l_to_aisle || '].' ||
                 '  Causes could be incorrect aisle to aisle distance setup' ||
                 ' or the aisle_info.physical_aisle_order has not been' ||
                 ' entered.  Cross aisle distance ignored.';

               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit

         END IF;
      ELSE
         -- No cross aisles between the starting and ending bays
         -- or the cross aisles did not extend from the starting to
         -- the ending bay.  Set the cross aisle distance to a large
         -- value the will effectively cause the distance not to be used.
         l_cross_aisle_dist := ct_big_number;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         IF (l_cross_aisle_dist = ct_big_number) THEN
            l_message := 'There are no cross aisles.';
         ELSE
            l_message := 'The cross aisle distance is ' ||
               TO_CHAR(l_cross_aisle_dist, '999999.99') || ' feet.';
         END IF;
    
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      RETURN(l_cross_aisle_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_aca THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN pl_exc.e_cross_aisle_sel_fail THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message_param);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_cross_aisle_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_bay_dist
   --
   -- Description:
   --    This function calculates the distance between two bays on the
   --    specified dock.  If the "from" bay and the "to" bay are on the same
   --    aisle then the distance between the bays are calculated otherwise
   --    three distances are calculated with the shortest distance being used.
   --    The three distances are:
   --    - "from" bay -> start of "from aisle" -> start of "to" aisle -> "to" bay
   --    - "from" bay -> end of "from aisle" -> end of "to" aisle -> "to" bay
   --    - Cross aisle distance.
   --
   -- Parameters:
   --    i_dock_num - Specified dock number.
   --    i_from_bay - Starting bay.  Can either be a location or the aisle and
   --                 bay only (ie. from haul).
   --    i_to_bay   - Ending bay.  Can either be a location or the aisle and
   --                 bay only (ie. from haul).
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   -- 
   -- Return value:
   --    Distance between the bays.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/27/01 prpbcb   Created.  
   --
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_bay                   IN VARCHAR2,
                 i_to_bay                     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_bay_to_bay_dist';

      l_aisle_to_aisle_dist          NUMBER;
      l_bay_to_bay_dist              NUMBER;
      l_beg_bay_to_end_bay_dist      NUMBER;
      l_beg_bay_to_start_aisle_dist  NUMBER;
      l_end_bay_to_start_aisle_dist  NUMBER;
      l_beg_bay_to_end_aisle_dist    NUMBER;
      l_end_bay_to_end_aisle_dist    NUMBER;
      l_cross_aisle_dist             NUMBER;
      l_distance_used    VARCHAR2(1) := NULL;
                         -- Denotes what path is the shortest distance.
                         -- Used for the audit report.  The values are:
                         --    S - Going to the start of aisles shortest
                         --    E - Going to the end of aisles shortest
                         --    C - Cross aisle shortest

      l_from_aisle  point_distance.point_a%TYPE;
      l_from_bay    bay_distance.bay%TYPE;
      l_to_aisle    point_distance.point_a%TYPE;
      l_to_bay      bay_distance.bay%TYPE;

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
                         '(i_dock_num[' || i_dock_num || ']' ||
                         ',i_from_bay[' || i_from_bay || ']' ||
                         ',i_to_bay[' || i_to_bay || ']' ||
                         ',i_follow_aisle_direction[' || l_message || '])';
  
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Extract the aisles and bays from the parameters.
      l_from_aisle := SUBSTR(i_from_bay, 1, 2);
      l_from_bay := SUBSTR(i_from_bay, 3, 2);
      l_to_aisle := SUBSTR(i_to_bay, 1, 2);
      l_to_bay := SUBSTR(i_to_bay, 3, 2);

      pl_lma.g_suppress_audit_message_bln := FALSE;   -- Used in forklift audit.

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Calculate bay to bay distance.  Dock: ' || i_dock_num ||
            '  From Bay: ' || l_from_aisle || l_from_bay || '  To Bay: ' ||
            l_to_aisle || l_to_bay;

         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      -- Initialize distances.
      l_cross_aisle_dist := ct_big_number;

      IF (l_from_aisle = l_to_aisle) THEN
         -- The "from" bay and the "to" bay are on the same aisle.

         IF (pl_lma.g_audit_bln) THEN
            l_message := 'Bay ' || l_from_aisle || l_from_bay || ' and bay ' ||
               l_to_aisle || l_to_bay || ' are on the same aisle.' ||
               '  Calculate the distance between the bays.';

            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         END IF;  -- end audit

        l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                                 (l_from_aisle, l_from_bay,
                                                  l_to_bay);
      ELSE
         --  The "from" and "to" bays are on different aisles.
         IF (pl_lma.g_audit_bln) THEN
            l_message := 'Calculate the following distances and use the' ||
                         ' shortest distance:';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

            l_message := '- Bay ' || l_from_bay || ' -> start of aisle ' ||
               l_from_aisle || ' -> start of aisle ' || l_to_aisle ||
               ' -> bay ' || l_to_bay;
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

            l_message := '- Bay ' || l_from_bay || ' -> end of aisle ' ||
               l_from_aisle || ' -> end of aisle ' || l_to_aisle ||
               ' -> bay ' || l_to_bay;
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
            pl_lma.audit_cmt('- Distance using cross aisles', pl_lma.ct_na,
                             pl_lma.ct_detail_level_2);
         END IF;  -- end audit

         --  Suppress the forklift audit messages in the called functions.
         --  The audit messages are output by this function.
         pl_lma.g_suppress_audit_message_bln := TRUE; 

         -- Get the distance from the "from" bay to the start of the
         -- "from" aisle.
         l_beg_bay_to_start_aisle_dist := pl_lmd.f_get_aisle_to_bay_dist
                                (i_dock_num, l_from_aisle, i_from_bay);

         -- Get the distance from the "to" bay to the start of the "to" aisle.
         l_end_bay_to_start_aisle_dist := pl_lmd.f_get_aisle_to_bay_dist
                                        (i_dock_num, l_to_aisle, i_to_bay);

         -- Get the distance from the "from" bay to the end of the "from" aisle.
         l_beg_bay_to_end_aisle_dist := pl_lmd.f_get_bay_to_end_dist
                                           (l_from_aisle, l_from_bay);

         -- Get the distance from the "to" bay to the end of the "to" aisle.
         l_end_bay_to_end_aisle_dist := pl_lmd.f_get_bay_to_end_dist(l_to_aisle,
                                                                   l_to_bay);

         -- Get the distance from the "from" aisle to the "to" aisle.
         l_aisle_to_aisle_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dock_num,
                                               l_from_aisle, l_to_aisle);

         pl_lma.g_suppress_audit_message_bln := FALSE;

         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                             pl_lma.ct_detail_level_1);

            l_message := 'Calculate distance from bay ' || l_from_bay ||
               ' -> start of aisle ' || l_from_aisle || ' -> start of aisle ' ||
               l_to_aisle || ' -> bay ' || l_to_bay || '.';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

            l_message := 'Bay Distance  Start of Aisle: ' || l_from_aisle ||
               '  To Bay: ' || l_from_bay;
            pl_lma.audit_cmt(l_message, l_beg_bay_to_start_aisle_dist,
                             pl_lma.ct_detail_level_2);

            l_message := 'Aisle to Aisle Distance  From Aisle: ' ||
               l_from_aisle || '  To Aisle: ' || l_to_aisle;
            pl_lma.audit_cmt(l_message, l_aisle_to_aisle_dist,
                             pl_lma.ct_detail_level_2);

            l_message := 'Bay Distance  Start of Aisle: ' || l_to_aisle ||
               '  To Bay: ' || l_to_bay;
            pl_lma.audit_cmt(l_message, l_end_bay_to_start_aisle_dist,
                             pl_lma.ct_detail_level_2);

            pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                             pl_lma.ct_detail_level_2);

            l_message := 'Calculate distance from bay ' || l_from_bay ||
               ' -> end of aisle ' || l_from_aisle || ' -> end of aisle ' ||
               l_to_aisle || ' -> bay ' || l_to_bay;
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

            l_message := 'Bay Distance  End of Aisle: ' || l_from_aisle ||
               '  To Bay: ' || l_from_bay;
            pl_lma.audit_cmt(l_message, l_beg_bay_to_end_aisle_dist,
                             pl_lma.ct_detail_level_2);

            l_message := 'Aisle to Aisle Distance  From Aisle: ' ||
               l_from_aisle || '  To Aisle: ' || l_to_aisle;
            pl_lma.audit_cmt(l_message, l_aisle_to_aisle_dist,
                             pl_lma.ct_detail_level_2);

            l_message := 'Bay Distance  End of Aisle: ' || l_to_aisle ||
               '  To Bay: ' || l_to_bay;
            pl_lma.audit_cmt(l_message, l_end_bay_to_end_aisle_dist,
                             pl_lma.ct_detail_level_2);
         END IF;  -- end audit

         -- Get distance from the "from" bay to the "to" bay using cross aisles.
         l_cross_aisle_dist := pl_lmd.f_get_cross_aisle_dist(i_dock_num,
                                       l_from_aisle, l_from_bay, l_to_aisle,
                                       l_to_bay);

         -- Use the shortest path between the "from" bay to the "to" bay.

         IF ((l_beg_bay_to_start_aisle_dist + l_end_bay_to_start_aisle_dist) >
             (l_beg_bay_to_end_aisle_dist + l_end_bay_to_end_aisle_dist)) THEN
            l_bay_to_bay_dist := l_beg_bay_to_end_aisle_dist +
                                 l_end_bay_to_end_aisle_dist +
                                 l_aisle_to_aisle_dist;
            l_distance_used := 'E';
         ELSE
            l_bay_to_bay_dist := l_beg_bay_to_start_aisle_dist +
                                 l_end_bay_to_start_aisle_dist +
                                 l_aisle_to_aisle_dist;
            l_distance_used := 'S';
         END IF;

         IF (l_bay_to_bay_dist > l_cross_aisle_dist) THEN
            -- Using the cross aisle(s) is the shortest path.
            l_bay_to_bay_dist := l_cross_aisle_dist;
            l_distance_used := 'C';
         END IF;

         IF (pl_lma.g_audit_bln) THEN
            IF (l_distance_used = 'S') THEN
               l_message := 'Going to start of aisles is the shortest path.  '||
                  TO_CHAR(l_bay_to_bay_dist, '99999.99') || ' feet.';
            ELSIF (l_distance_used = 'E') THEN
               l_message := 'Going to end of aisles is the shortest path.  ' ||
                  TO_CHAR(l_bay_to_bay_dist, '99999.99') || ' feet.';
            ELSIF (l_distance_used = 'C') THEN
               l_message := 'The cross aisles is the shortest path.  ' ||
                  TO_CHAR(l_bay_to_bay_dist, '99999.99') || ' feet.';
            ELSE
               l_message := 'Have unhandled distance used indicator <' ||
                  l_distance_used || '>.  Call in a ticket.';
            END IF;

            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         END IF;  -- end audit

      END IF;

      RETURN(l_bay_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_bay_to_bay_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_bay_on_aisle_dist
   --
   -- Description:
   --    This function finds the distance between two bays on the specified
   --    aisle.
   --
   -- Parameters:
   --    i_aisle     - Aisle.  Examples:  CA, DE
   --    i_from_bay  - Starting bay.  Bay id only.  Examples: 01, 23
   --    i_to_bay    - Ending bay.  Bay id only.  Examples: 01, 23
   --  Note: Leading zeros are required for the bay.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_bay_dist_bad_setup  Bay(s) not found. 
   --    pl_exc.e_database_error         Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/18/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_bay_on_aisle_dist
                          (i_aisle    IN bay_distance.aisle%TYPE,
                           i_from_bay IN bay_distance.bay%TYPE,
                           i_to_bay   IN bay_distance.bay%TYPE)
   RETURN NUMBER IS
      l_message          VARCHAR2(256);  -- Message buffer
      l_message_param    VARCHAR2(256);  -- Message buffer
      l_object_name      VARCHAR2(61) := gl_pkg_name ||
                                         '.f_get_bay_to_bay_on_aisle_dist';

      l_bay_to_bay_dist  NUMBER;         -- Bay to bay distance

      -- This cursor calculates the distance between two bays on the same
      -- aisle.
      CURSOR c_bay_dist IS
         SELECT ABS(bd.bay_dist - bd1.bay_dist)
           FROM bay_distance bd1, bay_distance bd
          WHERE bd1.aisle = bd.aisle
            AND bd1.bay   = i_to_bay
            AND bd.bay    = i_from_bay
            AND bd.aisle  = i_aisle;

   BEGIN

      l_message_param := l_object_name || ' i_aisle[' || i_aisle || ']' ||
                   ' i_from_bay[' || i_from_bay || ']' ||
                   ' i_to_bay[' || i_to_bay || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_bay_dist;
      FETCH c_bay_dist INTO l_bay_to_bay_dist;
    
      IF (c_bay_dist%NOTFOUND) THEN
         CLOSE c_bay_dist;
         RAISE pl_exc.e_lm_bay_dist_bad_setup;
      END IF;

      CLOSE c_bay_dist;

      RETURN l_bay_to_bay_dist;

   EXCEPTION
      WHEN pl_exc.e_lm_bay_dist_bad_setup THEN
         l_message := l_message_param || '  TABLE=bay_distance' ||
            '  ACTION=SELECT  MESSAGE="Bay(s) not found."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_bay_to_bay_on_aisle_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_bay_to_end_dist
   --
   -- Description:
   --    This function finds the distance between the specified bay and the
   --    end cap of the specified aisle.
   --
   --  Parameters:
   --    i_aisle     - Aisle.  Examples:  CA, DE
   --    i_bay       - Bay.  Bay id only.  Examples: 01, 23
   --  Note: Leading zeros are required for the bay.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_bay_dist_bad_setup - Bay and/or end of aisle not found. 
   --    pl_exc.e_database_error        - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/28/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_bay_to_end_dist (i_aisle  IN bay_distance.aisle%TYPE,
                                   i_bay    IN bay_distance.bay%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);  -- Message buffer
      l_message_param  VARCHAR2(256);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_bay_to_end_dist';

      l_bay_to_end_dist  NUMBER;         -- Bay to end distance

   -- This cursor calculates the distance from the bay to the end of the aisle.
   CURSOR c_bay_to_end_dist IS
      SELECT ABS(b.bay_dist - bd.bay_dist)
        FROM bay_distance bd, bay_distance b
       WHERE bd.bay = 'END'
         AND bd.aisle = b.aisle
         AND b.aisle = i_aisle
         AND b.bay = i_bay;
   BEGIN
      l_message_param := l_object_name || ' i_aisle[' || i_aisle || ']' ||
                         ' i_bay[' || i_bay || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_bay_to_end_dist;

      FETCH c_bay_to_end_dist INTO l_bay_to_end_dist;

      IF (c_bay_to_end_dist%NOTFOUND) THEN
         CLOSE c_bay_to_end_dist;
         RAISE pl_exc.e_lm_bay_dist_bad_setup;
      END IF;
      
      CLOSE c_bay_to_end_dist;

      IF (     pl_lma.g_audit_bln
           AND pl_lma.g_suppress_audit_message_bln = FALSE) THEN
         l_message := 'Bay to end of aisle distance.  Aisle: ' || i_aisle ||
                      '  Bay: ' || i_bay;
         pl_lma.audit_cmt(l_message, l_bay_to_end_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name,
                     'bay to end distance: ' || TO_CHAR(l_bay_to_end_dist),
                     NULL, NULL);

      RETURN l_bay_to_end_dist;

   EXCEPTION
      WHEN pl_exc.e_lm_bay_dist_bad_setup THEN
         l_message := l_message_param || '  TABLE=bay_distance' ||
            '  ACTION=SELECT  MESSAGE="Bay to END distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_bay_to_end_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and aisle
   --    on the specified dock.
   --
   --  Parameters:
   --     i_dock_num  - Specified dock.  This needs to be the door dock number.
   --     i_from_door - Specified door.  Example: D102
   --     i_to_aisle  - Specified aisle.  Example: DA
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_dta   Door to aisle distance not found.
   --    pl_exc.e_database_error            Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/28/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_aisle_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_aisle   IN point_distance.point_b%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                '.f_get_door_to_aisle_dist';

      l_door_to_aisle_dist  NUMBER;           -- Door to aisle distance

      -- This cursor selects the door to aisle distance.
      CURSOR c_door_to_aisle_dist IS
         SELECT point_dist
           FROM point_distance
          WHERE point_dock = i_dock_num 
            AND point_type = 'DA'
            AND point_a = i_from_door
            AND point_b = i_to_aisle;
   BEGIN
      l_message_param := l_object_name || ' i_dock_num[' || i_dock_num || ']' ||
                         ' i_from_door[' || i_from_door || ']' ||
                         ' i_to_aisle[' || i_to_aisle || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_door_to_aisle_dist;
      FETCH c_door_to_aisle_dist INTO l_door_to_aisle_dist;

      IF (c_door_to_aisle_dist%NOTFOUND) THEN
         CLOSE c_door_to_aisle_dist;
         RAISE pl_exc.e_lm_pt_dist_badsetup_dta;
      END IF;

      CLOSE c_door_to_aisle_dist;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Door to Aisle Distance  Dock: ' || i_dock_num ||
            '  From Door: ' || i_from_door || '  To Aisle: ' || i_to_aisle;
         pl_lma.audit_cmt(l_message, l_door_to_aisle_dist,
                          pl_lma.ct_detail_level_2);   
      END IF;  -- end audit
   
      RETURN(l_door_to_aisle_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_dta THEN
         l_message := l_message_param || '  TABLE=point_distance' || 
            '  ACTION=SELECT  MESSAGE="Door to aisle distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_door_to_aisle_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_pup_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and
   --    pickup point on the specified dock.
   --
   --  Parameters:
   --     i_dock_num  - Specified dock.  This needs to be the door dock number.
   --     i_from_door - Specified door.  Example: D102
   --     i_to_pup    - Specified pickup point.  Example: LBP1
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_dtp   Door to pickup point distance not
   --                                       found.
   --    pl_exc.e_database_error            Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/11/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_pup_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_pup     IN point_distance.point_b%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_door_to_pup_dist';

      l_door_to_pup_dist  NUMBER;       -- Door to pickup point distance.

      -- This cursor selects the door to pickup point distance.
      CURSOR c_door_to_pup_dist IS
         SELECT point_dist
           FROM point_distance
          WHERE point_dock = i_dock_num 
            AND point_type = 'DP'
            AND point_a = i_from_door
            AND point_b = i_to_pup;
   BEGIN

      l_message_param := l_object_name || ' i_dock_num[' || i_dock_num || ']' ||
                         ' i_from_door[' || i_from_door || ']' ||
                         ' i_to_pup[' || i_to_pup || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_door_to_pup_dist;
      FETCH c_door_to_pup_dist INTO l_door_to_pup_dist;

      IF (c_door_to_pup_dist%NOTFOUND) THEN
         CLOSE c_door_to_pup_dist;
         RAISE pl_exc.e_lm_pt_dist_badsetup_dtp;
      END IF;

      CLOSE c_door_to_pup_dist;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Door to Pickup Point Distance  Dock: ' || i_dock_num ||
            '  From Door: ' || i_from_door ||
            '  To Pickup Point: ' || i_to_pup; 
         pl_lma.audit_cmt(l_message, l_door_to_pup_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit
   
      RETURN(l_door_to_pup_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_dtp THEN
         l_message := l_message_param || '  TABLE=point_distance' || 
            '  ACTION=SELECT' ||
            '  MESSAGE="Door to pickup point distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_door_to_pup_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_bay_direct_dist
   --
   -- Description:
   --    This subroutine finds the straight line distance between the specified
   --    door and bay.
   --
   --    By knowing the following we can calculate the distance using the
   --    law of cosines.
   --       1.  Distance from the door to the bay at the start of the aisle.
   --       2.  Distance from the door to the bay at the end of the aisle.
   --       3.  Distance from the start of the aisle to the bay in 2.
   --       4.  Distance from the start of the aisle to the destination bay.
   --
   --   It is possible the door to bay distances setup are not direct line
   --   distances which will prevent the distance from being calculated by
   --   this function.  This is not an error.
   --
   --  Parameters:
   --      i_dock_num     - Specified dock number.
   --      i_from_door    - Specified door.
   --      i_to_bay       - Destination bay.  It can be the complete location or
   --                       just the aisle and bay (ie. from haul).
   --                       Examples: DA20, DA24A3
   --      i_min_bay      - Lowest bay number closest to the destination bay
   --                       that has a door to bay distance setup for
   --                       i_from_door.  It includes the aisle and bay.
   --                       Example: DA03
   --      i_max_bay      - Highest bay number closest to the destination bay
   --                       that has a door to bay distance setup for
   --                       i_from_door.  It includes the aisle and bay.
   --                       Example: DA57
   --      i_min_bay_dist - Distance from i_from_door to i_min_bay.
   --      i_max_bay_dist - Distance from i_from_door to i_max_bay.
   --
   --      i_to_bay, i_min_bay and i_max_bay must be on the same aisle.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Sample calculation of distance:
   --
   --          Steps in calculating the distance
   --          from door D381 to bay DB37
   --
   --     1.  Distances from door D381 to bay DB01 and door D381 to bay DB99
   --         are setup as door to bay distances.
   --     2.  Get the distance from bay DB01 to bay DB99 using the
   --         BAY_DISTANCE table.
   --     3.  The angle beta between D381->DB01 and DB01->DB99 is calculated.
   --     4.  Get the distance from bay DB01 to bay DB37 using the
   --         BAY_DISTANCE table.
   --     5.  Calculate distance from D381 to DB37 using:
   --            - Distance from door D381 to bay DB01
   --            - Distance from bay DB01 to bay DB37
   --            - Angle beta
   --
   --          Door         Door         Door
   --          D380         D381         D382
   --  +------+====+-------+=====+------+====+------------+
   --  |                      *                           |
   --  |                   *   *  *                       |
   --  |                *       *     *                   |
   --  |             *           *        *               |
   --  |          *               *           *           |
   --  |       *                   *       beta   *     <--- Aisle DB
   --  |    +---------------------------------------+     |
   --  |    |99|                  |37|           |01|     |
   --  |    +---------------------------------------+     |
   --  |    |                                       |     |
   --  |    +---------------------------------------+     |
   --  |                                                  |
   --  |                                                  |
   --  +--------------------------------------------------+
   --
   --
   --   Following is a situation where the direct line distance cannot be
   --   calculated:
   --
   --   D380 -> DA01 is setup as a door to bay distance.
   --   D380 -> DA97 is setup as a door to bay distance.
   --
   --   The direct line distance from D380 to DA11 cannot be calculated
   --   using D380->DA01 and D380->DA97 because the distance from D380 to DA97
   --   is not a direct line distance.  It this case the distance from D380
   --   to DA11 will be D380->DA01->DA11.
   --
   --          Door         Door         Door
   --          D380         D381         D382
   --  +------+====+-------+=====+------+====+---------------------------+
   --  |                                                                 |
   --  |                                               DA DB DC DD       |
   --  |                                                 +  +  +  +      |
   --  |                                               01|  |  |  |      |
   --  |                                                 |  |  |  |      |
   --  |                  DS                             |  |  |  |      |
   --  |    +------------------------------------+       |  |  |  |      |
   --  |                  DR                             |  |  |  |      |
   --  |    +------------------------------------+     11|  |  |  |      |
   --  |                  DP                             |  |  |  |      |
   --  |    +------------------------------------+       |  |  |  |      |
   --  |                  DN                             |  |  |  |      |
   --  |    +------------------------------------+       |  |  |  |      |
   --  |                  DM                             |  |  |  |      |
   --  |    +------------------------------------+     97|  |  |  |      |
   --  |                  DL                             +  +  +  +      |
   --  |                                                                 |
   --  |                                                                 |
   --  +-----------------------------------------------------------------+
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/28/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_bay_direct_dist
                          (i_dock_num      IN point_distance.point_dock%TYPE,
                           i_from_door     IN point_distance.point_a%TYPE,
                           i_to_bay        IN VARCHAR2,
                           i_min_bay       IN VARCHAR2,
                           i_max_bay       IN VARCHAR2,
                           i_min_bay_dist  IN NUMBER,
                           i_max_bay_dist  IN NUMBER)
   RETURN NUMBER IS
      l_message          VARCHAR2(256);    -- Message buffer
      l_message_param    VARCHAR2(256);    -- Message buffer
      l_object_name      VARCHAR2(61) := gl_pkg_name ||
                                              '.f_get_door_to_bay_direct_dist';

      l_angle            NUMBER := 0;
      l_bay_to_bay_dist  NUMBER;
      l_door_to_bay_dist NUMBER;                 -- Door to bay distance
      l_min_bay_id_only  bay_distance.bay%TYPE;  -- Only the bay of the min bay
      l_max_bay_id_only  bay_distance.bay%TYPE;  -- Only the bay of the max bay
      l_to_aisle         bay_distance.aisle%TYPE;-- Aisle of the "to" bay
      l_to_bay_id_only   bay_distance.bay%TYPE;  -- Only the bay of the "to" bay
   BEGIN

      l_message_param := l_object_name || '(' || i_dock_num || ',' ||
         i_from_door || ',' || i_to_bay || ',' || i_min_bay || ',' ||
         i_max_bay || ',' || TO_CHAR(i_min_bay_dist) || ',' ||
         TO_CHAR(i_max_bay_dist) || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialize the distance to a large number so that if there is a
      -- problem calculating the distance the calling function will not
      -- use the value.
      l_door_to_bay_dist := ct_big_number;

      -- Extract out the aisle and the bay from the parameters.  Function
      -- lmd_get_bay_to_bay_on_aisle_dist which is called to get bay to bay
      -- distances wants the aisle parameter to have only the aisle and the
      -- bay parameters to have only the bay.
      l_to_aisle := SUBSTR(i_to_bay, 1, 2);
      l_to_bay_id_only := SUBSTR(i_to_bay, 3, 2);
      l_min_bay_id_only := SUBSTR(i_min_bay, 3, 2);
      l_max_bay_id_only := SUBSTR(i_max_bay, 3, 2);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Calculate the distance from door ' || i_from_door ||
            ' directly to bay ' || l_to_aisle || l_to_bay_id_only ||
            ' using distance of ' || TO_CHAR(i_min_bay_dist) ||
            ' from the door to bay ' || i_min_bay || ' and distance of ' ||
            TO_CHAR(i_max_bay_dist) || ' from the door to bay ' ||
            i_max_bay || '.';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist(l_to_aisle,
                                 l_min_bay_id_only, l_max_bay_id_only);

      -- Calculate the angle.
      -- If the angle is -1 then there was a problem in calculating
      -- the angle.  The most likely situation is that the distances
      -- to the door to the bays are not direct line distances which
      -- results in the inability to form a triangle between the points.
      l_angle := f_get_ab_angle(i_min_bay_dist, l_bay_to_bay_dist,
                                i_max_bay_dist);
        
      IF (l_angle = -1) THEN
         NULL;
      ELSE
         -- If the destination bay is less then the min bay setup in the
         -- door to bay distances then the angle will be pi minus the
         -- angle.
         IF (l_to_bay_id_only < l_min_bay_id_only) THEN
            l_angle := ct_m_pi - l_angle;
         END IF;

         IF (l_angle != -1) THEN
            l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                                       (l_to_aisle,
                                                        l_min_bay_id_only,
                                                        l_to_bay_id_only);

            l_door_to_bay_dist := f_get_side_a_length(i_min_bay_dist,
                                                      l_bay_to_bay_dist,
                                                      l_angle);
            IF (l_door_to_bay_dist = -1) THEN
               l_door_to_bay_dist := ct_big_number;
            END IF;
           
            IF (pl_lma.g_audit_bln AND l_door_to_bay_dist != ct_big_number) THEN
               l_message := 'Distance from door ' || i_from_door ||
                  ' directly to bay ' || l_to_aisle || l_to_bay_id_only || '.';
               pl_lma.audit_cmt(l_message, l_door_to_bay_dist,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit
            
         END IF;
      END IF;

      RETURN(l_door_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_door_to_bay_direct_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_dist_using_door_bay_dist
   --
   -- Description:
   --    This function finds the shortest distance between the specified door
   --    and bay on the specified dock using door to bay point distances.
   --    This comes into play for docks that run parallel to the aisles.
   --    When door to bay distances are setup (point type DB) there should
   --    be a distance from the door to the front of the aisle and a distance
   --    from the door to the end of the aisle.
   --
   --    First the distance from the door to the bay setup as a point distance
   --    is determined then the distance from the bay to the destination bay is
   --    determined.  If the destination bay is on the aisle that has the
   --    door to bay distances setup then the distance from the door directly
   --    to the bay is calculated.
   --
   --    A door can have a distance setup to more than one bay.  At most four
   --    bays will be selected when determining the shortest distance.
   --       - The destination bay if it is setup as a door to bay distance.
   --       - The bay setup closest to the front of the aisle.  There should be
   --         a distance setup from the door to the front of the aisle.
   --       - The bay setup closest to the end of the aisle.  There should be
   --         a distance setup from the door to the end of the aisle.
   --       - The bay setup nearest the cross bay if a cross bay exists.
   --
   --    Following is a sample setup of door to bay distances in the
   --    POINT_DISTANCE table.  POINT_B must have the aisle and bay.
   --    The last sample record is the distance to the bay at the cross aisle.
   --
   --     POINT_DOCK   POINT_TYPE   POINT_A   POINT_B   POINT_DIST
   --     ----------   ----------   -------   -------   ----------
   --        D3           DB         D380      DB00        300
   --        D3           DB         D380      DB99        610
   --        D3           DB         D380      DB45        340
   --
   --                     Side Dock
   --
   --          Door         Door         Door
   --  +------+====+-------+=====+------+====+------------+
   --  |                                                  |
   --  |                    cross bay                     |
   --  |   +-----------------+ * +-----------------+      +
   --  |                                                  |Door      Front Dock
   --  |   +-----------------+   +-----------------+      +
   --  |                                                  |
   --  |   +-----------------+   +-----------------+      +
   --  |                                                  |Door
   --  |   +-----------------+   +-----------------+      +
   --  |                       ^                          |
   --  +-----------------------|--------------------------+
   --                          |
   --                     Cross Aisle
   --
   -- Parameters:
   --    i_dock_num  - Specified dock.  This needs to be the door dock number.
   --    i_from_door - Specified door.
   --    i_to_bay    - Specified bay.  Can either be a location or
   --                  only a bay (ie. from haul).  Examples: DC01, DC01A4
   --                  Note that it must include the aisle.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/24/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_dist_using_door_bay_dist 
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_door  IN point_distance.point_a%TYPE,
                           i_to_bay     IN VARCHAR2)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.f_get_dist_using_door_bay_dist';

      l_db_aislebay           VARCHAR2(10);  -- Door to bay distance bay
      l_db_min_aislebay       VARCHAR2(10);  -- Door to bay distance bay
      l_db_min_aislebay_dist  NUMBER;
      l_db_max_aislebay       VARCHAR2(10);  -- Door to bay distance bay
      l_db_max_aislebay_dist  NUMBER;
      l_dummy1       NUMBER;              -- Place to hold a fetched value
      l_dummy2       VARCHAR2(10);        -- Place to hold a fetched value
      l_dist         NUMBER := 0;         -- Door to bay distance
      l_to_aislebay  VARCHAR2(10);   -- Destination bay.  Includes aisle and
                                     -- bay.  No position or level.
      l_to_aisle           aisle_info.name%TYPE;    -- Destination aisle
      l_bay_to_bay_dist    NUMBER := 0;
      l_door_to_bay_dist   NUMBER;
      l_save_bay           VARCHAR2(10);  -- Used in audit messages.

      -- This cursor selects the two bays closest to the destination bay when
      -- the destination aisle has door to bay distances setup.
      -- If the destination bay is setup as a door to bay distance then
      -- this will be the first record selected.  No more than two records
      -- will be selected.
      --
      -- Note that only one bay will be selected if only one door to bay
      -- distance is setup.
      CURSOR  c_db_dist_same_aisle IS
         SELECT pd.point_b, NVL(pd.point_dist,0),
                DECODE(pd.point_b, l_to_aislebay, 0, 1), pd.point_b
           FROM point_distance pd
          WHERE point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a    = i_from_door
            AND SUBSTR(pd.point_b,1,2) = l_to_aisle
            AND point_b =
                 (SELECT MAX(pd2.point_b)
                    FROM point_distance pd2
                   WHERE pd2.point_type = pd.point_type
                     AND pd2.point_dock = pd.point_dock
                     AND pd2.point_a    = pd.point_a
                     AND SUBSTR(pd2.point_b,1,2)  = SUBSTR(pd.point_b,1,2)
                     AND pd2.point_b    <= l_to_aislebay)
         UNION
         SELECT pd.point_b, NVL(pd.point_dist,0),
                DECODE(pd.point_b, l_to_aislebay, 0, 1), pd.point_b
           FROM point_distance pd
          WHERE point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a    = i_from_door
            AND SUBSTR(pd.point_b,1,2) = l_to_aisle
            AND point_b =
                 (SELECT MIN(pd2.point_b)
                    FROM point_distance pd2
                   WHERE pd2.point_type = pd.point_type
                     AND pd2.point_dock = pd.point_dock
                     AND pd2.point_a    = pd.point_a
                     AND SUBSTR(pd2.point_b,1,2)  = SUBSTR(pd.point_b,1,2)
                     AND pd2.point_b    > l_to_aislebay)
          ORDER BY 3, 4;

      -- This cursor selects the door to bay distances setup for the door.
      -- The min bay, max bay and the bay nearest the cross bay (if there is
      -- a cross aisle) for each aisle defined for the door are selected.
      -- This cursor is used when the destination aisle does not have any
      -- door to bay distances.
      CURSOR  c_db_dist IS
         SELECT pd.point_b aislebay, NVL(pd.point_dist,0) dist,
                DECODE(pd.point_b, l_to_aislebay, 0, 1) dummy1,
                pd.point_b dummy2
           FROM point_distance pd
          WHERE point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a    = i_from_door
            AND point_b =
                 (SELECT MIN(pd2.point_b)
                    FROM point_distance pd2
                   WHERE pd2.point_type = pd.point_type
                     AND pd2.point_dock = pd.point_dock
                     AND pd2.point_a    = pd.point_a
                     AND SUBSTR(pd2.point_b,1,2)  = SUBSTR(pd.point_b,1,2))
         UNION
         SELECT pd.point_b aislebay, NVL(pd.point_dist,0) dist,
                DECODE(pd.point_b, l_to_aislebay, 0, 1) dummy1,
                pd.point_b dummy2
           FROM point_distance pd
          WHERE point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a    = i_from_door
            AND point_b =
                 (SELECT MAX(pd2.point_b)
                    FROM point_distance pd2
                   WHERE pd2.point_type = pd.point_type
                     AND pd2.point_dock = pd.point_dock
                     AND pd2.point_a    = pd.point_a
                     AND SUBSTR(pd2.point_b,1,2)  = SUBSTR(pd.point_b,1,2))
         UNION
         SELECT pd.point_b aislebay, NVL(pd.point_dist,0) dist,
                DECODE(pd.point_b, l_to_aislebay, 0,
                                   1) dummy1,
                pd.point_b dummy2
           FROM forklift_cross_aisle ca, point_distance pd
          WHERE pd.point_type = 'DB'
            AND pd.point_dock = i_dock_num
            AND pd.point_a    = i_from_door
            AND ca.from_aisle = SUBSTR(pd.point_b,1,2)
            AND ABS(ca.from_bay - SUBSTR(pd.point_b,3,2)) =
                (SELECT MIN(ABS(ca2.from_bay - SUBSTR(pd2.point_b,3,2)))
                   FROM forklift_cross_aisle ca2, point_distance pd2
                  WHERE pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a    = pd.point_a
                    AND ca2.from_aisle = SUBSTR(pd2.point_b,1,2))
         UNION
         SELECT pd.point_b aislebay, NVL(point_dist,0) dist,
                DECODE(pd.point_b, l_to_aislebay, 0,
                                   1) dummy1,
                pd.point_b dummy2
          FROM forklift_cross_aisle ca, point_distance pd
         WHERE pd.point_type = 'DB'
           AND pd.point_dock = i_dock_num
           AND pd.point_a    = i_from_door
           AND ca.to_aisle = SUBSTR(pd.point_b,1,2)
           AND ABS(ca.to_bay - SUBSTR(pd.point_b,3,2)) =
               (SELECT MIN(ABS(ca2.to_bay - SUBSTR(pd2.point_b,3,2)))
                  FROM forklift_cross_aisle ca2, point_distance pd2
                 WHERE pd2.point_type = pd.point_type
                   AND pd2.point_dock = pd.point_dock
                   AND pd2.point_a    = pd.point_a
                   AND ca2.to_aisle = SUBSTR(pd2.point_b,1,2))
          ORDER BY 3, 4;
   BEGIN
      l_message_param := l_object_name || '(' || i_dock_num || ',' ||
                         i_from_door || ',' || i_to_bay || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialize the distances to ct_big_number.  This is used to designate 
      -- if a distance was found or not.  Calling functions check for
      -- ct_big_number.  Another way it could have been done is using boolean
      -- variables.
      l_door_to_bay_dist := ct_big_number;
      l_db_min_aislebay_dist := ct_big_number;
      l_db_max_aislebay_dist := ct_big_number;

      -- Extract out the aisle and the aislebay from i_to_bay.
      l_to_aisle := SUBSTR(i_to_bay, 1, 2);
      l_to_aislebay := SUBSTR(i_to_bay, 1,4);

      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                          pl_lma.ct_detail_level_2);
         l_message := 'Calculate door to bay distance using door to bay' ||
           ' point distances.  Dock: ' || i_dock_num ||
           '  Door: ' || i_from_door || '  Bay: ' || l_to_aislebay;
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit
 
      OPEN c_db_dist_same_aisle;

       -- Fetch the min bay closest to the destination bay if it exists.
       FETCH c_db_dist_same_aisle
              INTO l_db_min_aislebay,
                   l_db_min_aislebay_dist,
                   l_dummy1, l_dummy2;

      IF (c_db_dist_same_aisle%NOTFOUND) THEN
         -- Did not find the min bay closest to the destination bay
         -- which also means there are no door to bay distances
         -- setup for the destination aisle.
         NULL;
      ELSE 
          -- Found the min bay closest to the destination bay.

         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                             pl_lma.ct_detail_level_2);

            l_message := 'Found door to bay distance setup.' ||
               '  From Door: ' || i_from_door || '  To Bay: ' ||
               l_db_min_aislebay;
            pl_lma.audit_cmt(l_message, l_db_min_aislebay_dist,
                             pl_lma.ct_detail_level_2);

            pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                             pl_lma.ct_detail_level_2);
         END IF;  -- end audit

         -- If the min bay is the same as the destination bay then
         -- we have the distance.
         IF (l_db_min_aislebay = l_to_aislebay) THEN
            -- The destination bay is setup as a door to bay distance.
            l_door_to_bay_dist := l_db_min_aislebay_dist;
            l_save_bay := l_to_aislebay;
   
            IF (pl_lma.g_audit_bln) THEN
               l_message := 'Destination bay ' || l_to_aislebay ||
                            ' is setup as a door to bay distance.';
               pl_lma.audit_cmt(l_message, l_db_min_aislebay_dist,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit
         ELSE
            -- Fetch the max bay closest to the destination bay if it exists.
            FETCH c_db_dist_same_aisle
                      INTO l_db_max_aislebay,
                           l_db_max_aislebay_dist,
                           l_dummy1, l_dummy2;

            IF (c_db_dist_same_aisle%FOUND) THEN
               -- Found the max bay closest to the destination bay.
               NULL;

               IF (pl_lma.g_audit_bln) THEN
                  pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
                  l_message := 'Found door to bay distance setup.' ||
                     '  From Door: ' || i_from_door ||
                     '  To Bay: ' || l_db_max_aislebay;
                  pl_lma.audit_cmt(l_message, l_db_max_aislebay_dist,
                                   pl_lma.ct_detail_level_2);
                  pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
               END IF;  -- end audit

            END IF;
         END IF;
      END IF;

      CLOSE c_db_dist_same_aisle;
dbms_output.put_line('RRRRR');

      -- If there are door to bay distances for the destination aisle and
      -- one of these was not the destination bay then calculate the
      -- distance to the destination bay.
if (1 = 1) then  -- GGGG
null;
      ELSIF (l_door_to_bay_dist = ct_big_number AND
          l_db_min_aislebay_dist != ct_big_number) THEN
dbms_output.put_line('SSSS');

         IF (l_db_max_aislebay_dist != ct_big_number) THEN
            -- Found two door to bay distances going to the
            -- destination aisle.  Calculate the distance from the door
            -- directly to the destination bay.
            --
dbms_output.put_line('TTTT');

            IF (pl_lma.g_audit_bln) THEN
               l_message := 'There are door to bay distances setup for the destination aisle.';
               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                pl_lma.ct_detail_level_2);
            END IF;  -- end audit

            -- pl_lmd.f_get_door_to_bay_direct_dist returns ct_big_number if
            -- unable to calculate the distance.  This can happen if the
            -- point distances do not form a triangle.
            l_door_to_bay_dist := pl_lmd.f_get_door_to_bay_direct_dist
                       (i_dock_num, i_from_door, i_to_bay,
                        l_db_min_aislebay, l_db_max_aislebay,
                        l_db_min_aislebay_dist, l_db_max_aislebay_dist);
dbms_output.put_line('UUUU');

            IF (l_door_to_bay_dist = ct_big_number) THEN
               -- Unable to calculate the distance from the door directly
               -- to the destination bay.  Use the shortest of the following
               -- as the distance from the door to the destination bay.
               --    - Door -> min bay -> destination bay 
               --    - Door -> max bay -> destination bay 
dbms_output.put_line('VVVV');


               IF (pl_lma.g_audit_bln) THEN
                  l_message := 'Unable to calculate the distance from door ' ||
                     i_from_door || ' directly to bay ' || l_to_aislebay || '.';
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);

                  pl_lma.audit_cmt('Use the shortest of the following as' ||
                     ' the distance from the door to the destination bay' ||
                     ' using door to bay distances:', pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);

                  l_message := '-'||i_from_door||' -> '||l_db_min_aislebay||
                     ' -> '||l_to_aislebay||'.'||
                     '  Distance from ' ||i_from_door||' to '||
                     l_db_min_aislebay||' is ' ||
                     TO_CHAR(l_db_min_aislebay_dist)||'.';
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);

                  l_message := '-'||i_from_door||' -> '||l_db_max_aislebay||
                     ' -> '||l_to_aislebay||'.'||
                     '  Distance from ' ||i_from_door||' to '||
                     l_db_max_aislebay ||
                     ' is ' || TO_CHAR(l_db_max_aislebay_dist)||'.';
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
               END IF; -- end audit

dbms_output.put_line('WWWW');
               l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_dist(i_dock_num,
                                            l_db_min_aislebay, i_to_bay);

dbms_output.put_line('XXXX');
               l_door_to_bay_dist := l_db_min_aislebay_dist +
                                     l_bay_to_bay_dist;

               l_save_bay := l_db_min_aislebay;


               l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_dist(i_dock_num,
                                            l_db_max_aislebay, i_to_bay);
dbms_output.put_line('YYYY');

               IF (l_door_to_bay_dist >
                      (l_db_max_aislebay_dist + l_bay_to_bay_dist)) THEN
                  l_door_to_bay_dist := l_db_max_aislebay_dist +
                                     l_bay_to_bay_dist;
                  l_save_bay := l_db_max_aislebay;
               END IF;
            END IF;
         END IF;
      ELSE
         -- Found one door to bay distance going to the destination
         -- aisle meeting the selection criteria.  The distance to the
         -- destination bay will be from the door to the "door to bay"
         -- bay then to the destination bay.
dbms_output.put_line('ZZZZ');
         IF (pl_lma.g_audit_bln) THEN
            l_message := 'The distance from ' || i_from_door || ' to ' ||
                l_to_aislebay || ' using door to bay distances will be from ' ||
                i_from_door || ' to ' || l_db_min_aislebay || ' to ' ||
                l_to_aislebay || '.';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         END IF;  -- end audit

         l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_dist(i_dock_num,
                                              l_db_min_aislebay, i_to_bay);
dbms_output.put_line('1111');

         l_door_to_bay_dist := l_bay_to_bay_dist + l_db_min_aislebay_dist;
         l_save_bay := l_db_min_aislebay;
      END IF;

      -- If l_door_to_bay_dist is ct_big_number at this point then there were
      -- no door to bay distances for the destination aisle.  Select the door
      -- to bay distances setup for the door.  For each aisle calculate the
      -- following distances, if they exist, then use the mininum distance.
      --    - Distance from the door to the min bay then to
      --      the destination bay.
      --    - Distance from the door to the max bay then to
      --      the destination bay.
      --    - Distance from the door to the cross aisle bay then to
      --      the destination bay.
      IF (l_door_to_bay_dist = ct_big_number
and 1 = 2) THEN  -- GGGG
dbms_output.put_line('BBBBB');
         FOR r_db_dist IN c_db_dist LOOP

            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                                pl_lma.ct_detail_level_2);

               l_message := 'Found door to bay distance setup.  From Door: ' ||
                  i_from_door || '  To Bay: ' ||r_db_dist.aislebay;
               pl_lma.audit_cmt(l_message, r_db_dist.dist,
                                pl_lma.ct_detail_level_2);

               pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                                pl_lma.ct_detail_level_2);
            END IF;   -- end audit

            l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_dist(i_dock_num,
                                    r_db_dist.aislebay, i_to_bay);

            IF (l_door_to_bay_dist >
                      (l_bay_to_bay_dist + r_db_dist.dist)) THEN
               l_door_to_bay_dist :=
                            l_bay_to_bay_dist + r_db_dist.dist;
               l_save_bay := r_db_dist.aislebay;
            END IF;
         END LOOP;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         IF (l_door_to_bay_dist = ct_big_number) THEN
            l_message := 'No Door to Bay Distances found for door ' ||
                         i_from_door || '.';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         ELSE
            l_message := 'Shortest Door to Bay Distance Using Door to Bay' ||
               ' Distances  Dock: ' || i_dock_num || '  From Door: ' ||
               i_from_door || '  To Bay: ' || l_save_bay || '  Then To Bay: ' ||
               l_to_aislebay;
            pl_lma.audit_cmt(l_message, l_door_to_bay_dist,
                             pl_lma.ct_detail_level_2);
         END IF;
      END IF;  -- end audit

      RETURN(l_door_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_dist_using_door_bay_dist;
                          

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the specified door and bay
   --    on the specified dock.
   --
   --    In the point distance setup a door can have a distance setup to
   --    one or more bays.  This allows different routes to the destination bay.
   --    Usually door to bay distances are setup for docks that run parallel
   --    to the aisles.
   --
   --    The door to bay distance will be the shortest of the following:
   --       1. Door to start of the aisle (or end of the aisle if at the
   --          back dock) then from the start of the aisle (or end of the aisle)
   --          to the destination bay.
   --       2. Shortest distance using the door to bay point distances if any
   --          are setup.
   --
   -- Parameters:
   --    i_dock_num  - Specified dock.  This needs to be the door dock number.
   --    i_from_door - Specified door.
   --    i_to_bay    - Specified bay.  Can either be a location or
   --                  only a bay (ie. from haul).  Examples: DC01, DC01A4
   --                  Note that it must include the aisle.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/24/01 prpbcb   Created.  
   --
   --    09/24/01 prpbcb   History from PRO*C program:
   --    06/19/00 prpbcb   Modified to find the shortest distance when the
   --                      door is on a dock parallel to the aisles.
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_bay_dist
                (i_dock_num                   IN point_distance.point_dock%TYPE,
                 i_from_door                  IN point_distance.point_a%TYPE,
                 i_to_bay                     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_door_to_bay_dist';

      l_aisle_to_bay_dist         NUMBER; -- Aisle to bay distance
      l_dist_using_door_bay_dist  NUMBER; -- Door to bay distance using door
                                          -- to bay distance setup.
      l_door_to_aisle_dist        NUMBER; -- Door to aisle distance
      l_door_to_bay_dist          NUMBER; -- Door to bay distance
      l_to_aisle                  VARCHAR2(10);  -- Aisle of i_to_bay
      l_to_aislebay               VARCHAR2(10);  -- Aisle and bay of i_to_bay

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
                         '(i_dock_num[' || i_dock_num || ']' ||
                         ',i_from_door[' || i_from_door || ']' ||
                         ',i_to_bay[' || i_to_bay || ']' ||
                         ',i_follow_aisle_direction[' || l_message || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Extract the aisle and aisle-bay from i_to_bay.
      l_to_aisle := SUBSTR(i_to_bay, 1, 2);
      l_to_aislebay := SUBSTR(i_to_bay, 1, 4);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Calculate door to bay distance.' ||
            '  Dock: ' || i_dock_num || '  Door: ' || i_from_door ||
            '  Bay: ' || l_to_aislebay;
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         pl_lma.audit_cmt('The following distances are calculated and the' ||
            ' shortest distance used:', pl_lma.ct_na, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('- Door to start of the aisle (or end of the' ||
            ' aisle if at the back dock) then to the destination bay.',
            pl_lma.ct_na, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('- If door to bay distances are defined then the' ||
           ' distance from the door to the bay then to the destination' ||
           ' bay.', pl_lma.ct_na, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt(ct_audit_msg_divider, pl_lma.ct_na,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      -- Get door to aisle distance.
      l_door_to_aisle_dist := pl_lmd.f_get_door_to_aisle_dist(i_dock_num,
                                                              i_from_door,
                                                              l_to_aisle);

      -- Get aisle to bay distance.
      l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dock_num,
                                                            l_to_aisle,
                                                            i_to_bay);

      -- Get the door to bay distance using door to bay distance setup.
      l_dist_using_door_bay_dist :=
           pl_lmd.f_get_dist_using_door_bay_dist(i_dock_num, i_from_door,
                                                 i_to_bay);
-- l_dist_using_door_bay_dist := 99999999;
-- dbms_output.put_line('AAAAA door_bay-dist is ' ||
-- to_char(l_dist_using_door_bay_dist));

      -- Compare the distance going to the front(or end) of the aisle then
      -- to the bay against the distance using door to bay distances and
      -- use the shortest distance of these two distances.
      IF ((l_door_to_aisle_dist + l_aisle_to_bay_dist) <=
                                          l_dist_using_door_bay_dist) THEN
         l_door_to_bay_dist := l_door_to_aisle_dist + l_aisle_to_bay_dist;
      ELSE
         l_door_to_bay_dist := l_dist_using_door_bay_dist;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Door to Bay Distance  Dock: ' || i_dock_num ||
            '  Door: ' || i_from_door || '  Bay: ' || l_to_aislebay;
         pl_lma.audit_cmt(l_message, l_door_to_bay_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      RETURN(l_door_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_door_to_bay_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_door_to_door_dist
   --
   -- Description:
   --    This function finds the distance between two doors within the
   --    same area.  The doors can be on different docks but the docks need
   --    to be in the same area.
   --
   -- Parameters:
   --    i_from_dock_num  - Dock of the starting door.
   --    i_to_dock_num    - Dock of the ending door.
   --    i_from_door      - Starting door.
   --    i_to_door        - Ending door.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_dtd   Door to door distance not setup.
   --    pl_exc.e_database_error            Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/20/01 prpbcb   Created.  
   --
   --    09/09/01 prpbcb   History from PRO*C program:
   --    05/12/00 prpbcb   Modified to extract the starting and ending docks
   --                      from the starting and ending doors.  The first two
   --                      characters in the door # are the dock.  Parameters
   --                      i_from_dock_num and i_to_dock_num are no longer used.
   --
   ---------------------------------------------------------------------------
   FUNCTION f_get_door_to_door_dist
                         (i_from_dock_num  IN point_distance.point_dock%TYPE,
                          i_to_dock_num    IN point_distance.point_dock%TYPE,
                          i_from_door      IN point_distance.point_a%TYPE,
                          i_to_door        IN point_distance.point_a%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(512);  -- Message buffer
      l_message_param  VARCHAR2(512);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                              '.f_get_door_to_door_dist';

      l_door_to_door_dist  NUMBER;         -- Door to door distance.
      l_from_dock_no       point_distance.point_dock%TYPE;
      l_to_dock_no         point_distance.point_dock%TYPE;

      -- This cursor calculates the door to door distance.
      CURSOR c_door_to_door_dist IS
         SELECT SUM(point_dist)
           FROM point_distance
          WHERE point_dock = l_from_dock_no 
            AND point_type = 'DD'
            AND (((i_from_door < i_to_door) AND
                  (point_a >= i_from_door) AND
                  (point_b <= i_to_door))
               OR
                ((i_from_door > i_to_door) AND
                 (point_a >= i_to_door) AND
                 (point_b <= i_from_door)));
   BEGIN

      l_message_param := l_object_name || '(' || i_from_dock_num || ',' ||
                         i_to_dock_num || ',' || i_from_door || ',' ||
                         i_to_door || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Extract the dock numbers from the doors.
      l_from_dock_no := SUBSTR(i_from_door, 1, 2);
      l_to_dock_no := SUBSTR(i_to_door, 1, 2);

      IF (pl_lma.g_audit_bln) THEN
         l_message :=
           'Calculate door to door distance.  From Dock: ' || l_from_dock_no ||
           '  To Dock: ' || l_to_dock_no || '  From Door: ' || i_from_door ||
           '  To Door: ' || i_to_door;
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;

      -- Calculate the distance between the doors if they are different.
      -- If it is the same door then the distance will be 0.
      IF (i_from_door != i_to_door) THEN
         --  The from and to doors are different.
         --  Check the dock the doors are on and perform the appropriate
         --  processing.
         IF (l_from_dock_no = l_to_dock_no) THEN
            -- The doors are on the same dock.
            OPEN c_door_to_door_dist;
            FETCH c_door_to_door_dist INTO l_door_to_door_dist;

            IF (c_door_to_door_dist%NOTFOUND) THEN
               CLOSE c_door_to_door_dist;
               RAISE pl_exc.e_lm_pt_dist_badsetup_dtd;
            END IF;

            CLOSE c_door_to_door_dist;
         ELSE
            -- The doors are on different docks in the same area.
            l_door_to_door_dist :=
                pl_lmd.f_get_dr_to_dr_dist_diff_dock(l_from_dock_no,
                                                     l_to_dock_no,
                                                     i_from_door,
                                                     i_to_door);
         END IF;
      ELSE
         -- The doors are the same so the distance is 0.
         l_door_to_door_dist := 0;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Door to Door Distance  From Dock: ' || l_from_dock_no ||
            '  To Dock: ' || l_to_dock_no  ||
            '  From Door: ' || i_from_door || '  To Door: ' || i_to_door;
         pl_lma.audit_cmt(l_message, l_door_to_door_dist,
                          pl_lma.ct_detail_level_2);
      END IF;

      RETURN(l_door_to_door_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_dtd THEN
         l_message := l_message_param || '  TABLE=point_distance' ||
            '  point_type=DD  ACTION=SELECT' ||
            '  MESSAGE="Door to door distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_door_to_door_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_dr_to_dr_dist_diff_dock
   --
   -- Description:
   --    This function finds the distance between two doors WITHIN THE
   --    SAME AREA but on different docks.
   --
   --    The following distances are calculated then added together to get
   --    the door to door distance.
   --       - Determine the aisle closest to the from door and get the
   --       - length of this aisle.
   --       - Distance from the from door to the closest aisle.
   --       - Distance from the to door to the closest aisle.
   --
   --    Called by f_get_door_to_door_dist.
   --
   -- Parameters:
   --    i_from_dock_num  - Dock of the starting door.
   --    i_to_dock_num    - Dock of the ending door.
   --    i_from_door      - Starting door.
   --    i_to_door        - Ending door.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_dtd   Door to door distance not setup.
   --    pl_exc.e_data_error                A called object returned an
   --                                       user defined error.
   --    pl_exc.e_database_error            Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/21/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_dr_to_dr_dist_diff_dock
                         (i_from_dock_num  IN point_distance.point_dock%TYPE,
                          i_to_dock_num    IN point_distance.point_dock%TYPE,
                          i_from_door      IN point_distance.point_a%TYPE,
                          i_to_door        IN point_distance.point_a%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                             '.f_get_dr_to_dr_dist_diff_dock';

      l_closest_aisle            point_distance.point_b%TYPE;
      l_closest_aisle_length     NUMBER := 0;
      l_door_to_door_dist        NUMBER;
      l_from_door_to_aisle_dist  NUMBER;
      l_to_door_to_aisle_dist    NUMBER;

      e_closest_aisle_not_found  EXCEPTION;

      -- This cursor selects the aisle closest to the specified door.
      -- It is possible to return more than one aisle.  We will use the
      -- first one fetched.
      CURSOR c_closest_aisle(cp_point_dock point_distance.point_dock%TYPE,
                             cp_door_no    point_distance.point_a%TYPE) IS
         SELECT point_b 
           FROM point_distance pd1
          WHERE point_type = 'DA'
            AND point_dock = cp_point_dock
            AND point_a    = cp_door_no
            AND point_dist = (SELECT MIN(point_dist)
                                FROM point_distance pd2
                               WHERE pd2.point_type = pd1.point_type
                                 AND pd2.point_dock = pd1.point_dock
                                 AND pd2.point_a    = pd1.point_a);

   BEGIN

      l_message_param := l_object_name || '(' ||
                         'i_from_dock_num[' || i_from_dock_num || '],' ||
                         'i_to_dock_num['   || i_to_dock_num   || '],' ||
                         'i_from_door['     || i_from_door     || '],' ||
                         'i_to_door['       || i_to_door       || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Find the closest aisle to the from door and get the length of this
      -- aisle.

      OPEN c_closest_aisle(i_from_dock_num, i_from_door);  
      FETCH c_closest_aisle INTO l_closest_aisle;
 
      IF (c_closest_aisle%NOTFOUND) THEN  
         CLOSE c_closest_aisle;  
         RAISE e_closest_aisle_not_found;
      END IF;
          
      CLOSE c_closest_aisle;  

      l_closest_aisle_length := pl_lmd.f_get_aisle_length(l_closest_aisle);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Door ' || i_from_door || 'and door ' || i_to_door ||
            ' are in the same area but on different docks.';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         l_message := 'The distance between the doors is the sum of the' ||
            ' following:';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         l_message := '1.  Length of the aisle closest to door ' ||
            i_from_door || ' which is aisle ' || l_closest_aisle || '.';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         l_message := '2.  Distance from door ' || i_from_door ||
            ' to aisle ' || l_closest_aisle || '.';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         l_message := '3.  Distance from door ' || i_to_door ||
            ' to aisle ' || l_closest_aisle || '.';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);

         l_message := 'Length of aisle ' || l_closest_aisle || '.';
         pl_lma.audit_cmt(l_message, l_closest_aisle_length,
                          pl_lma.ct_detail_level_2);
      END IF;   -- end audit
        
      l_from_door_to_aisle_dist := pl_lmd.f_get_door_to_aisle_dist
                              (i_from_dock_num, i_from_door, l_closest_aisle);

      l_to_door_to_aisle_dist := pl_lmd.f_get_door_to_aisle_dist(i_to_dock_num,
                                    i_to_door, l_closest_aisle);

      l_door_to_door_dist := l_closest_aisle_length +
                             l_from_door_to_aisle_dist +
                             l_to_door_to_aisle_dist;

      IF (pl_lma.g_audit_bln) THEN
         -- Dashes output to aid in the readability of the audit report.
         l_message := '----------------------------------------';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;

      RETURN(l_door_to_door_dist);

   EXCEPTION
      WHEN e_closest_aisle_not_found THEN
         l_message := l_message_param ||
            '  TABLE=point_distance  point_type=DD' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Cannot find the closest aisle to door '|| i_from_door ||
            '  on dock ' || i_from_dock_num || '."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_dr_to_dr_dist_diff_dock;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_aisle_dist
   --
   -- Description:
   --    This function finds the distance between the pickup point and aisle
   --    on the specified dock.
   --
   --  Parameters:
   --     i_dock_num  - Specified dock.  This needs to be the door dock number.
   --     i_from_pup  - Specified pickup point.  Example: LBL1
   --     i_to_aisle  - Specified aisle.  Example: DA
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_pta  - Pickup point to aisle distance
   --                                        not setup.
   --    pl_exc.e_database_error           - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/20/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_aisle_dist
                          (i_dock_num   IN point_distance.point_dock%TYPE,
                           i_from_pup   IN point_distance.point_a%TYPE,
                           i_to_aisle   IN point_distance.point_b%TYPE)
   RETURN NUMBER IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_message_param VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_get_pup_to_aisle_dist';

      l_pup_to_aisle_dist  NUMBER;     --  Pickup point to aisle distance

      -- This cursor selects the pickup point to aisle distance.
      CURSOR c_pup_to_aisle_dist IS
         SELECT point_dist
           FROM point_distance
          WHERE point_dock = i_dock_num 
            AND point_type = 'PA'
            AND point_a = i_from_pup
            AND point_b = i_to_aisle;
   BEGIN
      l_message_param := l_object_name ||
                         ' i_dock_num[' || i_dock_num || ']' ||
                         ' i_from_pup[' || i_from_pup || ']' ||
                         ' i_to_aisle[' || i_to_aisle || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_pup_to_aisle_dist;
      FETCH c_pup_to_aisle_dist INTO l_pup_to_aisle_dist;

      IF (c_pup_to_aisle_dist%NOTFOUND) THEN
         CLOSE c_pup_to_aisle_dist;
         RAISE pl_exc.e_lm_pt_dist_badsetup_pta;
      END IF;

      CLOSE c_pup_to_aisle_dist;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Pickup Point to Aisle Distance  Dock: ' || i_dock_num ||
            '  From Pickup Point: ' || i_from_pup ||
            '  To Aisle: ' || i_to_aisle;
         pl_lma.audit_cmt(l_message, l_pup_to_aisle_dist,
                          pl_lma.ct_detail_level_2);   
      END IF;  -- end audit
   
      RETURN(l_pup_to_aisle_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_pta THEN
         l_message := l_message_param ||
            '  TABLE=point_distance  point_type=PA' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Pickup point to aisle distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_pup_to_aisle_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_bay_dist
   --
   -- Description:
   --    This function finds the distance between the pickup point and bay
   --    on the specified dock.
   --
   -- Parameters:
   --    i_dock_num  - Specified dock.  This needs to be the pup dock number.
   --    i_from_pup  - Specified pickup point.
   --    i_to_bay    - Specified bay.  Can either be a location or
   --                  only a bay (ie. from haul).  Examples: DC01, DC01A4
   --                  Note that it must include the aisle.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/23/01 prpbcb   Created.  Used function f_get_door_to_bay_dist
   --                      as a template.
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_bay_dist
                (i_dock_num   IN point_distance.point_dock%TYPE,
                 i_from_pup   IN point_distance.point_a%TYPE,
                 i_to_bay     IN VARCHAR2,
                 i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_pup_to_bay_dist';

      l_aisle_after               aisle_info.name%TYPE;  -- Aisle before
      l_aisle_before              aisle_info.name%TYPE;  -- Aisle after
      l_aisle_direction           aisle_info.direction%TYPE;
      l_aisle_to_bay_dist         NUMBER; -- Aisle to bay distance
      l_dock_location             dock.location%TYPE;
      l_pup_to_aisle_dist         NUMBER; -- Pickup point to aisle distance
      l_pup_to_bay_dist           NUMBER; -- Pickup point to bay distance
      l_to_aisle                  aisle_info.name%TYPE;  -- Aisle of i_to_bay
      l_to_aislebay               VARCHAR2(10);  -- Aisle and bay of i_to_bay
      l_temp_dist1                NUMBER;  -- Work area
      l_temp_dist2                NUMBER;  -- Work area

   BEGIN

      -- Extract the aisle and aisle-bay from i_to_bay.
      l_to_aisle := SUBSTR(i_to_bay, 1, 2);
      l_to_aislebay := SUBSTR(i_to_bay, 1, 4);

      IF (i_follow_aisle_direction_bln) THEN
         l_aisle_direction := f_get_aisle_direction(l_to_aisle);
         l_dock_location := f_get_dock_location(i_dock_num);
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
                         '(i_dock_num[' || i_dock_num || ']' ||
                         ',i_from_pup[' || i_from_pup || ']' ||
                         ',i_to_bay[' || i_to_bay || ']' ||
                         ',i_follow_aisle_direction[' || l_message || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Calculate pickup point to bay distance.' ||
            '  Dock: ' || i_dock_num || '  Pickup Point: ' || i_from_pup ||
           '  Bay: ' || l_to_aislebay || '  Aisle direction: ' ||
           TO_CHAR(l_aisle_direction);
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit


      -- If needing to follow the aisle direction and the direction of the
      -- aisle the bay is on is toward the front of the warehouse then the
      -- path to take is down an aisle that has the direction away from
      -- the front of the warehouse then backup to the destination bay.
      IF (    i_follow_aisle_direction_bln
          AND l_aisle_direction = ct_aisle_direction_up
          AND (   l_dock_location = ct_front_dock
               OR l_dock_location = ct_side_dock) ) THEN
   
         -- Get the aisle before and the aisle after that go in the opposite
         -- direction of the destination aisle.
         find_closest_aisles(l_to_aisle, l_aisle_before, l_aisle_after);
 
         IF (l_aisle_before IS NOT NULL OR l_aisle_after IS NOT NULL) THEN
            -- Get the distance using these aisles.
            l_temp_dist1 := ct_big_number;
            l_temp_dist2 := ct_big_number;

            IF (pl_lma.g_audit_bln) THEN
               l_message := 'Traveling directly to the bay is against the' ||
                  ' aisle direction.  Use aisle[' || l_aisle_before || ']' ||
                  ' or aisle [' || l_aisle_after || '] then backup to the bay.';
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
            END IF;

            IF (l_aisle_before IS NOT NULL) THEN
               l_pup_to_aisle_dist := pl_lmd.f_get_pup_to_aisle_dist
                                                (i_dock_num,
                                                 i_from_pup,
                                                 l_aisle_before);

               l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist
                                                (i_dock_num,
                                                 l_aisle_before,
                                                 i_to_bay,
                                                 i_follow_aisle_direction_bln);

               l_temp_dist1 := l_pup_to_aisle_dist + l_aisle_to_bay_dist;


            END IF;

            IF (l_aisle_after IS NOT NULL) THEN
               l_pup_to_aisle_dist := pl_lmd.f_get_pup_to_aisle_dist
                                                (i_dock_num,
                                                 i_from_pup,
                                                 l_aisle_after);

               l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist
                                                (i_dock_num,
                                                 l_aisle_after,
                                                 i_to_bay,
                                                 i_follow_aisle_direction_bln);

               l_temp_dist2 := l_pup_to_aisle_dist + l_aisle_to_bay_dist;
            END IF;

            IF (l_temp_dist2 < l_temp_dist1) THEN
               l_pup_to_bay_dist := l_temp_dist2;
            ELSE
               l_pup_to_bay_dist := l_temp_dist1;
            END IF;
            
         ELSE
            -- Did did find an aisle before or after the destination aisle
            -- so just go directly to the bay.  Write an aplog message
            -- indicating this.

            l_message := 'Calculate pickup point to bay distance.' ||
               '  Dock: ' || i_dock_num || '  Pickup Point: ' || i_from_pup ||
               '  Bay: ' || l_to_aislebay || '  Aisle direction: ' ||
               TO_CHAR(l_aisle_direction) ||
               '  Needed to go down opposing aisle then backup to the bay' ||
               ' but found no aisle to go down.  Will travel directly to bay.';
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message_param,
                           NULL, NULL);

            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                pl_lma.ct_detail_level_1);
            END IF;  -- end audit

            -- Get pickup point to aisle distance.
            l_pup_to_aisle_dist := pl_lmd.f_get_pup_to_aisle_dist(i_dock_num,
                                                                  i_from_pup,
                                                                  l_to_aisle);

            -- Get aisle to bay distance.
            l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dock_num,
                                                                  l_to_aisle,
                                                                  i_to_bay);

            l_pup_to_bay_dist := l_pup_to_aisle_dist + l_aisle_to_bay_dist;
         END IF;

      ELSE
         -- Get distance traveling directly from the pup point to the bay.
         -- Get pickup point to aisle distance.
         l_pup_to_aisle_dist := pl_lmd.f_get_pup_to_aisle_dist(i_dock_num,
                                                               i_from_pup,
                                                               l_to_aisle);

         -- Get aisle to bay distance.
         l_aisle_to_bay_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dock_num,
                                                               l_to_aisle,
                                                               i_to_bay);

         l_pup_to_bay_dist := l_pup_to_aisle_dist + l_aisle_to_bay_dist;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Pickup Point to Bay Distance  Dock: ' || i_dock_num ||
            '  Pickup Point: ' || i_from_pup || '  Bay: ' || l_to_aislebay;
         pl_lma.audit_cmt(l_message, l_pup_to_bay_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      RETURN(l_pup_to_bay_dist);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_pup_to_bay_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_pup_to_pup_dist
   --
   -- Description:
   --    This function finds the distance between two pickup points on the
   --    specified dock.
   --
   -- Parameters:
   --    i_dock_num       - Dock
   --    i_from_pup       - Starting pickup point.
   --    i_to_pup         - Ending pickup point.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_ptp - Pickup point to pickup point
   --                                       distance not setup.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/10/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_pup_to_pup_dist
                        (i_dock_num     IN point_distance.point_dock%TYPE,
                         i_from_pup     IN point_distance.point_a%TYPE,
                         i_to_pup       IN point_distance.point_b%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_pup_to_pup_dist';

      l_pup_to_pup_dist    NUMBER;   -- Pickup point to pickup point distance.

      -- This cursor gets the pickup point to pickup point distance.  A union
      -- is used to handle the distance setup going from point a to point b
      -- or point b to point a.
      CURSOR c_pup_to_pup_dist IS
         SELECT point_dist
           FROM point_distance
          WHERE point_dock = i_dock_num
            AND point_type = 'PP'
            AND point_a    = i_from_pup
            AND point_b    = i_to_pup
         UNION
         SELECT point_dist
           FROM point_distance
          WHERE point_dock = i_dock_num
            AND point_type = 'PP'
            AND point_b    = i_from_pup
            AND point_a    = i_to_pup;
   BEGIN

      l_message_param := l_object_name ||
                         ' i_dock_num[' || i_dock_num || ']' ||
                         ' i_from_pup[' || i_from_pup || ']' ||
                         ' i_to_pup[' || i_to_pup || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         l_message :=
            'Calculate pickup point to pickup point distance.' ||
            '  Dock: ' || i_dock_num ||
            '  From Point: ' || i_from_pup ||
            '  To Point: ' || i_to_pup;
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      -- Calculate the distance between the pickup points if they are different.
      -- If it is the same pickup point then the distance will be 0.
      IF (i_from_pup != i_to_pup) THEN
         --  The points are different.
         OPEN c_pup_to_pup_dist;
         FETCH c_pup_to_pup_dist INTO l_pup_to_pup_dist;

         IF (c_pup_to_pup_dist%NOTFOUND) THEN
            CLOSE c_pup_to_pup_dist;
            RAISE pl_exc.e_lm_pt_dist_badsetup_ptp;
         END IF;

         CLOSE c_pup_to_pup_dist;

      ELSE
         -- The pickup points are the same so the distance is 0.
         l_pup_to_pup_dist := 0;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Pickup Point to Pickup Point  Dock: ' || i_dock_num ||
            '  From Point: ' || i_from_pup || '  To Point: ' || i_to_pup;
         pl_lma.audit_cmt(l_message, l_pup_to_pup_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      RETURN(l_pup_to_pup_dist);

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_ptp THEN
         l_message := l_message_param ||
            '  TABLE=point_distance  point_type=PP' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Pickup point to pickup point distance not setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_pup_to_pup_dist;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    add_distance
   --
   -- Description:
   --    This procedure adds the distances in the second distance record
   --    to the first distance record.
   --
   --  Parameters:
   --     io_rec1
   --     i_rec2
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Got an oracle error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/14/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   PROCEDURE add_distance(io_rec1   IN OUT pl_lmc.t_distance_rec,
                          i_rec2    IN     pl_lmc.t_distance_rec)
   IS
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.add_distance';

   BEGIN

      l_message_param := l_object_name || '(io_rec1,i_rec2)';

      io_rec1.total_distance := io_rec1.total_distance + i_rec2.total_distance;
      io_rec1.accel_distance := io_rec1.accel_distance + i_rec2.accel_distance;
      io_rec1.decel_distance := io_rec1.decel_distance + i_rec2.decel_distance;
      io_rec1.tia_time       := io_rec1.tia_time + i_rec2.tia_time;
      io_rec1.travel_distance := io_rec1.travel_distance +
                                            i_rec2.travel_distance;
   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);

   END add_distance;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_point_type
   --
   -- Description:
   --    This procedure determines the type of the specified point and the
   --    dock it is at.  The valid point type are:
   --       - A  Aisle
   --       - B  Bay  (example DA05)
   --       - D  Door
   --       - P  Pickup point
   --       - W  Warehouse.  This could be referring to a warehouse as
   --            designated by D, C or F or could be referring to a dock
   --            such as D1 or C1.
   --
   --  Parameters:
   --     i_point       - Point
   --     o_point_type  - Point type.
   --     o_dock_num    - The dock the point is at.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_pt - Could not determine the point type
   --                                      because the point was not found in
   --                                      the point_distance or bay_distance
   --                                      or pickup_point tables.
   --    pl_exc.e_database_error         - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/19/01 prpbcb   Created.  
   --
   --    09/19/01 prpbcb   History from PRO*C program:
   --                      Changed the select stmt that determines if the point
   --                      is a bay to return the front dock.  Used new table
   --                      DOCK in the join to use in selecting the front dock.
   --
   --    06/21/02 prpbcb   Changed cursor c_aisle to look at aisle to aisle
   --                      distances in determining if a point is an aisle.
   --                      Before it looked at door to aisles distances.
   ---------------------------------------------------------------------------
   PROCEDURE get_point_type(i_point      IN  VARCHAR2,
                            o_point_type OUT point_distance.point_type%TYPE,
                            o_dock_num   OUT point_distance.point_dock%TYPE)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_point_type';

      l_aisle           bay_distance.aisle%TYPE;     -- Parsed aisle
      l_bay             bay_distance.bay%TYPE;       -- Parsed Bay
      l_dock_num        point_distance.point_dock%TYPE;  -- The point's
                                                         -- dock number.
      l_found_bln       BOOLEAN;                     -- Cursor found status.
      l_level           loc.logi_loc%TYPE;           -- Parsed level
      l_point_type      point_distance.point_type%TYPE; -- The point's point
                                                        -- type.

      l_position       loc.logi_loc%TYPE;           -- Parsed position

      -- This cursor determines if the point is a warehouse.
      CURSOR c_whse IS
         SELECT 'W', point_dock
           FROM point_distance
          WHERE point_type = 'WW'
            AND point_a    = i_point;

      -- This cursor determines if the point is a door.
      CURSOR c_door IS
         SELECT 'D', point_dock
           FROM point_distance
          WHERE point_type = 'DA'
            AND point_a    = i_point;

      -- This cursor determines if the point is an aisle.
      CURSOR c_aisle IS
         SELECT 'A', point_dock
           FROM point_distance
          WHERE point_type = 'AA'
            AND (   point_a    = i_point
                 OR point_b    = i_point);

      -- This cursor determines if the point is a pickup point.
      CURSOR c_pickup_point IS
         SELECT 'P', point_dock
           FROM point_distance
          WHERE point_type = 'DP'
            AND point_b    = i_point;

      -- This cursor determines if the point is a bay.
      --
      -- This query can return more than one row.  If there is more than
      -- one dock for the area select the front dock first if it
      -- exists and if not select the side dock first.  If there
      -- is no front or side dock then the back dock is used.  The dock
      -- is significant in that it affects the path used when calculating
      -- the distance between two points in different areas.
      CURSOR c_bay(cp_bay   IN bay_distance.bay%TYPE,
                   cp_aisle IN bay_distance.aisle%TYPE) IS
         SELECT 'B', p.point_dock
           FROM dock d, point_distance p, bay_distance b
          WHERE p.point_type = 'AA'
            AND (   p.point_a    = b.aisle
                 OR p.point_b    = b.aisle)
            AND b.bay        = cp_bay
            AND b.aisle      = cp_aisle 
            AND d.dock_no    = p.point_dock
          ORDER BY DECODE(d.location, 'F', 1, 'S', 2, 'B', 3);
   BEGIN
      l_message_param := l_object_name ||
                         '(i_point[' || i_point || ']' ||
                         ',o_point_type,o_dock_num)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_whse;
      FETCH c_whse INTO l_point_type, l_dock_num;
      l_found_bln := c_whse%FOUND;
      CLOSE c_whse;

      IF (NOT l_found_bln) THEN
         -- The point is not a warehouse.  Check if it is a door.
         OPEN c_door;
         FETCH c_door INTO l_point_type, l_dock_num;
         l_found_bln := c_door%FOUND;
         CLOSE c_door;

         IF (NOT l_found_bln) THEN
            -- The point is not a door.  Check if it is an aisle.
            OPEN c_aisle;
            FETCH c_aisle INTO l_point_type, l_dock_num;
            l_found_bln := c_aisle%FOUND;
            CLOSE c_aisle;

            IF (NOT l_found_bln) THEN
               -- The point is not an aisle.  Check if it is a pickup point.
               OPEN c_pickup_point;
               FETCH c_pickup_point INTO l_point_type, l_dock_num;
               l_found_bln := c_pickup_point%FOUND;
               CLOSE c_pickup_point;

               IF (NOT l_found_bln) THEN
                  -- The point is not a pickup point.  Check if it is a bay.
                  -- Parse out the aisle and bay from the point.
                  -- The position and level are ignored as they are not
                  -- needed.
                  parse_location(i_point, l_aisle, l_bay, l_position, l_level);

                  OPEN c_bay(l_bay, l_aisle);
                  FETCH c_bay INTO l_point_type, l_dock_num;
                  l_found_bln := c_bay%FOUND;
                  CLOSE c_bay;

                  IF (NOT l_found_bln) THEN
                     -- The point is not a bay.  Don't know what it is.
                     RAISE pl_exc.e_lm_pt_dist_badsetup_pt;
                  END IF;
               END IF;
            END IF;
         END IF;
      END IF;

      o_point_type := l_point_type;
      o_dock_num := l_dock_num;

      l_message := l_object_name ||'  Point[' || i_point || '] is point type['||
                   l_point_type || '] on dock[' || l_dock_num ||']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);
 
   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_pt THEN
         l_message := l_object_name ||
            '  TABLE=point_distance,bay_distance  ACTION=SELECT' ||
            '  MESSAGE="Cannot determine the point type of point'||
            '[' || i_point || '].  Check setup.  Is it a valid point?"';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END get_point_type;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_whse_to_aisle_dist
   --
   -- Description:
   --    This procedure finds the aisle in one dock closest to another dock
   --    and the distance from this aisle to the other dock.
   --
   --  Parameters:
   --      i_from_dock_num  - From dock.
   --      i_to_dock_num    - To dock.
   --      o_first_aisle    - Aisle in the "to" dock that is closest to the
   --                         "from" dock.  Determined by this procedure.
   --      o_dist           - Distance between the "from" dock and the closest
   --                         aisle in the "to" dock.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_wfa - Warehouse to first aisle distance
   --                                       not setup.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/19/01 prpbcb   Created.  
   --
   --    09/19/01 prpbcb   History from PRO*C program:
   --    05/17/00 prpbcb   Modified the select statement to select the distance
   --                      defined for the dock and then the distance defined
   --                      for the area.  A change has been made in the
   --                      warehouse to aisle distance setup in the
   --                      point_distance table to put in the dock as the "to"
   --                      point instead of the area.  The area was still left
   --                      in the select statement to enable the old
   --                      point_distance setup to work but the old setup will
   --                      cause inaccurate distances if the area has more than
   --                      one dock.
   --
   --                      Example setup of warehouse to aisle distances:
   --                   point_dock point_type point_a point_b point_dist
   --                   ---------- ---------- ------- ------- ----------
   --        Old setup     F1         WA        D       DB        200
   --        New setup     F1         WA        D1      DB        200
   --
   ---------------------------------------------------------------------------
   PROCEDURE get_whse_to_aisle_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE,
                           o_first_aisle   OUT point_distance.point_a%TYPE,
                           o_dist          OUT NUMBER)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                               '.f_get_whse_to_aisle_dist';

      l_first_aisle  point_distance.point_a%TYPE;
      l_dist         NUMBER := 0;

      CURSOR c_point_distance IS
         SELECT NVL(point_dist,0), point_b 
           FROM point_distance
          WHERE point_dock = i_from_dock_num 
            AND point_type = 'WA'
            AND (point_a = i_to_dock_num
                 OR point_a = SUBSTR(i_to_dock_num,1,1))
          ORDER BY point_a DESC;

   BEGIN

      l_message_param := l_object_name ||
         '(i_from_dock_num[' || i_from_dock_num || ']' ||
         ',i_to_dock_num[' || i_to_dock_num || ']' ||
         ',o_first_aisle,o_dist';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_point_distance;
      FETCH c_point_distance INTO l_dist, l_first_aisle;

      IF (c_point_distance%NOTFOUND) THEN
         CLOSE c_point_distance;
         RAISE pl_exc.e_lm_pt_dist_badsetup_wfa;
      END IF;

      CLOSE c_point_distance;

      o_first_aisle := l_first_aisle;
      o_dist := l_dist;

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name,
         'o_first_aisle: ' || l_first_aisle ||
         '  o_dist: ' || TO_CHAR(l_dist), NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Warehouse to Aisle Distance  From Dock: ' ||
                i_from_dock_num || '  To Dock: ' || i_to_dock_num ||
                '  To Aisle: ' || l_first_aisle;
         pl_lma.audit_cmt(l_message, l_dist,
                          pl_lma.ct_detail_level_2);
      END IF;

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_wfa THEN
         l_message := l_object_name || '  TABLE=point_distance' ||
            '  point_type=WA  i_from_dock[' || i_from_dock_num || ']' ||
            '  i_to_dock_num[' || i_to_dock_num || ']' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Warehouse to first aisle distance not setup.' ||
            '  Check distance setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END get_whse_to_aisle_dist;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_whse_to_door_dist
   --
   -- Description:
   --    This procedure finds the door in one dock closest to another dock
   --    and the distance from this door to the other dock.
   --
   --  Parameters:
   --      i_from_dock_num  - From dock.
   --      i_to_dock_num    - To dock.
   --      o_first_door     - Door in the "to" dock that is closest to the
   --                         "from" dock.  Determined by this procedure.
   --      o_dist           - Distance between the "from" dock and the closest
   --                         door in the "to" dock.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_wfd - Warehouse to first door distance
   --                                       not setup.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/19/01 prpbcb   Created.  
   --
   --    09/19/01 prpbcb   History from PRO*C program:
   --    05/17/00 prpbcb   Modified the select statement to select the distance
   --                      defined for the dock and then the distance defined
   --                      for the area.  A change has been made in the
   --                      warehouse to door distance setup in the
   --                      point_distance table to put in the dock as the "to"
   --                      point instead of the area.  This allows the distance
   --                      to doors in the same area but different docks to be
   --                      easily defined.  The area was still left in the
   --                      select statement to enable the old point_distance
   --                      setup to work but the old setup will cause
   --                      inaccurate distances if the area has more than one
   --                      dock.
   --
   --                      Example setup of warehouse to door distances:
   --                   point_dock point_type point_a point_b point_dist
   --                   ---------- ---------- ------- ------- ----------
   --        Old setup     F1         WD        D       D133      200
   --        New setup     F1         WD        D1      D133      200
   --
   ---------------------------------------------------------------------------
   PROCEDURE get_whse_to_door_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE,
                           o_first_door    OUT point_distance.point_a%TYPE,
                           o_dist          OUT NUMBER)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                                '.f_get_whse_to_door_dist';

      l_first_door       point_distance.point_a%TYPE;
      l_w_to_door_dist   NUMBER := 0;

      CURSOR c_point_distance IS
         SELECT NVL(point_dist,0), point_b 
           FROM point_distance
          WHERE point_dock = i_from_dock_num 
            AND point_type = 'WD'
            AND (point_a = i_to_dock_num
                 OR point_a = SUBSTR(i_to_dock_num,1,1))
          ORDER BY point_a DESC;

   BEGIN
      l_message_param := l_object_name ||
         '(i_from_dock_num[' || i_from_dock_num || ']' ||
         ',i_to_dock_num[' || i_to_dock_num || ']' ||
         ',o_first_door,o_dist';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_point_distance;

      FETCH c_point_distance INTO l_w_to_door_dist, l_first_door;

      IF (c_point_distance%NOTFOUND) THEN
         CLOSE c_point_distance;
         RAISE pl_exc.e_lm_pt_dist_badsetup_wfd;
      END IF;

      CLOSE c_point_distance;

      o_first_door := l_first_door;
      o_dist := l_w_to_door_dist;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Warehouse to Door Distance  From Dock: ' ||
                i_from_dock_num || '  To Dock: ' || i_to_dock_num ||
                '  To Door: ' || l_first_door;
         pl_lma.audit_cmt(l_message, l_w_to_door_dist,
                          pl_lma.ct_detail_level_2);
      END IF;  -- end audit

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_wfd THEN
         l_message := l_object_name || '  TABLE=point_distance' ||
            '  point_type=WD  i_from_dock[' || i_from_dock_num || ']' ||
            '  i_to_dock_num[' || i_to_dock_num || ']' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Warehouse to first door distance not setup.' ||
            '  Check distance setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ':' || SQLERRM);

   END get_whse_to_door_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    get_whse_to_pup_dist
   --
   -- Description:
   --    This function finds the distance from a pickup point on the "from"
   --    dock to the point in the travel lane on the "from" dock where we
   --    are just leaving the dock on the way to the "to" dock.
   --
   -- Parameters:
   --    i_from_dock_num  - From dock.
   --    i_to_dock_num    - To dock.
   --
   -- Return value:
   --    distance
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_wtp  - Warehouse to pickup point distance
   --                                        not found.
   --    pl_exc.e_database_error           - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/08/02 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION get_whse_to_pup_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_pup_point     IN  point_distance.point_a%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_whse_to_pup_dist';

      l_dist   NUMBER := 0;  -- Warehouse to pickup point distance.

      -- This cursor selects the distance.
      -- The select may be a bit confusing because of how the distance is
      -- defined in the point distance table.
      CURSOR c_point_distance IS
         SELECT NVL(point_dist,0)
           FROM point_distance
          WHERE point_dock = i_to_dock_num 
            AND point_type = 'WP'
            AND point_b = i_pup_point
            AND (point_a = i_from_dock_num
                 OR point_a = SUBSTR(i_from_dock_num,1,1))
          ORDER BY point_a DESC;
   BEGIN

      l_message_param := l_object_name ||
         '(i_from_dock_num[' || i_from_dock_num || '],' ||
         'i_pup_point[' || i_pup_point || '],' ||
         'i_to_dock_num[' || i_to_dock_num|| '])';
 
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_point_distance;
      FETCH c_point_distance INTO l_dist;

      IF (c_point_distance%NOTFOUND) THEN
         CLOSE c_point_distance;
         RAISE pl_exc.e_lm_pt_dist_badsetup_wtp;
      END IF;

      CLOSE c_point_distance;

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Warehouse to Pickup Point Distance -- Distance from ' ||
            i_pup_point || ' on dock ' || i_from_dock_num || ' to the ' ||
            ' travel lane leaving ' || i_from_dock_num ||
            ' on the way to dock ' || i_to_dock_num || ',';
            
         pl_lma.audit_cmt(l_message, l_dist, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, 
                     'Distance from ' || i_pup_point || ' on dock ' ||
                     i_from_dock_num || ' to the travel lane: ' || 
                     TO_CHAR(l_dist),
                     NULL, NULL);

      RETURN(l_dist);

   -- In the log message make sure l_message is set to the desired value.
   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_wtp THEN
         l_message := l_object_name || '  TABLE=point_distance' ||
            '  point_type=WP  i_from_dock=' || i_from_dock_num ||
            '  i_pup_point=' || i_pup_point ||
            '  i_to_dock_num=' || i_to_dock_num ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Warehouse to pickup point distance not setup.' ||
            '  Check distance setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ':' || SQLERRM);
   END get_whse_to_pup_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    get_whse_to_whse_dist
   --
   -- Description:
   --    This function finds the distance between the two warehouses for the
   --    specified docks.  A warehouse is the dry, cooler or freezer areas
   --    at the company.
   --
   --    This distance can be the distance between docks in different 
   --    warehouses (the preferred setup) or can be the distance between
   --    the warehouses.  If there is more than one dock in a warehouse then
   --    the distance between docks needs to be specified otherwise the 
   --    distance calculated will be incorrrect.
   --
   --  Parameters:
   --      i_from_dock_num  - From dock.
   --      i_to_dock_num    - To dock.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_wtw - Warehouse to warehouse distance
   --                                       not setup.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/19/01 prpbcb   Created.  
   --
   --    09/19/01 prpbcb   History from PRO*C program:
   --    05/19/00 prpbcb   Changed the parameters i_from_area, i_to_area
   --                      to i_from_dock_num, i_to_dock_num.
   --                      The from and to docks are now passed to this
   --                      function.  This allows the WW distance in the
   --                      point_distance table to be defined as area to area
   --                      or dock to dock.  If both area to area and dock to
   --                      dock are defined the dock to dock distance will be
   --                      used.
   --
   --                      Example point_distance setup:
   --       point_dock point_type point_a point_b point_dist
   --       ---------- ---------- ------- ------- ----------
   --         D1          WW        D       F        50         (area level)
   --         D2          WW        D2      F1       430        (dock level)
   --
   ---------------------------------------------------------------------------
   FUNCTION f_get_whse_to_whse_dist
                          (i_from_dock_num IN  point_distance.point_dock%TYPE,
                           i_to_dock_num   IN  point_distance.point_dock%TYPE)
   RETURN NUMBER IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                               '.f_get_whse_to_whse_dist';

      l_dist         NUMBER := 0;  -- Distance between the warehouses.
      l_dummy        point_distance.point_a%TYPE;  -- Work area

      -- This cursor selects the WW distance.  Select the dock level
      -- record first if there is one.
      CURSOR c_point_distance IS
         SELECT 1 sortval, point_dist      /* Dock level */
           FROM point_distance
          WHERE point_type = 'WW'
            AND point_dock = i_from_dock_num
            AND point_a    = i_from_dock_num
            AND point_b    = i_to_dock_num
         UNION
         SELECT 2 sortval, point_dist      /* Area level */
           FROM point_distance
          WHERE point_type = 'WW'
            AND point_dock = i_from_dock_num
            AND point_a    = SUBSTR(i_from_dock_num, 1, 1)
            AND point_b    = SUBSTR(i_to_dock_num, 1, 1)
          ORDER BY 1;

   BEGIN

      l_message_param := l_object_name ||
         '(i_from_dock_num[ ' || i_from_dock_num || ']' ||
         ',i_to_dock_num[ ' || i_to_dock_num || '])';
 
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_point_distance;
      FETCH c_point_distance INTO l_dummy, l_dist;

      IF (c_point_distance%NOTFOUND) THEN
         CLOSE c_point_distance;
         RAISE pl_exc.e_lm_pt_dist_badsetup_wtw;
      END IF;

      CLOSE c_point_distance;

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name,
                     'Distance: ' || TO_CHAR(l_dist),
                     NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         l_message := 'Warehouse to Warehouse Distance  From Dock: ' ||
             i_from_dock_num || '  To Dock: ' || i_to_dock_num;
         pl_lma.audit_cmt(l_message, l_dist, pl_lma.ct_detail_level_2);
      END IF;
 
      RETURN(l_dist); 

   EXCEPTION
      WHEN pl_exc.e_lm_pt_dist_badsetup_wtw THEN
         l_message := l_object_name || '  TABLE=point_distance' ||
            '  point_type=WW  i_from_dock_num[' || i_from_dock_num || ']' ||
            '  i_to_dock_num[' || i_to_dock_num || ']' ||
            '  ACTION=SELECT' ||
            '  MESSAGE="Warehouse to warehouse distance not setup.' ||
            '  Check distance setup."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, NULL);
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END f_get_whse_to_whse_dist;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    set_travel_docks
   --
   -- Description:
   --    This procedure sets what dock the forklift operator is leaving from
   --    and what dock the forklift operator will arrive at when traveling
   --    from one forklift labor mgmt section to another.  A forklift labor
   --    mgmt section is how the warehouse is split up when defining the
   --    forklift distances.  By default the distance calculation is expecting
   --    the travel between two sections will be from front dock to front dock
   --    but this is not necessarily the case (ie OpCo 96 Abbott).
   --    Table TRAVEL_DOCK is used to specify the travel docks.
   --    If nothing is setup then the the dock parameters are left unchanged.
   --    See the package specification modification history dated 3/28/08
   --    for more information.
   --
   --    When to check the setup in table TRAVEL_DOCK depends on the
   --    sections the points are in and the point types.
   --    The table is checked only when the source and destination points
   --    are in different sections (areas) and one of the points is a bay
   --    or aisle.  We are interested only in a bay or aisle because they were
   --    associated with a dock in lmd_get_pt_to_pt_dist() (which by default is
   --    the front dock) and the forklift operator will be traveling through
   --    these docks to reach the points.  For any other type of point
   --    (such as a door) the distance is setup directly to that dock.
   --
   -- Parameters:
   --    io_r_src_point      - PL/SQL record of the point information for the
   --                          point the forklift operator is traveling from.
   --    io_r_dest_point     - PL/SQL record of the point information for the
   --                          point forklift operator is traveling to.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an user
   --                                 defined error.
   --    pl_exc.e_data_error        - A parameter is null.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Called by:
   --    lm_distance.pc  Function lmd_get_pt_to_pt_dist().
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/28/08 prpbcb   Created.  
   --
   ---------------------------------------------------------------------------
   PROCEDURE set_travel_docks
                (io_r_src_point   IN OUT  pl_lmd.t_point_info_rec,
                 io_r_dest_point  IN OUT  pl_lmd.t_point_info_rec)
   IS
      l_message        VARCHAR2(310);    -- Message buffer
      l_object_name    VARCHAR2(30) := 'set_travel_docks';

      l_dock_changed_bln BOOLEAN := FALSE;  -- Used to designate if a travel
                                   -- dock was changed.
      l_src_dock        dock.dock_no%TYPE;
      l_dest_dock       dock.dock_no%TYPE;
      l_save_src_dock   dock.dock_no%TYPE;  -- Original source dock. Used in
                                            -- log message.
      l_save_dest_dock  dock.dock_no%TYPE;  -- Original source dock. Used in
                                            -- log message.

      --
      -- This cursor selects what dock the forklift operator is leaving from
      -- and what dock the forklift operator will arrive at when traveling
      -- from one forklift labor mgmt section to another.
      -- Note:  The setup in table TRAVEL_DOCK needs to specifty both
      --        ways.
      --        Example:  Cooler has two sections: C and E.
      --                  Section C has front dock C1.
      --                  Section E has front dock E1 and back dock E2.
      --                  When traveling between sections C and E the docks
      --                  traveled to are C1 and E2 (C1 is closest to E2
      --                  and not E1).
      --                  The TRAVEL_DOCK tables needs these records:
      --                     FROM_DOCK   TO_DOCK
      --                     ---------   -------
      --                       C1          E2
      --                       E2          C1
      --
      CURSOR c_travel_dock(cp_src_dock   dock.dock_no%TYPE,
                           cp_dest_dock  dock.dock_no%TYPE) IS
         SELECT d.from_dock_no, d.to_dock_no
           FROM travel_dock d
          WHERE SUBSTR(from_dock_no, 1, 1) = SUBSTR(cp_src_dock, 1, 1)
            AND SUBSTR(to_dock_no, 1, 1)   = SUBSTR(cp_dest_dock, 1, 1);
   BEGIN
      --
      -- Check that the point section (area) and the point dock are populated
      -- in the parameter records.
      --
      IF (   io_r_src_point.pt_type   IS NULL
          OR io_r_dest_point.pt_type  IS NULL
          OR io_r_src_point.area      IS NULL
          OR io_r_dest_point.area     IS NULL
          OR io_r_src_point.dock_num  IS NULL
          OR io_r_dest_point.dock_num IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      --
      -- Check for the travel docks only when the source and destination points
      -- are in different sections (areas) and one of the points is a bay
      -- or aisle.  We are interested only in a bay or aisle because they were
      -- associated with a dock in lmd_get_pt_to_pt_dist() (which by default is
      -- the front dock) and the forklift operator will be traveling through
      -- these docks to reach the points.  For any other type of point
      -- (such as a door) the distance is setup directly to that point.
      --
      IF (    (io_r_src_point.area <> io_r_dest_point.area)
          AND (   io_r_src_point.pt_type  = ct_pt_type_bay
               OR io_r_dest_point.pt_type = ct_pt_type_bay
               OR io_r_src_point.pt_type  = ct_pt_type_aisle
               OR io_r_dest_point.pt_type = ct_pt_type_aisle)) THEN

         OPEN c_travel_dock(io_r_src_point.dock_num,
                            io_r_dest_point.dock_num);
         FETCH c_travel_dock INTO l_src_dock, l_dest_dock;

         IF (c_travel_dock%FOUND) THEN
            --
            -- Travel docks have been defined when traveling between the
            -- sections which indicates they are not the default of front
            -- dock to front dock.
            --

            --
            -- Save the original docks to use later in the log message.
            --
            l_save_src_dock  := io_r_src_point.dock_num;
            l_save_dest_dock := io_r_dest_point.dock_num;

            --
            -- Only change the travel dock if the point is an aisle or bay
            -- and the travel dock is different.  There are situations where
            -- the travel docks does not change, such as this:
            --      Section E has a front dock E1 and a back dock E2.
            --      Section C has front dock C1
            --      The TRAVEL_DOCK setup is:
            --         FROM_DOCK   TO_DOCK
            --         ---------   -------
            --            C1          E2
            --            E2          C1
            --      Travel is from door E161 to bay CD11A1.
            --      Door E161 is on dock E1, bay CD11A1 on dock C1.
            --      Because E161 is a door the dock will always be E1.
            --      Section C only has front dock C1 so the dock for bay
            --      CD11A1 will always be C1.  So, there is nothing to change
            --      though the cursor will select a record.
            --
            IF (    (io_r_src_point.dock_num <> l_src_dock)
                AND (   io_r_src_point.pt_type = ct_pt_type_bay
                     OR io_r_src_point.pt_type = ct_pt_type_aisle)) THEN
               io_r_src_point.dock_num := l_src_dock;
               l_dock_changed_bln := TRUE;
            END IF;

            IF (    (io_r_dest_point.dock_num <> l_dest_dock)
                AND (   io_r_dest_point.pt_type = ct_pt_type_bay
                     OR io_r_dest_point.pt_type = ct_pt_type_aisle)) THEN
               io_r_dest_point.dock_num := l_dest_dock;
               l_dock_changed_bln := TRUE;
            END IF;

            --
            -- Write log message only if the travel dock changed.
            --
            IF (l_dock_changed_bln = TRUE) THEN
               --
               -- Build message for general logging and forklift audting.
               --
               l_message := 'Points ' || io_r_src_point.point || ' and '
                  || io_r_dest_point.point || ' are in different sections of'
                  || ' the warehouse.  When traveling between these two points'
                  || ' the docks traveled to would normally be '
                  || l_save_src_dock || ' and ' || l_save_dest_dock
                  || '.  This has been changed in the travel docks setup'
                  || ' to ' || io_r_src_point.dock_num || ' and '
                  || io_r_dest_point.dock_num || '.';

               --
               -- Write log message.
               --
               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  'io_r_src_point.point[' || io_r_src_point.point || ']'
                  || ' io_r_dest_point.point[' || io_r_dest_point.point || ']'
                  || ' io_r_src_point.dock_num[' || io_r_src_point.dock_num
                  || ']'
                  || ' io_r_dest_point.dock_num[' || io_r_dest_point.dock_num
                  || ']'
                  || '  ' || l_message,
                  NULL, NULL, 'LABOR', gl_pkg_name);

               --
               -- Create forklift audit record if auditing is on.
               --
               IF (pl_lma.g_audit_bln) THEN
                  pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_1);
               END IF;
            END IF;
         ELSE
            --
            -- No travel docks setup so io_src_point.dock_num and
            -- io_dest_point.dock_num remain as is.
            --
            NULL;
         END IF;

         CLOSE c_travel_dock;
      ELSE
         --
         -- The points are in the same sections(areas)
         -- or
         -- the points are not in the same section but none of the points
         -- or an aisle or bay.  Do nothing.
         --
         NULL;
      END IF;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := gl_pkg_name || '.' || l_object_name
            || ' io_r_src_point.pt_type[' || io_r_src_point.pt_type || ']'
            || ' io_r_dest_point.pt_type[' || io_r_dest_point.pt_type || ']'
            || ' io_r_src_point.area[' || io_r_src_point.area || ']'
            || ' io_r_dest_point.area[' || io_r_dest_point.area || ']'
            || ' io_r_src_point.dock_num[' || io_r_src_point.dock_num || ']'
            || ' io_r_dest_point.dock_num[' || io_r_dest_point.dock_num || ']'
            || ' io_r_src_point.point[' || io_r_src_point.point || ']'
            || ' io_r_dest_point.point[' || io_r_dest_point.point || ']'
            || '  A point type or area (section) or dock parameter'
            || ' is null.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                        l_message, pl_exc.ct_data_error,
                        NULL, 'LABOR', gl_pkg_name);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
      WHEN OTHERS THEN
         l_message := gl_pkg_name || '.' || l_object_name
            || ' io_r_src_point.pt_type[' || io_r_src_point.pt_type || ']'
            || ' io_r_dest_point.pt_type[' || io_r_dest_point.pt_type || ']'
            || ' io_r_src_point.area[' || io_r_src_point.area || ']'
            || ' io_r_dest_point.area[' || io_r_dest_point.area || ']'
            || ' io_r_src_point.dock_num[' || io_r_src_point.dock_num || ']'
            || ' io_r_dest_point.dock_num[' || io_r_dest_point.dock_num || ']'
            || ' io_r_src_point.point[' || io_r_src_point.point || ']'
            || ' io_r_dest_point.point[' || io_r_dest_point.point || ']';

         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                           l_message,
                           SQLCODE, SQLERRM ,'LABOR', gl_pkg_name);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM, 'LABOR', gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;
   END set_travel_docks;



   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_pt_to_pt_dist
   --
   -- Description:
   --    This procedure calculates the distance between two points.
   --
   -- Parameters:
   --    i_src_point        - Starting point.
   --    i_dest_point       - Ending point.
   --    i_equip_rec        - Equipment tmu values.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --    io_dist_rec        - Distance traveled.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an user
   --                                 defined error.
   --    pl_exc.e_database_error    - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/14/01 prpbcb   Created.  
   --
   --    09/14/01 prpbcb   History from PRO*C program:
   --    06/23/99 prpbcb   Added call to function lmd_segment_distance.  
   --                      As things stand now a point to point distance will
   --                      have only one accelerate and one decelerate distance.
   --    08/13/01 prpbcb   Added assignment of the turn into aisle (TIA) time.
   --                      It used to be in lm_goaltime.pc
   --
   ---------------------------------------------------------------------------
   PROCEDURE get_pt_to_pt_dist
                (i_src_point                  IN     VARCHAR2,
                 i_dest_point                 IN     VARCHAR2,
                 i_equip_rec                  IN     pl_lmc.t_equip_rec,
                 i_follow_aisle_direction_bln IN     BOOLEAN,
                 io_dist_rec                  IN OUT pl_lmc.t_distance_rec)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_pt_to_pt_dist';

      l_areas_are_different BOOLEAN := FALSE; -- Denotes if the source and
                                              -- destination areas are different
      l_docks_are_different BOOLEAN := FALSE; -- Denotes if the source and
                                              -- destination docks are different
      l_dest_pt                   t_point_info_rec; -- Dest. point info
      l_dist                      NUMBER;     -- A point to point distance
      l_include_accel_decel_flag  VARCHAR2(1);
      l_src_pt                    t_point_info_rec;  -- Source point info

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name ||
               '(i_src_point[' || i_src_point || ']' ||
               ',i_dest_point[' || i_dest_point || ']' ||
               ',i_equip_rec.equip_id[' || i_equip_rec.equip_id || ']' ||
               ',i_follow_aisle_direction_bln[' || l_message || ']' ||
               ',io_dist_rec)';
       
      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (pl_lma.g_audit_bln) THEN
         l_message := '*** Get Point to Point Distance  ' || i_src_point ||
                    ' -> ' || i_dest_point || ' ***';
         pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

      l_src_pt.point := i_src_point;
      l_dest_pt.point := i_dest_point;

      -- Clear the distance record.
      io_dist_rec.accel_distance   := 0;
      io_dist_rec.decel_distance   := 0;
      io_dist_rec.travel_distance  := 0;
      io_dist_rec.total_distance   := 0;
      io_dist_rec.tia_time         := 0;
      io_dist_rec.distance_time    := 0;

      -- Get the point type of the source point and the dock it is on.
      pl_lmd.get_point_type(l_src_pt.point, l_src_pt.pt_type,
                            l_src_pt.dock_num);

      -- Get the point type of the destination point and the dock it is on.
      pl_lmd.get_point_type(l_dest_pt.point, l_dest_pt.pt_type,
                            l_dest_pt.dock_num);

      -- The area is the first character in the dock number.
      l_src_pt.area := SUBSTR(l_src_pt.dock_num,1,1);
      l_dest_pt.area := SUBSTR(l_dest_pt.dock_num,1,1);

      IF (l_src_pt.dock_num = l_dest_pt.dock_num) THEN
         l_docks_are_different := FALSE;
      ELSE
	 l_docks_are_different := TRUE;
      END IF;

      IF (l_src_pt.area = l_dest_pt.area) THEN
         l_areas_are_different := FALSE;
      ELSE
         l_areas_are_different := TRUE;
      END IF;

      -- Give turn into aisle time when appropriate.
      IF ( (l_src_pt.pt_type = ct_pt_type_door AND l_dest_pt.pt_type = ct_pt_type_bay)
        OR (l_src_pt.pt_type = ct_pt_type_bay AND l_dest_pt.pt_type = ct_pt_type_door)
        OR (l_src_pt.pt_type = ct_pt_type_aisle AND l_dest_pt.pt_type = ct_pt_type_bay)
        OR (l_src_pt.pt_type = ct_pt_type_bay AND l_dest_pt.pt_type = ct_pt_type_aisle))
      THEN
         io_dist_rec.tia_time := io_dist_rec.tia_time + i_equip_rec.tia;

         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_movement('TIA', 1, NULL, pl_lma.ct_detail_level_1);
         END IF;  -- end audit

      ELSIF ((l_src_pt.pt_type = ct_pt_type_bay) AND
             (l_dest_pt.pt_type = ct_pt_type_bay) AND
             (l_src_pt.point = l_dest_pt.point)) THEN
         io_dist_rec.tia_time := io_dist_rec.tia_time + (i_equip_rec.tia * 2);

         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_movement('TIA', 1, NULL, pl_lma.ct_detail_level_1);
            pl_lma.audit_movement('TIA', 1, NULL, pl_lma.ct_detail_level_1);
         END IF;  -- end audit
      END IF;

      IF (l_areas_are_different = FALSE) THEN
         -- The source and destination points are in the same area.
         -- The docks may be different.
         l_message := l_object_name || '  src type=' || l_src_pt.pt_type ||
            '  dest type=' || l_dest_pt.pt_type;

         pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);
  
         l_dist := f_get_same_area_dist(l_src_pt, l_dest_pt,
                                        i_follow_aisle_direction_bln);

      ELSE
         -- The source and destination points are in different areas 
         -- which also means they are on different docks.
         l_dist := f_get_diff_area_dist(l_src_pt, l_dest_pt,
                                        i_follow_aisle_direction_bln);
      END IF;

      -- Determine the accelerate and decelerate distance.
      io_dist_rec.total_distance := l_dist;
      segment_distance(io_dist_rec);  

      l_message := l_object_name ||
         '  total distance=' || TO_CHAR(io_dist_rec.total_distance) ||
         '  accel  distance=' || TO_CHAR(io_dist_rec.accel_distance) ||
         '  decel distance=' ||  TO_CHAR(io_dist_rec.decel_distance) ||
         '  travel distance=' || TO_CHAR(io_dist_rec.travel_distance) ||
         '  distance time=' || TO_CHAR(io_dist_rec.distance_time);

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END get_pt_to_pt_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_same_area_dist
   --
   -- Description:
   --    This function calculates the distance between two points in the
   --    same area.
   --
   -- Parameters:
   --    i_src_pt_rec   - Source point information.
   --    i_dest_pt_rec  - Destination point information.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_pt  - Unable to identify the point type.
   --    User defined exception           - A called object returned an user
   --                                       defined error.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/16/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_same_area_dist
               (i_src_pt_rec                 IN t_point_info_rec, 
                i_dest_pt_rec                IN t_point_info_rec,
                i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message         VARCHAR2(512);    -- Message buffer
      l_message_param   VARCHAR2(512);    -- Message buffer
      l_object_name     VARCHAR2(61) := gl_pkg_name || '.f_get_same_area_dist';

      l_dist  NUMBER;    -- Distance between the points.

      e_unhandled_dest_pt_type  EXCEPTION;  -- Destination point type not
                                            -- handled by this function.
      e_unhandled_src_pt_type   EXCEPTION;  -- Source point type not
                                            -- handled by this function.

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name || '(i_src_pt_rec,i_dest_pt_rec' ||
         ',i_follow_aisle_direction[' || l_message || '])' ||
         ' i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
         ' i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
         ' i_src_pt_rec.area[' || i_src_pt_rec.area || ']' ||
         ' i_dest_pt_rec.area[' || i_dest_pt_rec.area || ']' ||
         ' i_src_pt_rec.dock_num[' || i_src_pt_rec.dock_num || ']' ||
         ' i_dest_pt_rec.dock_num[' || i_dest_pt_rec.dock_num || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (i_src_pt_rec.pt_type = ct_pt_type_door) THEN
         -----------------------------------
         -- Source point is a door.
         -----------------------------------
         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Door to Door
            l_dist := pl_lmd.f_get_door_to_door_dist(i_src_pt_rec.dock_num,
                                                     i_dest_pt_rec.dock_num,
                                                     i_src_pt_rec.point,
                                                     i_dest_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Door to Aisle
            l_dist := pl_lmd.f_get_door_to_aisle_dist(i_src_pt_rec.dock_num,
                                                      i_src_pt_rec.point,
                                                      i_dest_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Door to Bay
            l_dist := pl_lmd.f_get_door_to_bay_dist
                                         (i_src_pt_rec.dock_num,
                                          i_src_pt_rec.point,
                                          i_dest_pt_rec.point,
                                          i_follow_aisle_direction_bln);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Door to Pickup Point
            l_dist := pl_lmd.f_get_door_to_pup_dist(i_src_pt_rec.dock_num,
                                                    i_src_pt_rec.point,
                                                    i_dest_pt_rec.point);
         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_aisle) THEN
         -----------------------------------
         -- Source point is an aisle.
         -----------------------------------
         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Aisle to Door
            l_dist := pl_lmd.f_get_door_to_aisle_dist(i_dest_pt_rec.dock_num,
                                                      i_dest_pt_rec.point,
                                                      i_src_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Aisle to Aisle
            l_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_src_pt_rec.dock_num,
                                                           i_src_pt_rec.point,
                                                           i_dest_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Aisle to Bay
            l_dist := pl_lmd.f_get_aisle_to_bay_dist
                                         (i_src_pt_rec.dock_num,
                                          i_src_pt_rec.point,
                                          i_dest_pt_rec.point,
                                          i_follow_aisle_direction_bln);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Aisle to Pickup Point
            l_dist := pl_lmd.f_get_pup_to_aisle_dist(i_src_pt_rec.dock_num,
                                                     i_dest_pt_rec.point,
                                                     i_src_pt_rec.point);
         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_bay) THEN
         -----------------------------------
         -- Source point is a bay.
         -----------------------------------
         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Bay to Door
            l_dist := pl_lmd.f_get_door_to_bay_dist
                                       (i_dest_pt_rec.dock_num,
                                        i_dest_pt_rec.point,
                                        i_src_pt_rec.point,
                                        i_follow_aisle_direction_bln);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Bay to Aisle
            l_dist := pl_lmd.f_get_aisle_to_bay_dist(i_src_pt_rec.dock_num,
                                                     i_dest_pt_rec.point,
                                                     i_src_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Bay to Bay
            IF (i_src_pt_rec.point < i_dest_pt_rec.point) THEN
               l_dist := pl_lmd.f_get_bay_to_bay_dist
                                         (i_src_pt_rec.dock_num,
                                          i_src_pt_rec.point,
                                          i_dest_pt_rec.point,
                                          i_follow_aisle_direction_bln);
            ELSE
               l_dist := pl_lmd.f_get_bay_to_bay_dist(i_src_pt_rec.dock_num,
                                                      i_dest_pt_rec.point,
                                                      i_src_pt_rec.point);
            END IF;
         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_pup) THEN
         -----------------------------------
         -- Source point is a pickup point.
         -----------------------------------

         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Pickup Point to Door
            l_dist := pl_lmd.f_get_door_to_pup_dist(i_src_pt_rec.dock_num,
                                                    i_dest_pt_rec.point,
                                                    i_src_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Pickup Point to Aisle
            l_dist := pl_lmd.f_get_pup_to_aisle_dist(i_src_pt_rec.dock_num,
                                                     i_src_pt_rec.point,
                                                     i_dest_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Pickup Point to Pickup Point
            l_dist := pl_lmd.f_get_pup_to_pup_dist(i_src_pt_rec.dock_num,
                                                   i_src_pt_rec.point,
                                                   i_dest_pt_rec.point);
         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Pickup Point to Bay
            l_dist := pl_lmd.f_get_pup_to_bay_dist
                                         (i_src_pt_rec.dock_num,
                                          i_src_pt_rec.point,
                                          i_dest_pt_rec.point,
                                          i_follow_aisle_direction_bln);
         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;
      ELSE
         -- Have an unhandled source point type.
         RAISE e_unhandled_src_pt_type;
      END IF;

      RETURN(l_dist);

   EXCEPTION
      WHEN e_unhandled_src_pt_type THEN
         l_message := l_object_name ||
            ': Unhandled source point type.' ||
            '  i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
            '  i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
            '  i_src_pt_rec.pt_type[' || i_src_pt_rec.pt_type || ']' ||
            '  i_dest_pt_rec.pt_type[' || i_dest_pt_rec.pt_type || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_pt, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_pt, l_message);

      WHEN e_unhandled_dest_pt_type THEN
         l_message := l_object_name ||
            ': Unhandled destination point type.' ||
            '  i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
            '  i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
            '  i_src_pt_rec.pt_type[' || i_src_pt_rec.pt_type || ']' ||
            '  i_dest_pt_rec.pt_type[' || i_dest_pt_rec.pt_type || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_pt, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_pt, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_same_area_dist;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_diff_area_dist
   --
   -- Description:
   --    This function calculates the distance between two points that are
   --    in different areas.
   --
   -- Parameters:
   --    i_src_pt_rec   - Source point information.
   --    i_dest_pt_rec  - Destination point information.
   --    i_follow_aisle_direction_bln - This designates if travel can only
   --                           be in the aisle direction or if travel is
   --                           allowed up or down the aisle.  A selector can
   --                           travel only in the aisle direction.  A forklift
   --                           can travel in either direction on an aisle.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_pt_dist_badsetup_pt  - Unable to identify the point type.
   --    User defined exception           - A called object returned an user
   --                                       defined error.
   --    pl_exc.e_database_error          - Any other error.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/17/01 prpbcb   Created.  
   ---------------------------------------------------------------------------
   FUNCTION f_get_diff_area_dist
               (i_src_pt_rec                 IN t_point_info_rec, 
                i_dest_pt_rec                IN t_point_info_rec,
                i_follow_aisle_direction_bln IN BOOLEAN DEFAULT FALSE)
   RETURN NUMBER IS
      l_message       VARCHAR2(512);    -- Message buffer
      l_message_param VARCHAR2(512);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_get_diff_area_dist';

      l_dist          NUMBER := 0;    -- Distance between points.
      l_w_dist        NUMBER := 0;    -- Distance between points.
      l_first_aisle   point_distance.point_a%TYPE;
      l_first_door    point_distance.point_a%TYPE;

      e_unhandled_dest_pt_type  EXCEPTION;  -- Destination point type not
                                            -- handled by this function.
      e_unhandled_src_pt_type   EXCEPTION;  -- Source point type not
                                            -- handled by this function.

   BEGIN

      IF (i_follow_aisle_direction_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;
       
      l_message_param := l_object_name || '(i_src_pt_rec,i_dest_pt_rec' ||
         ',i_follow_aisle_direction[' || l_message || '])' ||
         ' i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
         ' i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
         ' i_src_pt_rec.area[' || i_src_pt_rec.area || ']' ||
         ' i_dest_pt_rec.area[' || i_dest_pt_rec.area || ']' ||
         ' i_src_pt_rec.dock_num[' || i_src_pt_rec.dock_num || ']' ||
         ' i_dest_pt_rec.dock_num[' || i_dest_pt_rec.dock_num || ']';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      IF (i_src_pt_rec.pt_type = ct_pt_type_door) THEN
         -----------------------------------------
         -- The source point is a door.
         -----------------------------------------

         -- Get the door on the source dock that is closest
         -- to the destination dock and get the distance from this door
         -- to the travel lane.
         pl_lmd.get_whse_to_door_dist(i_dest_pt_rec.dock_num,
                                      i_src_pt_rec.dock_num,
                                      l_first_door,
                                      l_w_dist);

         -- Get the distance from the source door to the door on the
         -- source dock that is closest to the destination dock.
         l_dist := pl_lmd.f_get_door_to_door_dist(i_src_pt_rec.dock_num,
                                                  i_src_pt_rec.dock_num,
                                                  i_src_pt_rec.point,
                                                  l_first_door);
         l_dist := l_dist + l_w_dist;

         -- Get the distance between the source and destination docks.
         l_w_dist := pl_lmd.f_get_whse_to_whse_dist
                                                (i_src_pt_rec.dock_num,
                                                 i_dest_pt_rec.dock_num);
         l_dist := l_dist + l_w_dist;

         -- At this point we have calculated the distance from the source
         -- door to the point in the travel lane where we are just entering
         -- the destination dock.  We now need to get the distance from
         -- this "entrance" point to the destination point.

         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Door to Door distance.
            -- The destination point is a door.

            -- Get the door on the destination dock that is closest
            -- to the source dock and get the distance from this door to
            -- the travel lane.
            pl_lmd.get_whse_to_door_dist(i_src_pt_rec.dock_num,
                                         i_dest_pt_rec.dock_num,
                                         l_first_door,
                                         l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination door to the door on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_door_to_door_dist(i_dest_pt_rec.dock_num,
                                                       i_dest_pt_rec.dock_num,
                                                       l_first_door,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Door to Aisle distance.
            -- The destination point is an aisle.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination aisle to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dest_pt_rec.dock_num,
                                                         l_first_aisle,
                                                         i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Door to Bay distance.
            -- The destination point is a bay.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination bay to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dest_pt_rec.dock_num,
                                                       l_first_aisle,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Door to Pickup Point distance.
            -- The destination point is a pickup point.

            -- Get the distance from the destination pickup point to the point
            -- in the travel lane where we are just entering the destination
            -- dock.
            l_w_dist := pl_lmd.get_whse_to_pup_dist(i_dest_pt_rec.dock_num,
                                                    i_dest_pt_rec.point,
                                                    i_src_pt_rec.dock_num);
            l_dist := l_dist + l_w_dist;

         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_aisle) THEN
         -----------------------------------------
         -- The source point is an aisle.
         -----------------------------------------

         -- Get the aisle on the source dock that is closest
         -- to the destination dock and get the distance from this aisle
         -- to the travel lane.
         pl_lmd.get_whse_to_aisle_dist(i_dest_pt_rec.dock_num,
                                       i_src_pt_rec.dock_num,
                                       l_first_aisle,
                                       l_w_dist);

         -- Get the distance from the source aisle to the aisle on the
         -- source dock that is closest to the destination dock.
         l_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_src_pt_rec.dock_num,
                                                    i_src_pt_rec.point,
                                                    l_first_aisle);
         l_dist := l_dist + l_w_dist;

         -- Get the distance between the source and destination docks.
         l_w_dist := pl_lmd.f_get_whse_to_whse_dist(i_src_pt_rec.dock_num,
                                                    i_dest_pt_rec.dock_num);
         l_dist := l_dist + l_w_dist;

         -- At this point we have calculated the distance from the source
         -- aisle to the point in the travel lane where we are just entering
         -- the destination dock.  We now need to get the distance from
         -- this "entrance" point to the destination point.

         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Aisle to Door distance.
            -- The destination point is a door.

            -- Get the door on the destination dock that is closest
            -- to the source dock and get the distance from this door to
            -- the travel lane.
            pl_lmd.get_whse_to_door_dist(i_src_pt_rec.dock_num,
                                         i_dest_pt_rec.dock_num,
                                         l_first_door,
                                         l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination door to the door on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_door_to_door_dist(i_dest_pt_rec.dock_num,
                                                       i_dest_pt_rec.dock_num,
                                                       l_first_door,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Aisle to Aisle distance.
            -- The destination point is an aisle.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination aisle to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dest_pt_rec.dock_num,
                                                         l_first_aisle,
                                                         i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Aisle to Bay distance.
            -- The destination point is a bay.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination bay to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dest_pt_rec.dock_num,
                                                       l_first_aisle,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Aisle to Pickup Point distance.
            -- The destination point is a pickup point.

            -- Get the distance from the destination pickup point to the point
            -- in the travel lane where we are just entering the destination
            -- dock.
            l_w_dist := pl_lmd.get_whse_to_pup_dist(i_dest_pt_rec.dock_num,
                                                    i_dest_pt_rec.point,
                                                    i_src_pt_rec.dock_num);
            l_dist := l_dist + l_w_dist;

         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_bay) THEN
         -----------------------------------------
         -- The source point is a bay.
         -----------------------------------------

         -- Get the aisle on the source dock that is closest to the
         -- destination dock and get the distance from this aisle to
         -- the travel lane.
         pl_lmd.get_whse_to_aisle_dist(i_dest_pt_rec.dock_num,
                                       i_src_pt_rec.dock_num,
                                       l_first_aisle,
                                       l_w_dist);

         -- Get the distance from the source bay to the aisle on the
         -- source dock that is closest to the destination dock.
         l_dist := pl_lmd.f_get_aisle_to_bay_dist(i_src_pt_rec.dock_num,
                                                  l_first_aisle,
                                                  i_src_pt_rec.point);
         l_dist := l_dist + l_w_dist;

         -- Get the distance between the source and destination docks.
         l_w_dist := pl_lmd.f_get_whse_to_whse_dist(i_src_pt_rec.dock_num,
                                                    i_dest_pt_rec.dock_num);
         l_dist := l_dist + l_w_dist;

         -- At this point we have calculated the distance from the source
         -- bay to the point in the travel lane where we are just entering
         -- the destination dock.  We now need to get the distance from
         -- this "entrance" point to the destination point.

         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Bay to Door distance.
            -- The destination point is a door.

            -- Get the door on the destination dock that is closest
            -- to the source dock and get the distance from this door
            -- to the travel lane.
            pl_lmd.get_whse_to_door_dist(i_src_pt_rec.dock_num,
                                         i_dest_pt_rec.dock_num,
                                         l_first_door,
                                         l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination door to the door on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_door_to_door_dist(i_dest_pt_rec.dock_num,
                                                       i_dest_pt_rec.dock_num,
                                                       l_first_door,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Bay to Aisle distance.
            -- The destination point is an aisle.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle
            -- to the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination aisle to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dest_pt_rec.dock_num,
                                                         l_first_aisle,
                                                         i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Bay to Bay distance.
            -- The destination point is a bay.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            l_w_dist := pl_lmd.f_get_aisle_to_bay_dist
                                                 (i_dest_pt_rec.dock_num,
                                                  l_first_aisle,
                                                  i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Bay to Pickup Point distance.
            -- The destination point is a pickup point.

            -- Get the distance from the destination pickup point to the point
            -- in the travel lane where we are just entering the destination
            -- dock.
            l_w_dist := pl_lmd.get_whse_to_pup_dist(i_dest_pt_rec.dock_num,
                                                    i_dest_pt_rec.point,
                                                    i_src_pt_rec.dock_num);
            l_dist := l_dist + l_w_dist;

         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSIF (i_src_pt_rec.pt_type = ct_pt_type_pup) THEN
         -----------------------------------------
         -- The source point is a pickup point.
         -----------------------------------------

         -- Get the distance from the pickup point to the point in the travel
         -- lane where we are just leaving the source dock on the way to
         -- the destination dock.
         l_w_dist := pl_lmd.get_whse_to_pup_dist(i_src_pt_rec.dock_num,
                                                 i_src_pt_rec.point,
                                                 i_dest_pt_rec.dock_num);

         -- Get the distance between the source and destination docks.
         l_dist := pl_lmd.f_get_whse_to_whse_dist(i_src_pt_rec.dock_num,
                                                    i_dest_pt_rec.dock_num);
         l_dist := l_dist + l_w_dist;

         -- At this point we have calculated the distance from the source
         -- pickup point to the point in the travel lane where we are just
         -- entering the destination dock.  We now need to get the distance
         -- from this "entrance" point to the destination point.

         IF (i_dest_pt_rec.pt_type = ct_pt_type_door) THEN
            -- Pickup Point to Door
            -- The destination point is a door.

            -- Get the door on the destination dock that is closest
            -- to the source dock and get the distance from this door to
            -- the travel lane.
            pl_lmd.get_whse_to_door_dist(i_src_pt_rec.dock_num,
                                         i_dest_pt_rec.dock_num,
                                         l_first_door,
                                         l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination door to the door on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_door_to_door_dist(i_dest_pt_rec.dock_num,
                                                       i_dest_pt_rec.dock_num,
                                                       l_first_door,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_aisle) THEN
            -- Pickup Point to Aisle
            -- The destination point is an aisle.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination aisle to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_aisle_dist(i_dest_pt_rec.dock_num,
                                                         l_first_aisle,
                                                         i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_bay) THEN
            -- Pickup Point to Bay
            -- The destination point is a bay.

            -- Get the aisle on the destination dock that is closest
            -- to the source dock and get the distance from this aisle to
            -- the travel lane.
            pl_lmd.get_whse_to_aisle_dist(i_src_pt_rec.dock_num,
                                          i_dest_pt_rec.dock_num,
                                          l_first_aisle,
                                          l_w_dist);
            l_dist := l_dist + l_w_dist;

            -- Get the distance from the destination bay to the aisle on the
            -- destination dock that is closest to the source dock.
            l_w_dist := pl_lmd.f_get_aisle_to_bay_dist(i_dest_pt_rec.dock_num,
                                                       l_first_aisle,
                                                       i_dest_pt_rec.point);
            l_dist := l_dist + l_w_dist;

         ELSIF (i_dest_pt_rec.pt_type = ct_pt_type_pup) THEN
            -- Pickup Point to Pickup Point
            -- The destination point is a pickup point.

            -- Get the distance from the destination pickup point to the point
            -- in the travel lane where we are just entering the destination
            -- dock.
            l_w_dist := pl_lmd.get_whse_to_pup_dist(i_dest_pt_rec.dock_num,
                                                    i_dest_pt_rec.point,
                                                    i_src_pt_rec.dock_num);
            l_dist := l_dist + l_w_dist;

         ELSE
            -- Have an unhandled destination point type.
            RAISE e_unhandled_dest_pt_type;
         END IF;

      ELSE
         -- Have an unhandled source point type.
         RAISE e_unhandled_src_pt_type;
      END IF;

      RETURN(l_dist);

   EXCEPTION
      WHEN e_unhandled_src_pt_type THEN
         l_message := l_object_name || ': Unhandled source point type' ||
            '  i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
            '  i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
            '  i_src_pt_rec.pt_type[' || i_src_pt_rec.pt_type || ']' ||
            '  i_dest_pt_rec.pt_type[' || i_dest_pt_rec.pt_type || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_pt, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_pt, l_message);

      WHEN e_unhandled_dest_pt_type THEN
         l_message := l_object_name || ': Unhandled destination point type' ||
            '  i_src_pt_rec.point[' || i_src_pt_rec.point || ']' ||
            '  i_dest_pt_rec.point[' || i_dest_pt_rec.point || ']' ||
            '  i_src_pt_rec.pt_type[' || i_src_pt_rec.pt_type || ']' ||
            '  i_dest_pt_rec.pt_type[' || i_dest_pt_rec.pt_type || ']';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_lm_pt_dist_badsetup_pt, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_lm_pt_dist_badsetup_pt, l_message);

      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END f_get_diff_area_dist;


---------------------------------------------------------------------------
-- Procedure:
--    get_next_point
--
-- Description:
--    This function fetches the ending point for the batch being completed.
--    The ending point will be one of the following:
--       - The kvi_from_loc of the batch the user is signing onto.
--       - The kvi_to_loc of the batch the user is signing onto.
--       - The last completed drop point of a suspended batch which the user
--         is in the process of reattaching to.
--
--    Look for last scanned batch first--status = N.  This is the batch
--    the user is in the process of signing onto.  Earlier in the batch
--    completion process the status was updated to N.
--
--    If no N status batch is found then look for a suspended batch--status = W.
--    A suspended batch is a batch for the tasks not completed when the
--    opertor broke away to perform another batch such as replenishments during
--    putaway.  When the operator finishes these other batches the RF will
--    return back to the tasks not yet completed.  The operator is then made
--    active on the suspended batch with the task is completed.  When a user is
--    in the process of reattaching to a W batch the user should not have an
--    N batch.  The program that calls lmf_signon_to_forklift_batch() in
--    lm_forklift.pc checks for a suspended batch and if one find then will
--    pass the suspended batch number to lmf_signon_to_forklift_batch().
--    An example of this is in putaway.pc.
--
--    Example of a W status batch:
--       An example of having a W status batch is a NDM
--       performed during a two pallet multi-pallet putaway after dropping the
--       first pallet.  The batch for the first pallet putaway will be
--       completed with a haul batch created for the second pallet and merged
--       to the putaway for the first pallet.  The second pallet putaway batch
--       will have the status udpated to W and because it is now the only
--       putaway not done the parent batch number is cleared.
--
-- Parameters:
--    i_batch_no         - The labor batch being completed.
--    i_user_id          - User performing the task.
--    o_point            - The ending point.  If the user has no N or W
--                         status batch then o_point will be set to null.
--                          
-- 
--
-- Exceptions raised:
--    User defined exception     - A called object returned an user
--                                 defined error.
--    pl_exc.e_data_error        - A parameter is null.
--    pl_exc.e_database_error    - Any other error.
--
-- Called by:
--    lm_distance.pc  Function lmd_get_next_point().
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/01/10 prpbcb   Created.  
--                      It is a PL/SQL version of function
--                      lmd_get_next_point() in lm_distance.pc modified
--                      for the new process of completing and not suspending
--                      a batch when the user breaks away to another task.
--
---------------------------------------------------------------------------
PROCEDURE get_next_point
                (i_batch_no        IN  arch_batch.batch_no%TYPE,
                 i_user_id         IN  arch_batch.user_id%TYPE,
                 o_point           OUT arch_batch.kvi_from_loc%TYPE)
IS
   l_message        VARCHAR2(310);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'get_next_point';

   l_batch_no      arch_batch.batch_no%TYPE;  -- The batch the user will be
                                              -- signing onto.
   l_kvi_from_loc  arch_batch.kvi_from_loc%TYPE; -- from loc for l_batch_no
   l_kvi_to_loc    arch_batch.kvi_to_loc%TYPE;   -- to loc for l_batch_no

   l_3_part_move_bln BOOLEAN := FALSE;  -- Designates if 3 part move for demand
                               -- replenishments is active.  For any other type
                               -- of forklift batch the value will be FALSE.
                               -- If TRUE and the batch about to be signed onto
                               -- is a demand repl then o_point is set to
                               -- kvi_to_loc otherwise o_point is set to
                               -- kvi_from_loc.

   l_found_suspended_batch_bln  BOOLEAN:= FALSE; -- Denotes if user has a
                                                 -- suspended batch.  It is
                                                 -- used when creating an audit
                                                 -- message.
BEGIN
   --
   -- Check for null parameters.
   --
   IF (   i_batch_no        IS NULL
       OR i_user_id         IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Look for the last scanned batch which has been previously marked by
   -- setting the status to 'N' (for new).  This 'N' batch is the batch the
   -- user will be signing onto.  If no 'N' status batch then look for a
   -- suspended batch.
   --
   pl_lmf.get_new_batch(i_user_id, l_batch_no, l_kvi_from_loc, l_kvi_to_loc);

   IF (l_batch_no IS NULL ) THEN
      --
      -- Found no 'N' batch for the user.  Look for a suspended batch.
      --
      pl_lmf.get_suspended_batch(i_user_id, l_batch_no, l_kvi_from_loc,
                                 l_kvi_to_loc);

      IF (l_batch_no IS NOT NULL) THEN
         --
         -- Found suspended batch for the user.  The user will be made
         -- active on this batch after the current batch is completed.
         -- l_kvi_from_loc will be the ending point of the batch being
         -- completed.
         --
         l_found_suspended_batch_bln := TRUE;
      ELSE
         --
         -- Found no suspended batch for the user.
         -- If this point reached then we assume the user is signing onto
         -- an indirect batch.  Set o_point to NULL.  The calling function
         -- will handle the o_point being null appropriately.
         --
         -- 07/14/03 prpbcb  Changes have been made when signing onto an
         -- indirect using task assign on the CRT or RF to update the status
         -- of the indirect batch to 'N' so ideally this point should not be
         -- reached.  If for whatever reason this point is reached then
         -- warning aplog messages are written and processing will continue.
         --
         --
         o_point := NULL;

         l_message := 
                'i_batch_no[' || i_batch_no || ']'
             || '  i_user_id[' || i_user_id || ']'
             || '  Found no N or suspended batch for the user.'
             || '  This is interpreted as the user is signing onto an'
             || ' indirect.'
             || '  Travel distance to the indirect batch source location will'
             || ' not be given to the operator.';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                        l_message, NULL, NULL, 'LABOR', gl_pkg_name);
      END IF;
   END IF;

   IF (l_batch_no IS NOT NULL) THEN
      --
      -- Found the batch the user will be signing onto and the from and to
      -- locations.
      -- Determine the next point.
      --
      -- If the batch being signed onto is a demand repl and the batch
      -- being completed is not a demand repl then get the 3_PART_MOVE syspar
      -- as it determines if the ending point of the batch being completed
      -- is the kvi_from_loc or the kvi_to_loc of the batch being signed
      -- onto.
      --

      IF (pl_lmc.get_batch_type(l_batch_no) = pl_lmc.ct_forklift_demand_rpl)
      THEN
         --
         -- The batch the user will be signing onto is a demand replenishment
         -- batch.
         --
         IF (pl_lmc.is_three_part_move_active(l_kvi_to_loc) = TRUE) THEN
            --
            -- Three part move for demand replenishments is active.
            --
            l_3_part_move_bln := TRUE;
            o_point := l_kvi_to_loc;

            --
            -- Create forklift audit record if auditing is on.
            --
            IF (pl_lma.g_audit_bln) THEN
               l_message := 'The next batch ' || l_batch_no || ' is a demand'
                || ' replenishment and 3 part move is active for the pallet'
                || ' type.  The ending point for batch '
                || i_batch_no || ' is the home slot of the demand'
                || ' replenishment which is ' || l_kvi_to_loc || '.';

               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                   pl_lma.ct_detail_level_1);
            END IF;
         ELSE
            --
            -- Three part move for demand replenishments is not active.
            --
            o_point := l_kvi_from_loc;
         END IF;
      ELSE
         --
         -- The batch the user will be signing onto is NOT a demand
         -- replenishment batch.
         --
         o_point := l_kvi_from_loc;
      END IF;

      --
      -- Create forklift audit message if auditing is turned on.
      --
      IF (pl_lma.g_audit_bln) THEN
         IF (l_found_suspended_batch_bln = TRUE) THEN
            l_message := 'User has suspended batch ' || l_batch_no
               || ' as a result of a break away'
               || ' which the user will be made active on again.  The'
               || ' pallet(s) for the suspended batch were dropped by'
               || ' location ' || o_point || ' which will be the ending point'
               || ' of batch ' || i_batch_no || '.';

            pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                             pl_lma.ct_detail_level_1);
         ELSE
            l_message := 'The ending point of batch ' || i_batch_no
               || ' will be ' || o_point
               || ' which is the first point of the next batch '
               || l_batch_no || '.';

            pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                             pl_lma.ct_detail_level_1);
         END IF;
      END IF;
   END IF;  -- end IF (l_batch_no IS NOT NULL) THEN

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_batch_no[' || i_batch_no || '],'
             || 'i_user_id[' || i_user_id || '],'
             ||  'o_point)  An input parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                        l_message, pl_exc.ct_data_error,
                        NULL, 'LABOR', gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      l_message := gl_pkg_name || '.' || l_object_name
             || '(i_batch_no[' || i_batch_no || '],'
             || 'i_user_id[' || i_user_id || '],'
             ||  'o_point)';

      IF (SQLCODE <= -20000) THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                        l_message,
                        SQLCODE, SQLERRM ,'LABOR', gl_pkg_name);
         RAISE;
      ELSE
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM, 'LABOR', gl_pkg_name);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);
      END IF;
END get_next_point;


END pl_lmd;  -- end package body
/

show errors


