create or replace PACKAGE PL_LM_DISTANCE AS 

   FUNCTION lmd_get_door_to_bay_dist (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_bay      IN            bay_distance.bay%TYPE,
        o_dist        IN OUT           lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_dr_to_bay_direct_dist (
        i_dock_num       IN               point_distance.point_dock%TYPE,
        i_from_door      IN               point_distance.point_a%TYPE,
        i_to_bay         IN               bay_distance.bay%TYPE,
        i_min_bay        IN               VARCHAR2,
        i_max_bay        IN               VARCHAR2,
        i_min_bay_dist   IN               NUMBER,
        i_max_bay_dist   IN               NUMBER,
        o_dist           OUT              lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_bay_to_bay_dist (
        i_dock_num   IN           point_distance.point_dock%TYPE,
        i_from_bay   IN           bay_distance.bay%TYPE,
        i_to_bay     IN           bay_distance.bay%TYPE,
        o_dist       OUT          lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_b2b_on_aisle_dist (
        i_aisle      IN           bay_distance.aisle%TYPE,
        i_from_bay   IN           bay_distance.bay%TYPE,
        i_to_bay     IN           bay_distance.bay%TYPE,
        o_dist       OUT          lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_suspended_batch_dist (
        i_psz_batch_no     IN                 batch.batch_no%TYPE,
        i_psz_user_id      IN                 arch_batch.user_id%TYPE,
        i_psz_next_point   IN                 VARCHAR2,
        io_e_rec            IN  OUT               pl_lm_goal_pb.type_lmc_equip_rec,
        o_dist             OUT                lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_door_to_aisle_dist (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_aisle    IN            point_distance.point_b%TYPE,
        o_dist        OUT           lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_bay_to_end_dist (
        i_aisle   IN        bay_distance.aisle%TYPE,
        i_bay     IN        bay_distance.bay%TYPE,
        o_dist    OUT       lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_ab_angle (
        i_side_a   IN         FLOAT,
        i_side_b   IN         FLOAT,
        i_side_c   IN         FLOAT
    ) RETURN FLOAT;

    FUNCTION lmd_get_side_a_length (
        i_side_b     IN           FLOAT,
        i_side_c     IN           FLOAT,
        i_bc_angle   IN           FLOAT
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_d2d_dist_on_diff_dock (
        i_from_dock_num   IN                point_distance.point_dock%TYPE,
        i_to_dock_num     IN                point_distance.point_dock%TYPE,
        i_from_door       IN                point_distance.point_a%TYPE,
        i_to_door         IN                point_distance.point_b%TYPE,
        o_dist            OUT               lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_aisle_to_bay_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_to_bay       IN             bay_distance.bay%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_aisle_to_aisle_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_to_aisle     IN             aisle_info.name%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_check_cross_aisle_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_from_bay     IN             bay_distance.bay%TYPE,
        i_to_aisle     IN             aisle_info.name%TYPE,
        i_to_bay       IN             bay_distance.bay%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER;

 

    FUNCTION lmd_get_next_point (
        i_batch_no   IN           arch_batch.batch_no%TYPE,
        i_user_id    IN           arch_batch.user_id%TYPE,
        io_point     IN OUT       arch_batch.kvi_from_loc%TYPE
    ) RETURN NUMBER;

  PROCEDURE lmd_segment_distance (
        io_dist IN OUT lmd_distance_obj
    );

    PROCEDURE lmd_add_distance (
        io_old   IN OUT   lmd_distance_obj,
        i_new    IN       lmd_distance_obj
    );

    PROCEDURE lmd_clear_distance (
        io_dist IN OUT lmd_distance_obj
    );

    FUNCTION lmd_get_warehouse_to_wh_dist (
        i_from_dock_num      IN                   point_distance.point_dock%TYPE,
        i_to_dock_num        IN                   point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;	


    FUNCTION lmd_get_warehouse_to_door_dist (
        i_from_dock_num      IN                   point_distance.point_dock%TYPE,
        i_to_dock_num        IN                   point_distance.point_a%TYPE,
        io_first_door        IN OUT               point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_wh_to_aisle_dist (
        i_from_dock_num      IN                   point_distance.point_dock%TYPE,
        i_to_dock_num        IN                   point_distance.point_a%TYPE,
        io_first_aisle       IN OUT               point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_batch_dist (
        i_batch_no          IN                  batch.batch_no%TYPE,
        i_is_parent         IN                  VARCHAR2,
        i_e_rec             IN                  pl_lm_goal_pb.type_lmc_equip_rec,
        i_3_part_move_bln   IN                  NUMBER,
        io_last_point       IN OUT              VARCHAR2,
        io_dist             IN OUT              lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_next_point_dist (
        i_batch_no           IN                   batch.batch_no%TYPE,
        i_user_id            IN                   VARCHAR2,
        i_last_point         IN                   VARCHAR2,
        i_e_rec              IN                   pl_lm_goal_pb.type_lmc_equip_rec,
        i_3_part_move_bln    IN                   NUMBER,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_dr_to_bay_dist_dtb (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_bay      IN            bay_distance.bay%TYPE,
        o_dist        OUT           lmd_distance_obj
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_door_to_door_dist (
        i_from_door          IN                   point_distance.point_a%TYPE,
        i_to_door            IN                   point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_point_type (
        i_point        IN             point_distance.point_a%TYPE,
        o_point_type   OUT            point_distance.point_type%TYPE,
        o_dock_num     OUT            point_distance.point_dock%TYPE
    ) RETURN NUMBER;
	
    FUNCTION lmd_calc_batch_dist (
        io_b_rec             IN OUT               lmd_batch_rec_obj,
        i_e_rec             IN                pl_lm_goal_pb.type_lmc_equip_rec,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_calc_parent_dist (
        io_b_rec             IN OUT               lmd_batch_rec_obj,
        i_e_rec             IN                pl_lm_goal_pb.type_lmc_equip_rec,
        o_last_location      OUT                  batch.kvi_to_loc%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_suspended_batch (
        i_psz_batch_being_completed   IN                            arch_batch.batch_no%TYPE,
        i_psz_user_id                 IN                            arch_batch.user_id%TYPE,
        o_psz_suspended_batch_no      OUT                           arch_batch.batch_no%TYPE
    ) RETURN NUMBER;
	
    FUNCTION lmd_get_pt_to_pt_dist (
        i_src_point          IN                   VARCHAR2,
        i_dest_point         IN                   VARCHAR2,
        i_e_rec             IN                pl_lm_goal_pb.type_lmc_equip_rec,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER;

    FUNCTION lmd_get_last_drop_point (
        i_psz_batch_no          IN                      batch.batch_no%TYPE,
        o_psz_pallet_id         OUT                     floats.pallet_id%TYPE,
        o_psz_last_drop_point   OUT                     VARCHAR2
    ) RETURN NUMBER;
    
END PL_LM_DISTANCE;
/

create or replace PACKAGE BODY PL_LM_DISTANCE AS
/*********************************************************************************
**  PACKAGE:                                                                    **
**      pl_lm_distance                                                          **
**  Files                                                                       **
**      pl_lm_distance created from lm_distance.pc                              **
**                                                                              **
**  DESCRIPTION: This file contains all functions and subroutines necessary to  **
**    calculate discrete distances for Labor Management.                        **
**                                                                              **
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
**********************************************************************************/

    g_suppress_audit_message           NUMBER := 0;        /* Defined in lm_goaltime.pc.  This
                                                              variable designates if the forklift
                                                              audit message should be output.
                                                              There are cases where a function is
                                                              called that normally outputs a message
                                                              but it is better for the calling
                                                              function to output the message. */
    g_forklift_audit                   BOOLEAN := FALSE;   /* Defined in lm_goaltime.pc.  Populated
                                                              by function lmg_sel_forklift_audit_syspar. */
	
	-----------------------------CONSTANTS----------------------------------------
    C_BIG_FLOAT                        CONSTANT NUMBER       := 9999999.0;
    C_M_PI                             CONSTANT NUMBER       := 3.14;
    C_FALSE                            CONSTANT NUMBER       := 0;
    C_TRUE                             CONSTANT NUMBER       := 1;
    C_AUDIT_MSG_DIVIDER                CONSTANT VARCHAR2(60) := '------------------------------------------------------------';
    C_SWMS_NORMAL                      CONSTANT NUMBER       := 0;
    C_ORACLE_NOT_FOUND                 CONSTANT NUMBER       := 1403;
    C_NO_LM_BATCH_FOUND                CONSTANT NUMBER       := 146;
    C_DATA_ERROR                       CONSTANT NUMBER       := 80;
    C_ACCELERATE_DISTANCE              CONSTANT NUMBER       := 9.0;
    C_DECELERATE_DISTANCE              CONSTANT NUMBER       := 11.0;
    C_LM_PT_DIST_BADSETUP_WTW          CONSTANT NUMBER       := 196; /* LM Point Distance not setup. W to W */
    C_LM_PT_DIST_BADSETUP_WFD          CONSTANT NUMBER       := 197; /* LM Point Distance not setup. W to First door */
    C_LM_PT_DIST_BADSETUP_WFA          CONSTANT NUMBER       := 203; /* LM Point Distance not setup.Warehouse to first aisle */
    C_LM_PT_DIST_BADSETUP_ACA          CONSTANT NUMBER       := 201; /* LM Point Distance not setup. Cross aisle to aisle */
    C_LM_PT_DIST_BADSETUP_ATA          CONSTANT NUMBER       := 200; /* LM Point Distance not setup. aisle to aisle */
    C_LM_BAY_DIST_BAD_SETUP            CONSTANT NUMBER       := 186; /* LM Bay Distance not setup. */
    C_CROSS_AISLE_SEL_FAIL             CONSTANT NUMBER       := 187; /* Select of cross aisle failed for LM. */
    C_ST_LM_PT_DIST_BADSTUP_DTD   CONSTANT NUMBER	     := 198; /* LM Point Distance not setup. door to door*/
    C_ST_LM_PT_DIST_BADSTUP_DTA   CONSTANT NUMBER	     := 199;
    C_STATUS_LM_BAY_DIST_BAD_SETUP	   CONSTANT NUMBER	     := 186; /* LM Bay Distance not setup*/
    C_LM_PT_DIST_BADSETUP_DTD		   CONSTANT NUMBER       := 198; /* LM Point Distance not setup. door to door */
    C_LM_PT_DIST_BADSETUP_PT		   CONSTANT NUMBER       := 204; /* Point Type not setup. */
    C_FORKLIFT_BATCH_ID                CONSTANT VARCHAR2(1)  := 'F';
    C_FORKLIFT_DEMAND_RPL              CONSTANT VARCHAR2(1)  := 'R';
    C_PT_TYPE_DOOR					   CONSTANT VARCHAR2(1) := 'D';
    C_PT_TYPE_AISLE					   CONSTANT VARCHAR2(1) := 'A';
    C_PT_TYPE_BAY					   CONSTANT VARCHAR2(1) := 'B';
    C_FRONT_DOCK CONSTANT VARCHAR2(1):='F';
    C_BACK_DOCK CONSTANT VARCHAR2(1):='B';
    C_SIDE_DOCK CONSTANT VARCHAR2(1):='S';
/****************************************************************************
**  Function:  lmd_get_door_to_bay_dist
**
**  Description:
**    This subroutine finds the distance between the specified door and bay
**    on the specified dock.
**
**    In the point distance setup a door can have a distance setup to
**    one or more bays.  This allows different routes to the destination bay.
**    Usually door to bay distances are setup for docks that run parallel
**    to the aisles.
**
**    The door to bay distance will be the shortest of the following:
**       1. Door to start of the aisle (or end of the aisle if at the
**          back dock) then from the start of the aisle (or end of the aisle)
**          to the destination bay.
**       2. Shortest distance using the door to bay point distances if any
**          are setup.
**
**  Parameters:
**    i_dock_num  - Specified dock.  This needs to be the door dock number.
**    i_from_door - Specified door.
**    i_to_bay    - Specified bay.  Can either be a location or
**                  only a bay (ie. from haul).  Example: DC01, DC01A4
**    o_dist      - Distance between the door and the bay.
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_door_to_bay_dist (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_bay      IN            bay_distance.bay%TYPE,
        o_dist        IN OUT           lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val                                 NUMBER := c_swms_normal;
        l_func_name                               VARCHAR2(50) := 'lmd_get_door_to_bay_dist';
        l_message                                 VARCHAR2(4000);
        l_to_aisle              VARCHAR2(3);
        l_to_aislebay           VARCHAR2(5);
        l_door_to_aisle_dist                      lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_aisle_to_bay_dist                       lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_asl_to_bay_dist_dr_bay_dist   lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    BEGIN
    l_to_aisle:=substr(i_to_bay,1,2);
l_to_aislebay:=substr(i_to_bay,1,4);
        IF ( g_forklift_audit ) THEN
            l_message := 'Calculate door to bay distance.  Dock: '
                         || i_dock_num
                         || ' Door: '
                         || i_from_door
                         || '  Bay: '
                         || l_to_aislebay
                         || '';

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'The following distances are calculated and the shortest distance used:'
            , -1);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '- Door to start of the aisle (or end of the aisle if at the back dock) then to the destination bay.'
            , -1);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '- If door to bay distances are defined then distance from the door to the bay then to the destination bay.'
            , -1);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
        END IF;


    /*
    ** Get door to aisle distance.
    */

        l_ret_val := lmd_get_door_to_aisle_dist(i_dock_num, i_from_door, l_to_aisle, l_door_to_aisle_dist);
        IF ( l_ret_val = c_swms_normal ) THEN
        /*
        ** Get aisle to bay distance.
        */
            l_ret_val := lmd_get_aisle_to_bay_dist(i_dock_num, l_to_aisle, i_to_bay, l_aisle_to_bay_dist);
             
        /*
        ** Get the door to bay distance using door to bay 
        ** distance setup.
        */
            IF ( l_ret_val = c_swms_normal ) THEN
                l_ret_val := lmd_get_dr_to_bay_dist_dtb(i_dock_num, i_from_door, i_to_bay, l_asl_to_bay_dist_dr_bay_dist
                );
            END IF;

        /*
        ** Compare the distance going to the front(or end) of the aisle then
        ** to the bay against the distance using door to bay distances and
        ** use the shortest distance of these two distances.
        */

            IF ( l_ret_val = c_swms_normal ) THEN
                IF ( ( l_door_to_aisle_dist.total_distance + l_aisle_to_bay_dist.total_distance ) <= l_asl_to_bay_dist_dr_bay_dist.total_distance ) THEN
                    lmd_add_distance(o_dist, l_door_to_aisle_dist);
                    lmd_add_distance(o_dist, l_aisle_to_bay_dist);
                ELSE
                    lmd_add_distance(o_dist, l_asl_to_bay_dist_dr_bay_dist);
                END IF;
            END IF;

            IF ( g_forklift_audit AND l_ret_val = c_swms_normal ) THEN
                l_message := 'Door to Bay Distance  Dock: '
                             || i_dock_num
                             || ' Door: '
                             || i_from_door
                             || '  Bay: '
                             || l_to_aislebay;

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, o_dist.total_distance);
            END IF;

        END IF;

        return(l_ret_val);
    END lmd_get_door_to_bay_dist;
	
/****************************************************************************
**  Function:  lmd_get_dr_to_bay_direct_dist
**
**  Description:
**    This subroutine finds the straight line distance between the specified
**    door and bay.
**
**    By knowing the following we can calculate the distance using the
**    law of cosines.
**       1.  Distance from the door to the bay at the start of the aisle.
**       2.  Distance from the door to the bay at the end of the aisle.
**       3.  Distance from the start of the aisle to the bay in 2.
**       4.  Distance from the start of the aisle to the destination bay.
**
**   It is possible the door to bay distances setup are not direct line
**   distances which will prevent the distance from being calculated by
**   this function.  This is not an error.
**
**  Parameters:
**      i_dock_num     - Specified dock number.
**      i_from_door    - Specified door.
**      i_to_bay       - Destination bay.  It can be the complete location or
**                       just the aisle and bay (ie. from haul).
**      i_min_bay      - Lowest bay number closest to the destination bay
**                       that has a door to bay distance setup for
**                       i_from_door.  It includes the aisle and bay.
**      i_max_bay      - Highest bay number closest to the destination bay
**                       that has a door to bay distance setup for
**                       i_from_door.  It includes the aisle and bay.
**      i_min_bay_dist - Distance from i_from_door to i_min_bay.
**      i_max_bay_dist - Distance from i_from_door to i_max_bay.
**      o_dist         - Direct line distance from i_from_door to i_to_bay.
**
**      i_to_bay, i_min_bay and i_max_bay must be on the same aisle.
**                     
**
**     Sample calculation:
**
**          Steps in calculating the distance
**          from door D381 to bay DB37
**
**     1.  Distances from door D381 to bay DB01 and door D381 to bay DB99
**         are setup as door to bay distances.
**     2.  Get the distance from bay DB01 to bay DB99 using the
**         BAY_DISTANCE table.
**     3.  The angle beta between D381->DB01 and DB01->DB99 is calculated.
**     4.  Get the distance from bay DB01 to bay DB37 using the
**         BAY_DISTANCE table.
**     5.  Calculate distance from D381 to DB37 using:
**            - Distance from door D381 to bay DB01
**            - Distance from bay DB01 to bay DB37
**            - Angle beta
**
**          Door         Door         Door
**          D380         D381         D382
**  +------+====+-------+=====+------+====+------------+
**  |                      *                           |
**  |                   *   *  *                       |
**  |                *       *     *                   |
**  |             *           *        *               |
**  |          *               *           *           |
**  |       *                   *       beta   *     <--- Aisle DB
**  |    +---------------------------------------+     |
**  |    |99|                  |37|           |01|     |
**  |    +---------------------------------------+     |
**  |    |                                       |     |
**  |    +---------------------------------------+     |
**  |                                                  |
**  |                                                  |
**  +--------------------------------------------------+
**
**
**
**
**   Following is a situation where the direct line distance cannot be
**   calculated:
**
**   D380 -> DA01 is setup as a door to bay distance.
**   D380 -> DA97 is setup as a door to bay distance.
**
**   The direct line distance from D380 to DA11 cannot be calculated
**   using D380->DA01 and D380->DA97 because the distance from D380 to DA97
**   is not a direct line distance.  It this case the distance from D380
**   to DA11 will be D380->DA01->DA11.
**
**          Door         Door         Door
**          D380         D381         D382
**  +------+====+-------+=====+------+====+---------------------------+
**  |                                                                 |
**  |                                               DA DB DC DD       |
**  |                                                 +  +  +  +      |
**  |                                               01|  |  |  |      |
**  |                                                 |  |  |  |      |
**  |                  DS                             |  |  |  |      |
**  |    +------------------------------------+       |  |  |  |      |
**  |                  DR                             |  |  |  |      |
**  |    +------------------------------------+     11|  |  |  |      |
**  |                  DP                             |  |  |  |      |
**  |    +------------------------------------+       |  |  |  |      |
**  |                  DN                             |  |  |  |      |
**  |    +------------------------------------+       |  |  |  |      |
**  |                  DM                             |  |  |  |      |
**  |    +------------------------------------+     97|  |  |  |      |
**  |                  DL                             +  +  +  +      |
**  |                                                                 |
**  |                                                                 |
**  +-----------------------------------------------------------------+
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/

    FUNCTION lmd_get_dr_to_bay_direct_dist (
        i_dock_num       IN               point_distance.point_dock%TYPE,
        i_from_door      IN               point_distance.point_a%TYPE,
        i_to_bay         IN               bay_distance.bay%TYPE,
        i_min_bay        IN               VARCHAR2,
        i_max_bay        IN               VARCHAR2,
        i_min_bay_dist   IN               NUMBER,
        i_max_bay_dist   IN               NUMBER,
        o_dist           OUT              lmd_distance_obj
    ) RETURN NUMBER AS

        l_angle             NUMBER := 0.0;
        l_func_name         VARCHAR2(50) := 'lmd_get_dr_to_bay_direct_dist';
        l_ret_val           NUMBER := c_swms_normal;
        l_message           VARCHAR2(4000);
        l_bay_to_bay_dist   lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_to_aisle          VARCHAR2(2);  /* Destination aisle */
        l_to_bay_id_only    VARCHAR2(2);  /* Only the bay of the to bay */
        l_min_bay_id_only   VARCHAR2(2);  /* Only the bay of the min bay */
        l_max_bay_id_only   VARCHAR2(2);  /* Only the bay of the max bay */
    BEGIN
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_dock_num= '
                                            || i_dock_num
                                            || 'i_from_door= '
                                            || i_from_door
                                            || 'i_to_bay= '
                                            || i_to_bay
                                            || 'i_min_bay'
                                            || i_min_bay
                                            || 'i_max_bay= '
                                            || i_max_bay
                                            || 'i_min_bay_dist= '
                                            || i_min_bay_dist, sqlcode, sqlerrm);

        o_dist.total_distance := c_big_float;
        IF ( g_forklift_audit ) THEN
            l_message := 'Calculate the distance from door directly to bay';
            pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_to_aisle := substr(i_to_bay,1,2);
        l_to_bay_id_only := substr(i_to_bay,3,2);
        l_min_bay_id_only := substr(i_min_bay,3,2);
        l_max_bay_id_only := substr(i_max_bay,3,2);

        l_ret_val := lmd_get_b2b_on_aisle_dist(l_to_aisle, l_min_bay_id_only, l_max_bay_id_only, l_bay_to_bay_dist);
        IF ( l_ret_val = c_swms_normal ) THEN
            l_angle := lmd_get_ab_angle(i_min_bay_dist, l_bay_to_bay_dist.total_distance, i_max_bay_dist);
            IF ( l_angle != -1.0 ) THEN
                IF ( l_to_bay_id_only < l_min_bay_id_only ) THEN
                    l_angle := c_m_pi - l_angle;
                END IF;
            END IF;

        END IF;

        IF ( l_angle != -1.0 ) THEN
            IF ( l_ret_val = c_swms_normal ) THEN
                l_ret_val := lmd_get_b2b_on_aisle_dist(l_to_aisle, l_min_bay_id_only, l_to_bay_id_only, l_bay_to_bay_dist)
                ;
            END IF;

            IF ( l_ret_val <> c_swms_normal ) THEN
                o_dist.total_distance := lmd_get_side_a_length(i_min_bay_dist, l_bay_to_bay_dist.total_distance, l_angle);
                IF ( o_dist.total_distance = -1.0 ) THEN
                    o_dist.total_distance := c_big_float;
                END IF;

                IF ( g_forklift_audit AND o_dist.total_distance != c_big_float ) THEN
                    l_message := 'Distance from door directly to bay = ' || l_to_bay_id_only;
                    pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, o_dist.total_distance);
                END IF;

            END IF;

        END IF;

        RETURN l_ret_val;
    END lmd_get_dr_to_bay_direct_dist;
	
	
/**************************************************************************
**  Function:  lmd_get_bay_to_bay_dist
**
**  Description:
**    This subroutine calculates the distance between two bays.
**    If the "from" bay and the "to" bay are on the same aisle then the
**    distance between the bays are calculated otherwise three distances are
**    calculated with the shortest distance being used.
**    The three distances are:
**    - "from" bay -> start of "from aisle" -> start of "to" aisle -> "to" bay
**    - "from" bay -> end of "from aisle" -> end of "to" aisle -> "to" bay
**    - Cross aisle distance.
**
**  Parameters:
**      i_dock_num - Specified dock number.
**      i_from_bay - Starting bay.  Can either be a location or the aisle and
**                   bay only (ie. from haul).
**      i_to_bay   - Ending bay.  Can either be a location or the aisle and
**                   bay only (ie. from haul).
**      o_dist     - Travel distance between specified bays on dock.
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
***************************************************************************/	

     FUNCTION lmd_get_bay_to_bay_dist (
        i_dock_num   IN           point_distance.point_dock%TYPE,
        i_from_bay   IN           bay_distance.bay%TYPE,
        i_to_bay     IN           bay_distance.bay%TYPE,
        o_dist       OUT          lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val                         NUMBER := c_swms_normal;
        l_message                         VARCHAR2(4000);
        l_distance_used                   VARCHAR2(1) := ' ';
        l_from_aisle                      VARCHAR2(2);
        l_from_bay                        VARCHAR2(2);
        l_func_name                       VARCHAR2(30) := 'lmd_get_bay_to_bay_dist';
        l_to_aisle                        VARCHAR2(2);
        l_to_bay                          VARCHAR2(2);
        l_begin_bay_to_end_bay_dist       lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_begin_bay_to_strt_aisle_dist   lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_end_bay_to_start_aisle_dist     lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_begin_bay_to_end_aisle_dist     lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_end_bay_to_end_aisle_dist       lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_aisle_dist                      lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_cross_aisle_dist                lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    BEGIN
        o_dist := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
l_from_aisle:=substr(i_from_bay,1,2);
l_from_bay:=substr(i_from_bay,3,2);
l_to_aisle:=substr(i_to_bay,1,2);
l_to_bay:=substr(i_to_bay,3,2);

        g_suppress_audit_message := c_false;   /* Used in forklift audit. */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_dock_num= '
                                            || i_dock_num
                                            || 'i_from_bay= '
                                            || i_from_bay
                                            || ' i_to_bay= '
                                            || i_to_bay, sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_dock_num= '
                                            || i_dock_num
                                            || 'i_from_bay= '
                                            || i_from_bay
                                            || ' i_to_bay= '
                                            || i_to_bay, sqlcode, sqlerrm);

        IF ( g_forklift_audit ) THEN
            l_message := 'Calculate bay to bay distance.';
            pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_cross_aisle_dist.total_distance := c_big_float;
        IF ( l_from_aisle = l_to_aisle ) THEN
            IF ( g_forklift_audit ) THEN
                l_message := 'Calculate the distance between the bays.';
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;

            l_ret_val := lmd_get_b2b_on_aisle_dist(l_from_aisle, l_from_bay, l_to_bay, l_begin_bay_to_end_bay_dist);
            IF ( l_ret_val = 0 ) THEN
                lmd_add_distance(o_dist, l_begin_bay_to_end_bay_dist);
            END IF;
        ELSE
            IF ( g_forklift_audit ) THEN
                l_message := 'Calculate the following distances and use the shortest distance.';
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                l_message := 'Bay= '
                             || l_from_bay
                             || ' start of aisle= '
                             || l_from_aisle
                             || ' start of aisle= '
                             || l_to_aisle
                             || 'bay= '
                             || l_to_bay;

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '- Distance using cross aisles', -1);
            END IF;

            g_suppress_audit_message := c_true;
            l_ret_val := lmd_get_aisle_to_bay_dist(i_dock_num, l_from_aisle, i_from_bay, l_begin_bay_to_strt_aisle_dist);
            IF ( l_ret_val = c_swms_normal ) THEN
			/* Get the distance from the "to" bay to the start of the "to" aisle. */
                l_ret_val := lmd_get_aisle_to_bay_dist(i_dock_num, l_to_aisle, i_to_bay, l_end_bay_to_start_aisle_dist);
            END IF;

            IF ( l_ret_val = c_swms_normal ) THEN
			/* Get the distance from the "from" bay to the end of the aisle. */
             pl_text_log.ins_msg_async('INFO', l_func_name, 'calling lmd_get_bay_to_end_dist.l_from_aisle'||l_from_aisle
             ||' l_from_bay = '||l_from_bay, sqlcode, sqlerrm);
               
                l_ret_val := lmd_get_bay_to_end_dist(l_from_aisle, l_from_bay, l_begin_bay_to_end_aisle_dist);
            END IF;

            IF ( l_ret_val = c_swms_normal ) THEN
            /* Get the distance from the "to" bay to the end of the "to" aisle. */
                l_ret_val := lmd_get_bay_to_end_dist(l_to_aisle, l_to_bay, l_end_bay_to_end_aisle_dist);
            END IF;

            IF ( l_ret_val = c_swms_normal ) THEN
             /* Get the distance from the "from" aisle to the "to" aisle. */
                l_ret_val := lmd_get_aisle_to_aisle_dist(i_dock_num, l_from_aisle, l_to_aisle, l_aisle_dist);
            END IF;

            g_suppress_audit_message := c_false;
            IF ( g_forklift_audit ) THEN
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
                l_message := 'Calculate distance from bay= '
                             || l_from_bay
                             || ' start of aisle= '
                             || l_from_aisle
                             || ' start of aisle= '
                             || l_to_aisle
                             || ' bay= '
                             || l_to_bay;

                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                l_message := 'Bay Distance. Start of Aisle= '
                             || l_from_aisle
                             || ' To Bay= '
                             || l_from_bay;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_begin_bay_to_strt_aisle_dist.total_distance);
                l_message := 'Aisle to Aisle Distance. From Aisle ='
                             || l_from_aisle
                             || ' To Aisle= '
                             || l_to_aisle;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_aisle_dist.total_distance);
                l_message := 'Bay Distance.Start of Aisle= '
                             || l_to_aisle
                             || ' To Bay= '
                             || l_to_bay;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_end_bay_to_start_aisle_dist.total_distance);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
                l_message := 'Calculate distance from bay= '
                             || l_from_bay
                             || 'end of aisle= '
                             || l_from_aisle
                             || ' end of aisle= '
                             || l_to_aisle
                             || ' bay= '
                             || l_to_bay;

                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                l_message := 'Bay Distance. End of Aisle = '
                             || l_from_aisle
                             || 'To Bay = '
                             || l_from_bay;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_begin_bay_to_end_aisle_dist.total_distance);
                l_message := 'Aisle to Aisle Distance. From Aisle = '
                             || l_from_aisle
                             || ' To Aisle= '
                             || l_to_aisle;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_aisle_dist.total_distance);
                l_message := 'Bay Distance. End of Aisle= '
                             || l_to_aisle
                             || 'To Bay= '
                             || l_to_bay;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_end_bay_to_end_aisle_dist.total_distance);
            END IF;

            IF ( l_ret_val = c_swms_normal ) THEN
			/* Get distance from the "from" bay to the "to" bay using cross aisles. */
                l_ret_val := lmd_check_cross_aisle_dist(i_dock_num, l_from_aisle, l_from_bay, l_to_aisle, l_to_bay, l_cross_aisle_dist
                );
            END IF;

            IF ( ( l_begin_bay_to_strt_aisle_dist.total_distance + l_end_bay_to_start_aisle_dist.total_distance ) > ( l_begin_bay_to_end_aisle_dist.total_distance + l_end_bay_to_end_aisle_dist.total_distance ) ) THEN
                lmd_add_distance(o_dist, l_begin_bay_to_end_aisle_dist);
                lmd_add_distance(o_dist, l_end_bay_to_end_aisle_dist);
                lmd_add_distance(o_dist, l_aisle_dist);
                l_distance_used := 'E';
            ELSE
                lmd_add_distance(o_dist, l_begin_bay_to_strt_aisle_dist);
                lmd_add_distance(o_dist, l_end_bay_to_start_aisle_dist);
                lmd_add_distance(o_dist, l_aisle_dist);
                l_distance_used := 'S';
            END IF;

            IF ( o_dist.total_distance > l_cross_aisle_dist.total_distance ) THEN
			/* Using the cross aisle(s) is the shortest path. */
                lmd_clear_distance(o_dist);
                lmd_add_distance(o_dist, l_cross_aisle_dist);
                l_distance_used := 'C';
            END IF;

            IF ( g_forklift_audit ) THEN
                CASE l_distance_used
                    WHEN 'S' THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Going to start of aisles is the shortest path. Feet = ' || o_dist.total_distance
                        , sqlcode, sqlerrm);
                    WHEN 'E' THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Going to end of aisles is the shortest path. Feet = ' || o_dist.total_distance
                        , sqlcode, sqlerrm);
                    WHEN 'C' THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'The cross aisles is the shortest path. Feet = ' || o_dist.total_distance
                        , sqlcode, sqlerrm);
                    ELSE
                        l_message := 'Have unhandled distance used indicator= '
                                     || l_distance_used
                                     || ' Call in a ticket';
                        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                END CASE;

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;

        END IF;

        RETURN l_ret_val;
    END lmd_get_bay_to_bay_dist;	

/***************************************************************************
**  Function:  lmd_get_b2b_on_aisle_dist
**
**  Description:
**    This subroutine finds the distance between the specified bays on the
**    same specified aisle.
**
**  Parameters:
**    i_aisle    - Specified aisle id.  Examples:  CA, DE
**    i_from_bay - Starting bay.  Bay id only.  Examples: 01, 23
**    i_to_bay   - Ending bay.  Bay id only.  Examples: 01, 23
**    o_dist     - Distance between specified bays on the same aisle
**
**  Return values:
**    LM_BAY_DIST_BAD_SETUP -- Bay not found in bay_distance table.
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
***************************************************************************/
    FUNCTION lmd_get_b2b_on_aisle_dist (
        i_aisle      IN           bay_distance.aisle%TYPE,
        i_from_bay   IN           bay_distance.bay%TYPE,
        i_to_bay     IN           bay_distance.bay%TYPE,
        o_dist       OUT          lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name         VARCHAR2(50) := 'lmd_get_b2b_on_aisle_dist';
        l_ret_val           NUMBER := c_swms_normal;
        l_message           VARCHAR2(4000);
        l_bay_to_bay_dist   NUMBER;
    BEGIN
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_aisle= '
                                            || i_aisle
                                            || ' i_from_bay= '
                                            || i_from_bay
                                            || ' i_to_bay= '
                                            || i_to_bay, sqlcode, sqlerrm);

        BEGIN
            SELECT
                abs(bd.bay_dist - bd1.bay_dist)
            INTO l_bay_to_bay_dist
            FROM
                bay_distance   bd1,
                bay_distance   bd
            WHERE
                bd1.aisle = bd.aisle
                AND bd1.bay = i_to_bay
                AND bd.bay = i_from_bay
                AND bd.aisle = i_aisle;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Unable to calculate distance between specified bays on aisle', sqlcode
                , sqlerrm);
                l_ret_val := c_status_lm_bay_dist_bad_setup;
        END;

        o_dist.total_distance := l_bay_to_bay_dist;
        IF ( g_forklift_audit ) THEN
            l_message := 'Bay to Bay Distance. Aisle= '
                         || i_aisle
                         || ' From Bay= '
                         || i_from_bay
                         || 'To Bay= '
                         || i_to_bay;

            pl_text_log.ins_msg_async('WARN', l_func_name, l_message, sqlcode, sqlerrm);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_bay_to_bay_dist);
        END IF;

        RETURN l_ret_val;
    END lmd_get_b2b_on_aisle_dist;

/****************************************************************************
**  Function:  lmd_get_suspended_batch_dist
**
**  Description:
**    Calculates the distance from the last completed drop point of a
**    suspended batch to the point specified.  The user probably will not
**    have a suspended batch which is OK.
**
**  Parameters:
**      i_psz_batch_no             - The batch being completed.
**      i_psz_user_id              - Current user.
**      i_psz_next_point           - The first point visited of the batch
**                                   being completed.
**      io_e_rec                    - Pointer to equipment tmu values.
**      o_dist struct lmd_distance - Pointer to distance values to be returned.
**
**  Return values:
**    SWMS_NORMAL       - Successful
**    NO_LM_BATCH_FOUND - User had no suspended batch which is OK.  
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/

    FUNCTION lmd_get_suspended_batch_dist (
      i_psz_batch_no     IN                 batch.batch_no%TYPE,
        i_psz_user_id      IN                 arch_batch.user_id%TYPE,
        i_psz_next_point   IN                 VARCHAR2,
        io_e_rec            IN  OUT               pl_lm_goal_pb.type_lmc_equip_rec,
        o_dist             OUT                lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val                 NUMBER := c_swms_normal;
        l_func_name               VARCHAR2(30) := 'lmd_get_suspended_batch_dist';
        l_message                 VARCHAR2(4000);
        l_sz_last_drop_point      VARCHAR(10);
        l_sz_pallet_id            VARCHAR2(10);
        l_sz_suspended_batch_no   VARCHAR2(10);
        l_dist                    lmd_distance_obj;
    BEGIN
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
--		io_e_rec := pl_lm_goal_pb.type_lmc_equip_rec('', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '');
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_psz_batch_no= '
                                            || i_psz_batch_no
                                            || ' i_psz_user_id= '
                                            || i_psz_user_id
                                            || ' i_psz_next_point= '
                                            || i_psz_next_point, sqlcode, sqlerrm);

        l_ret_val := lmd_get_suspended_batch(i_psz_batch_no, i_psz_user_id, l_sz_suspended_batch_no);
        IF ( l_ret_val = c_swms_normal ) THEN
            l_ret_val := lmd_get_last_drop_point(l_sz_suspended_batch_no, l_sz_pallet_id, l_sz_last_drop_point);
            IF ( l_ret_val = c_swms_normal ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Suspended batch= '
                                                    || l_sz_suspended_batch_no
                                                    || 'last drop point= '
                                                    || l_sz_last_drop_point, sqlcode, sqlerrm);

                IF ( g_forklift_audit ) THEN
                    l_message := 'User has suspended batch as are result of a break away.  The last completed drop for suspended batch '
                                 || l_sz_suspended_batch_no
                                 || ' was made at '
                                 || l_sz_last_drop_point
                                 || ' This will be the starting point of batch= '
                                 || i_psz_batch_no
                                 || ' The first pickup point for batch '
                                 || i_psz_batch_no
                                 || ' is '
                                 || i_psz_next_point;

                    pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                    pl_lm_goaltime.lmg_audit_cmt(i_psz_batch_no, l_message, -1);
                END IF;

                l_ret_val := lmd_get_pt_to_pt_dist(l_sz_last_drop_point, i_psz_next_point, io_e_rec, l_dist);
                IF ( g_forklift_audit AND l_ret_val = c_swms_normal ) THEN
                    pl_lm_goaltime.lmg_audit_travel_distance(i_psz_batch_no, l_sz_last_drop_point, i_psz_next_point, l_dist);
                END IF;

                IF ( l_ret_val = c_swms_normal ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Next_loc distances = '
                                                        || l_dist.total_distance
                                                        || ' , '
                                                        || l_dist.accel_distance
                                                        || ' , '
                                                        || l_dist.decel_distance
                                                        || ' , '
                                                        || l_dist.travel_distance
                                                        || ' , '
                                                        || l_dist.distance_rate, sqlcode, sqlerrm);

                    lmd_add_distance(o_dist, l_dist);
                END IF;

            END IF;

        END IF;

        RETURN l_ret_val;
    END lmd_get_suspended_batch_dist;

/**********************************************************************
**  FUNCTION     		:   lmd_get_door_to_aisle_dist
**
**  DESCRIPTION        	:   This subroutine finds the distance between the 
**    						specified door and aisle on the specified dock.                           
**
**  Called By          	:   lmd_get_door_to_bay_dist
**
**  INPUT Parameters
**		i_dock_num  - Specified dock.  This needs to be the door dock number.
**     	i_from_door - Specified door.
**      i_to_aisle  - Specified aisle.
**      o_dist      - Distance between door and aisle on specified dock.
**      
**  Return Values
**		return code	
**	
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
************************************************************************/

    FUNCTION lmd_get_door_to_aisle_dist (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_aisle    IN            point_distance.point_b%TYPE,
        o_dist        OUT           lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name            VARCHAR2(30) := 'lmd_get_door_to_aisle_dist';
        l_ret_status           NUMBER := c_swms_normal;
        l_door_to_aisle_dist   point_distance.point_dist%TYPE := 0.0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmd_get_door_to_aisle_dist i_dock_num '
                                            || i_dock_num
                                            || ' i_from_door '
                                            || i_from_door
                                            || ' i_to_aisle '
                                            || i_to_aisle, sqlcode, sqlerrm);

        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        BEGIN
            SELECT
                point_dist
            INTO l_door_to_aisle_dist
            FROM
                point_distance
            WHERE
                point_dock = i_dock_num
                AND point_type = 'DA'
                AND point_a = i_from_door
                AND point_b = i_to_aisle;

            o_dist.total_distance := l_door_to_aisle_dist;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from door and aisle on dock.', sqlcode
                , sqlerrm);
                l_ret_status := C_ST_LM_PT_DIST_BADSTUP_DTA;
        END;

        IF g_forklift_audit AND l_ret_status = c_swms_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Door to Aisle Distance  Dock: '
                                                || i_dock_num
                                                || '  From Door: '
                                                || i_from_door
                                                || '  To Aisle: '
                                                || i_to_aisle, sqlcode, sqlerrm);

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Door to Aisle Distance  Dock: '
                                                           || i_dock_num
                                                           || '  From Door: '
                                                           || i_from_door
                                                           || '  To Aisle: '
                                                           || i_to_aisle, l_door_to_aisle_dist);

        END IF/*END OF IF*/;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmd_get_door_to_aisle_dist return ' || l_ret_status, sqlcode, sqlerrm);
        RETURN l_ret_status;
    END lmd_get_door_to_aisle_dist;

/**********************************************************************
**  FUNCTION     		:   lmd_get_bay_to_end_dist
**
**  DESCRIPTION        	:   This subroutine finds the distance between 
**    						the specified bay and the end cap of the specified aisle.                           
**
**  Called By          	:   lmd_get_bay_to_bay_dist
**
**  INPUT Parameters
**		i_aisle - Specified aisle.
**      i_bay   - Specified bay.  This is only the bay specifier.
**      o_dist  - Distance between specified bay and the end of the
**                specified aisle
**  Return Values
**		return code		
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
************************************************************************/
    FUNCTION lmd_get_bay_to_end_dist (
        i_aisle   IN        bay_distance.aisle%TYPE,
        i_bay     IN        bay_distance.bay%TYPE,
        o_dist    OUT       lmd_distance_obj
    ) RETURN NUMBER AS
        l_func_name         VARCHAR(50) := 'lmd_get_bay_to_end_dist';
        l_ret_val           NUMBER := c_swms_normal;
        l_bay_to_end_dist   FLOAT;
    BEGIN
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmd_get_bay_to_end_dist i_aisle '
                                            || i_aisle
                                            || ' i_bay '
                                            || i_bay, sqlcode, sqlerrm);

        BEGIN
            SELECT
                abs(b.bay_dist - bd.bay_dist)
            INTO l_bay_to_end_dist
            FROM
                bay_distance   bd,
                bay_distance   b
            WHERE
                bd.bay = 'END'
                AND bd.aisle = b.aisle
                AND b.aisle = i_aisle
                AND b.bay = i_bay;

            o_dist.total_distance := l_bay_to_end_dist;
            IF ( g_forklift_audit AND g_suppress_audit_message = c_false ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Bay to end of aisle distance.  Aisle: '
                                                    || i_aisle
                                                    || ' i_bay '
                                                    || i_bay, sqlcode, sqlerrm);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Bay to end of aisle distance.  Aisle: '
                                                               || i_aisle
                                                               || ' i_bay '
                                                               || i_bay, l_bay_to_end_dist);

            END IF;/*END OF IF g_forklift_audit*/

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Unable to calculate distance from bay to end of aisle.', sqlcode, sqlerrm
                );
                l_ret_val := c_status_lm_bay_dist_bad_setup;
        END;
    /* lmd_segment_distance(o_dist); */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmd_get_bay_to_end_dist return ' || l_ret_val, sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_bay_to_end_dist;
	
/**********************************************************************
**  FUNCTION     		:   lmd_get_ab_angle
**
**  DESCRIPTION        	:   This function calculates the angle between sides a and b of a
**    						trianble when the lengths of all sides are known.
**    						Law of cosines is used.  If side a or side b is zero then 
**    						0 is returned.
**
**  Called By          	:   lmd_get_dr_to_bay_direct_dist
**
**  INPUT Parameters
**		i_side_a - Length of side a.
**    	i_side_b - Length of side b.
**    	i_side_c - Length of side c.
**
**  Return Values
**		If side a or side b is zero then 0.0 returned.
**  If an error occurs when determining then angle the -1.0 is returned.
**  Otherwise angle between sides a and b in radians returned.		
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
************************************************************************/

    FUNCTION lmd_get_ab_angle (
        i_side_a   IN         FLOAT,
        i_side_b   IN         FLOAT,
        i_side_c   IN         FLOAT
    ) RETURN FLOAT AS
        l_angle       FLOAT := 0.0;
        l_func_name   VARCHAR2(30) := 'lmd_get_ab_angle';
		l_message     VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmd_get_ab_angle side_a'
                                            || i_side_a
                                            || ' side_b '
                                            || i_side_b
                                            || ' side_c '
                                            || i_side_c, sqlcode, sqlerrm);

        IF ( i_side_a = 0 OR i_side_b = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'side_a'
                                                || i_side_a
                                                || ' side_b '
                                                || i_side_b
                                                || ' side_c '
                                                || i_side_c
                                                || '.  side_a and/or side_b is 0. Unable to calculate the angle between them.  Using 0 as the angle.'
                                                , sqlcode, sqlerrm);

            IF g_forklift_audit THEN
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'side_a'
                                                               || i_side_a
                                                               || ' side_b '
                                                               || i_side_b
                                                               || ' side_c '
                                                               || i_side_c
                                                               || '.  side_a and/or side_b is 0. Unable to calculate the angle between them.  Using 0 as the angle.'
                                                               , -1);

            END IF;/*END OF IF g_forklift_audit*/

        ELSE
            BEGIN
                l_angle := acos(((i_side_a * i_side_a) +(i_side_b * i_side_b) -(i_side_c * i_side_c)) /(2.0 * i_side_a * i_side_b
                ));

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'side_a'
                                                        || i_side_a
                                                        || ' side_b '
                                                        || i_side_b
                                                        || ' side_c '
                                                        || i_side_c
                                                        || 'Unable to calculate the angle between them.  Setting angle to '
                                                        || l_angle, sqlcode, sqlerrm);
					 /*
					** Unable to calculate the angle.  The values for the sides
					** are not physically possible.
					*/

                    l_angle := -1.0;  /* Use -1 to indicate unable to determine angle.*/
                    IF g_forklift_audit THEN
                        l_message := 'Unable to determine angle between sides a and b of triangle.  Lengths: side a: '
                                     || i_side_a
                                     || '  side b: '
                                     || i_side_b
                                     || '  side c: '
                                     || i_side_c
                                     || '.  Most likely the lengths cannot form a triangle.';

                        pl_text_log.ins_msg_async('WARN', l_func_name, l_message, sqlcode, sqlerrm);
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;/*END OF IF g_forklift_audit*/

            END;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmd_get_ab_angle ', sqlcode, sqlerrm);
        RETURN l_angle;
    END lmd_get_ab_angle;

/**********************************************************************
**  FUNCTION     		:   lmd_get_side_a_length
**
**  DESCRIPTION        	:   This function calulates the length of side 
**    						a of a triangle when given sides b and c and 
**    						the angle between sides b and c. Law of cosines                            
**							is used.
**
**  Called By          	:   lmd_get_dr_to_bay_direct_dist
**
**  INPUT Parameters
**		i_side_b   - Length of side b
**    	i_side_c   - Length of side c
**    	i_bc_angle - Angle between sides b and c.
**
**  Return Values
**		return code		
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
************************************************************************/
    FUNCTION lmd_get_side_a_length (
        i_side_b     IN           FLOAT,
        i_side_c     IN           FLOAT,
        i_bc_angle   IN           FLOAT
    ) RETURN number AS
        l_side_a      FLOAT := 0.0;
        l_func_name   VARCHAR2(30) := 'lmd_get_side_a_length';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmd_get_side_a_length i_side_b '
                                            || i_side_b
                                            || ' i_side_c '
                                            || i_side_c
                                            || ' i_bc_angle '
                                            || i_bc_angle, sqlcode, sqlerrm);

        BEGIN
            l_side_a := sqrt(((i_side_b * i_side_b) +(i_side_c * i_side_c)) -(2.0 * i_side_b * i_side_c * cos(i_bc_angle)));

        EXCEPTION
            WHEN OTHERS THEN
                l_side_a := -1.0;   /* -1.0 denotes error occured */
                pl_text_log.ins_msg_async('WARN', l_func_name, ' i_side_b '
                                                    || i_side_b
                                                    || ' i_side_c '
                                                    || i_side_c
                                                    || ' i_bc_angle .'
                                                    || i_bc_angle
                                                    || '  cos set errno to ERANGE.  Will use '
                                                    || l_side_a
                                                    || ' as the length of side a.', sqlcode, sqlerrm);

                IF ( g_forklift_audit ) THEN
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, ' i_side_b '
                                                                   || i_side_b
                                                                   || ' i_side_c '
                                                                   || i_side_c
                                                                   || ' i_bc_angle .'
                                                                   || i_bc_angle
                                                                   || '  cos set errno to ERANGE.  Will use '
                                                                   || l_side_a
                                                                   || ' as the length of side a.', -1);
                END IF;/*END OF IF*/

        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmd_get_side_a_length return ', sqlcode, sqlerrm);
        RETURN l_side_a;
    END lmd_get_side_a_length;

/**********************************************************************************************
**  FUNCTION     		:   lmd_get_d2d_dist_on_diff_dock
**
**  DESCRIPTION        	:   This subroutine finds the distance between two doors WITHIN THE
**    						SAME AREA but on different docks.
**
**    						The following distances are calculated then added together to get
**    						the door to door distance.
**       						- Determine the aisle closest to the from door and get the
**       						- length of this aisle.
**       						- Distance from the from door to the closest aisle.
**       						- Distance from the to door to the closest aisle.                           
**
**  Called By          	:   lmd_get_door_to_door_dist
**
**  INPUT Parameters
**		i_from_dock_num  - 	Dock of the starting door.
**      i_to_dock_num    - 	Dock of the ending door.
**      i_from_door      - 	Starting door.
**      i_to_door        - 	Ending door.
**      o_dist           - 	Distance between the specified doors.
**
**  Return Values
**		return code		
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
********************************************************************************************/

    FUNCTION lmd_get_d2d_dist_on_diff_dock (
        i_from_dock_num   IN                point_distance.point_dock%TYPE,
        i_to_dock_num     IN                point_distance.point_dock%TYPE,
        i_from_door       IN                point_distance.point_a%TYPE,
        i_to_door         IN                point_distance.point_b%TYPE,
        o_dist            OUT               lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name                 VARCHAR2(50) := 'lmd_get_d2d_dist_on_diff_dock';
        l_aisle                     VARCHAR2(2);--2 2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        l_ret_val                   NUMBER := c_swms_normal;
        l_closest_aisle             point_distance.point_b%TYPE;
        l_closest_aisle_length      NUMBER := 0;
        l_aisle_ind                 NUMBER := -1;
        l_aisle_length_ind          NUMBER := -1;
        l_aisle_length              FLOAT := 0.0;
        l_from_door_to_aisle_dist   lmd_distance_obj := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        l_to_door_to_aisle_dist     lmd_distance_obj := lmd_distance_obj(0, 0, 0, 0, 0, 0);
	
	  -- This cursor selects the aisle closest to the specified door.
	  -- It is possible to return more than one aisle.  We will use the
	  -- first one fetched.
        CURSOR c_closest_aisle_cur (
            cp_point_dock   point_distance.point_dock%TYPE,
            cp_door_no      point_distance.point_a%TYPE
        ) IS
        SELECT
            point_b
        FROM
            point_distance pd1
        WHERE
            point_type = 'DA'
            AND point_dock = cp_point_dock
            AND point_a = cp_door_no
            AND point_dist = (
                SELECT
                    MIN(point_dist)
                FROM
                    point_distance pd2
                WHERE
                    pd2.point_type = pd1.point_type
                    AND pd2.point_dock = pd1.point_dock
                    AND pd2.point_a = pd1.point_a
            );
	
	 -- This cursor selects the length of an aisle.

        CURSOR c_aisle_length_cur (
            cp_aisle bay_distance.aisle%TYPE
        ) IS
        SELECT
            bay_dist
        FROM
            bay_distance
        WHERE
            aisle = cp_aisle
            AND bay = 'END';

    BEGIN
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);

    /*
    ** Find the closest aisle to the from door and get the length of this
    ** aisle.
    */
        BEGIN
            OPEN c_closest_aisle_cur(i_from_dock_num, i_from_door);
            FETCH c_closest_aisle_cur INTO l_closest_aisle;
            IF ( c_closest_aisle_cur%found ) THEN
                CLOSE c_closest_aisle_cur;
                l_aisle := l_closest_aisle;
                l_aisle_ind := 0;
                OPEN c_aisle_length_cur(l_closest_aisle);
                FETCH c_aisle_length_cur INTO l_closest_aisle_length;
                IF ( c_aisle_length_cur%found ) THEN
                    l_aisle_length := l_closest_aisle_length;
                    l_aisle_length_ind := 0;
                ELSE
                    l_aisle_length_ind := -1;
                END IF;

                CLOSE c_aisle_length_cur;
            ELSE
                CLOSE c_closest_aisle_cur;
                l_aisle_ind := -1;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from door to door on different dock in same area.'
                , sqlcode, sqlerrm);
                l_ret_val := C_ST_LM_PT_DIST_BADSTUP_DTD;
        END;

        IF l_aisle_ind <> 0 THEN 
        /*
        ** Did not find an aisle closest to the from door on the from dock.
        */
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Did not find an aisle closest to the from door on the from dock.', sqlcode
            , sqlerrm);
            l_ret_val := C_ST_LM_PT_DIST_BADSTUP_DTD;
        ELSIF l_aisle_length_ind <> 0 THEN
    
        /*
        ** The end of aisle distance is not setup of the aisle closest to
        ** the from door is not setup.
        */
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE The end of aisle distance is not setup for this aisle.', sqlcode, sqlerrm
            );
            l_ret_val := C_ST_LM_PT_DIST_BADSTUP_DTD;
        ELSE
            IF g_forklift_audit THEN
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Door '
                                                               || i_from_door
                                                               || ' and door '
                                                               || i_from_door
                                                               || ' are in the same area but on different docks.', -1);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'The distance between the doors is the sum of the following:', -1

                );
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '1.  Length of the aisle closest to door '
                                                               || i_from_door
                                                               || ' which is aisle '
                                                               || l_aisle, -1);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '2.  Distance from door '
                                                               || i_from_door
                                                               || ' to aisle '
                                                               || l_aisle, -1);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '3.  Distance from door'
                                                               || i_to_door
                                                               || ' to aisle '
                                                               || l_aisle, -1);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Length of aisle ' || l_aisle, l_aisle_length);
            END IF; /* end audit */
        
        /*
        ** Initialize the value that lmd_get_door_to_aisle_dist will
        ** calculate.
        */

            l_from_door_to_aisle_dist.total_distance := 0.0;
            l_to_door_to_aisle_dist.total_distance := 0.0;
            l_ret_val := lmd_get_door_to_aisle_dist(i_from_dock_num, i_from_door, l_aisle, l_from_door_to_aisle_dist);
            IF l_ret_val = c_swms_normal THEN
                l_ret_val := lmd_get_door_to_aisle_dist(i_to_dock_num, i_to_door, l_aisle, l_to_door_to_aisle_dist);
            END IF;/*END OF IF*/

            IF l_ret_val = c_swms_normal THEN
                o_dist.total_distance := l_aisle_length + l_from_door_to_aisle_dist.total_distance + l_to_door_to_aisle_dist.total_distance
                ;
            END IF;/*END OF IF*/

            IF g_forklift_audit THEN
            /* Dashes output to aid in the readability of the audit report. */
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, '----------------------------------------', -1);
            END IF;/*END OF IF g_forklift_audit*/
        END IF;/*EN DO IF g_forklift_audit*/

        RETURN l_ret_val;
    END lmd_get_d2d_dist_on_diff_dock;
	
/****************************************************************************
**  Function:  lmd_get_aisle_to_bay_dist
**
**  Description:
**    This subroutine finds the distance between the specified aisle and bay
**    on the specified dock.
**
**  Parameters:
**      i_dock_num   - Dock aisle is on.
**      i_from_aisle - Starting aisle.
**      i_to_bay     - Ending bay.  Can either be a location or the aisle
**                     and bay only (ie. from haul).
**      o_dist       - Distance between specified aisle and bay on specified
**                     dock.
**  Return Values
**		return code		
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_aisle_to_bay_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_to_bay       IN             bay_distance.bay%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val                         NUMBER := c_swms_normal;
        l_func_name                       VARCHAR2(50) := 'lmd_get_aisle_to_bay_dist';
        l_message                         VARCHAR2(1024);
        l_aisle_to_bay_dist               NUMBER := 0.0;
        l_save_g_suppress_audit_msg   NUMBER;
        l_aisle_dist                      lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_bay_end_dist                    lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_dock_location                   VARCHAR2(1);
        l_to_bay        VARCHAR2(3);
        l_to_aisle  VARCHAR2(3);
    BEGIN
    l_to_bay:=substr(i_to_bay,3,2);
    l_to_aisle:=substr(i_to_bay,1,2);
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        IF ( g_forklift_audit AND g_suppress_audit_message = c_false ) THEN
            l_message := 'Calculate aisle to bay distance.  Dock: '
                         || i_dock_num
                         || '  Aisle: '
                         || i_from_aisle
                         ||' bay = '||i_to_bay
                         || '  To Bay: '
                         || l_to_aisle
                         || l_to_bay;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;
 pl_text_log.ins_msg_async('WARN', l_func_name, 'Calculate aisle to bay distance.  Dock: '
                         || i_dock_num
                         || '  Aisle: '
                         || i_from_aisle
                         || '  To Bay: '
                         || ' l_to_aisle ='||l_to_aisle
                         || ' l_to_bay = '||l_to_bay, sqlcode, sqlerrm);
               
        lmd_clear_distance(l_aisle_dist);

    /*
    ** Get the location of the dock.  This location designates if the dock
    ** it at the front, rear or the side.
    */
        BEGIN
            SELECT
                location
            INTO l_dock_location
            FROM
                dock
            WHERE
                dock_no = i_dock_num;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to select the location of the dock.', sqlcode, sqlerrm);
                l_ret_val := c_lm_bay_dist_bad_setup;
        END;
	
  /*
    ** If the source and destination aisles are different then
    ** get the distance between the two aisles.
    */

        IF ( l_ret_val = c_swms_normal AND ( l_to_aisle <> i_from_aisle ) ) THEN
            l_ret_val := lmd_get_aisle_to_aisle_dist(i_dock_num, i_from_aisle, l_to_aisle, l_aisle_dist);
        END IF;

        IF ( l_ret_val = c_swms_normal ) THEN
        /*
        **  Get the distance from the aisle to the bay.
        */
            CASE l_dock_location
                WHEN C_FRONT_DOCK THEN
                    NULL;
                WHEN C_SIDE_DOCK THEN
                /*
                ** Get the distance from the start of the aisle to the bay.
                */
                    SELECT
                        bay_dist
                    INTO l_aisle_to_bay_dist
                    FROM
                        bay_distance
                    WHERE
                        aisle = l_to_aisle
                        AND bay = l_to_bay;

                WHEN C_BACK_DOCK THEN
                /*
                ** Get the distance from the end of the aisle to the bay.
                **
                ** Suppress audit messages in lmd_get_bay_to_end_dist because
                ** they are output in this function.
                */
                    l_save_g_suppress_audit_msg := g_suppress_audit_message;
                    g_suppress_audit_message := c_true;
                    l_ret_val := lmd_get_bay_to_end_dist(l_to_aisle, l_to_bay, l_bay_end_dist);
                    g_suppress_audit_message := l_save_g_suppress_audit_msg;
                    l_aisle_to_bay_dist := l_bay_end_dist.total_distance;
                ELSE
                /*
                ** Have a unhandled value for the dock location.  Treat it as
                ** a front dock so processing can continue and write a l_message
                ** to aplog.
                */
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Have an unhandled value['
                                                        || l_dock_location
                                                        || ') for the dock location.  Handling it as a FRONT_DOCK.', sqlcode, sqlerrm
                                                        );

                    BEGIN
                        SELECT
                            bay_dist
                        INTO l_aisle_to_bay_dist
                        FROM
                            bay_distance
                        WHERE
                            aisle = l_to_aisle
                            AND bay = l_to_bay;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to select the Bay distance.', sqlcode, sqlerrm
                            );
                    END;

            END CASE;/* end CASE */

            IF ( l_ret_val != c_swms_normal ) THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from aisle to bay.', sqlcode, sqlerrm
                );
                l_ret_val := c_lm_bay_dist_bad_setup;
            ELSE
                o_dist.total_distance := l_aisle_to_bay_dist;
            /* lmd_segment_distance(o_dist); */
                IF ( g_forklift_audit AND l_ret_val = c_swms_normal AND g_suppress_audit_message = c_false ) THEN
                    CASE ( l_dock_location )
                        WHEN C_FRONT_DOCK THEN
                            NULL;
                        WHEN C_SIDE_DOCK THEN
                            l_message := 'Bay Distance  Start of Aisle: '
                                         || l_to_aisle
                                         || '  To Bay: '
                                         || l_to_bay;
                        WHEN C_BACK_DOCK THEN
                            l_message := 'Bay Distance  End of Aisle: '
                                         || l_to_aisle
                                         || '  To Bay: '
                                         || l_to_bay;
                        ELSE
                            l_message := 'Bay Distance  Start/End ?? of Aisle: '
                                         || l_to_aisle
                                         || ' To Bay: '
                                         || l_to_bay
                                         || ' Unhandled value for l_dock_location['
                                         || l_dock_location
                                         || ')';
                    END CASE;

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_aisle_to_bay_dist);
                END IF;

            /*
            ** If the source and destination aisle are different then add
            ** this distance to the distance from the destination aisle to
            ** the destination bay.
            */

                IF ( l_to_aisle <> i_from_aisle ) THEN
                    lmd_add_distance(o_dist, l_aisle_dist);
                END IF;
            END IF;

        END IF;

        return(l_ret_val);
    END lmd_get_aisle_to_bay_dist;
	
/****************************************************************************
**  Function:  lmd_get_aisle_to_aisle_dist
**
**  Description:
**    This subroutine finds the distance between the specified aisles on the
**    specified dock.
**
**  Parameters:
**    i_dock_num   - Dock the user is on.
**    i_from_aisle - Starting aisle.
**    i_to_aisle   - Ending aisle.
**    o_dist       - Distance between specified aisles on specified dock.
**
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_aisle_to_aisle_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_to_aisle     IN             aisle_info.name%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val               NUMBER := c_swms_normal;
        l_func_name             VARCHAR2(50) := 'lmd_get_aisle_to_aisle_dist';
        l_message               VARCHAR2(1024);
        l_aisle_to_aisle_dist   NUMBER := 0.0;
        l_from_seq              NUMBER := NULL;
        l_to_seq                NUMBER := NULL;
        l_temp_from_seq         NUMBER;
        l_temp_to_seq           NUMBER;
        l_hold                  NUMBER := 0;
        CURSOR c_aisle_order_cur (
            cp_aisle VARCHAR2
        ) IS
        SELECT
            physical_aisle_order
        FROM
            aisle_info
        WHERE
            name = cp_aisle;

              -- This cursor selects the aisle to aisle distance.

        CURSOR c_aa_dist_cur IS
        SELECT
            nvl(SUM(pd.point_dist), 0)
        FROM
            point_distance   pd,
            aisle_info       ai1,
            aisle_info       ai2
        WHERE
            pd.point_type = 'AA'
            AND pd.point_dock = i_dock_num
            AND pd.point_a = ai1.name
            AND pd.point_b = ai2.name
            AND DECODE(l_from_seq, NULL,(ascii(substr(pd.point_a, 1, 1)) * 100) + ascii(substr(pd.point_a, 2, 1)), ai1.physical_aisle_order
            ) BETWEEN l_temp_from_seq AND l_temp_to_seq
            AND DECODE(l_from_seq, NULL,(ascii(substr(pd.point_b, 1, 1)) * 100) + ascii(substr(pd.point_b, 2, 1)), ai2.physical_aisle_order
            ) BETWEEN l_temp_from_seq AND l_temp_to_seq;

    BEGIN

    /*
    ** Get the distance between the aisles.  If they are the same aisle
    ** the distance will be zero.
    **/
        o_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        IF ( i_to_aisle <> i_from_aisle ) THEN
            BEGIN
                OPEN c_aisle_order_cur(i_from_aisle);
                FETCH c_aisle_order_cur INTO l_from_seq;
                CLOSE c_aisle_order_cur;
                OPEN c_aisle_order_cur(i_to_aisle);
                FETCH c_aisle_order_cur INTO l_to_seq;
                CLOSE c_aisle_order_cur;
                IF ( l_from_seq IS NULL OR l_to_seq IS NULL ) THEN
                    l_temp_from_seq := ( ascii(substr(i_from_aisle, 1, 1)) * 100 ) + ascii(substr(i_from_aisle, 2, 1));

                    l_temp_to_seq := ( ascii(substr(i_to_aisle, 1, 1)) * 100 ) + ascii(substr(i_to_aisle, 2, 1));

                    l_from_seq := NULL;
                    l_to_seq := NULL;
                    IF ( l_temp_from_seq > l_temp_to_seq ) THEN
                        l_hold := l_temp_to_seq;
                        l_temp_to_seq := l_temp_from_seq;
                        l_temp_from_seq := l_hold;
                    END IF;

                ELSIF ( l_from_seq > l_to_seq ) THEN
                    l_temp_from_seq := l_to_seq;
                    l_temp_to_seq := l_from_seq;
                ELSE
                    l_temp_from_seq := l_from_seq;
                    l_temp_to_seq := l_to_seq;
                END IF;

                BEGIN
                    OPEN c_aa_dist_cur;
                    FETCH c_aa_dist_cur INTO l_aisle_to_aisle_dist;
                    CLOSE c_aa_dist_cur;
                EXCEPTION
                    WHEN OTHERS THEN
                        IF ( c_aa_dist_cur%isopen ) THEN
                            CLOSE c_aa_dist_cur;
                        END IF;
                        RAISE;
                END;

                o_dist.total_distance := l_aisle_to_aisle_dist;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate aisle to aisle distance on the specified dock.'
                    , sqlcode, sqlerrm);
                    l_ret_val := c_lm_pt_dist_badsetup_ata;
            END;

        ELSE
	
	 /*
        ** The from and to aisles are the same so the distance is zero.
        */
            o_dist.total_distance := 0.0;
        END IF;

        IF ( g_forklift_audit AND l_ret_val = c_swms_normal AND g_suppress_audit_message = c_false ) THEN
            l_message := 'Aisle to Aisle Distance  Dock: '
                         || i_dock_num
                         || '  From Aisle: '
                         || i_from_aisle
                         || ' To Aisle: '
                         || i_to_aisle;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_aisle_to_aisle_dist);
        END IF;

        return(l_ret_val);
    END lmd_get_aisle_to_aisle_dist;
	
/*****************************************************************************
**  Function:  lmd_check_cross_aisle_dist
**
**  Description:
**    This subroutine calculates the minimum cross aisle path from specified
**    starting and ending points. 
**
**  Parameters:
**    i_dock_num   - Dock number.
**    i_from_aisle - Starting aisle (aisle only).
**    i_from_bay   - Starting bay (bay only).
**    i_to_aisle   - Ending aisle (aisle only).
**    i_to_bay     - Ending bay (bay only).
**    o_dist       - Distance between the specified bays using cross aisles.
**
**  Return values:
**    c_swms_normal             - Operation successful
**    LM_PT_DIST_BADSETUP_ACA - Problem selecting the starting and ending
**                              aisles.
**    CROSS_AISLE_SEL_FAIL    - Oracle error selecting the cross aisles.
**    ?                       - Various other values depending on what a
**                              called function returned.
**
**  Modification History:
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
**
**   Example setup of cross aisles and calculating distance
**   from DC20B4 to DF9A1
**          
**  +--------------------------------------------------+
**  |                                                  |
**  |      Aisle DB                                    |
**  |   +-----------------------------|--|------+      |
**  |                                  20              +
**  |      Aisle DC                                    |Door      Front Dock
**  |                      47                          +
**  |   +-----------------+   +-----------------+      |
**  |                      43                          +
**  |      Aisle DD                                    |Door
**  |                      50                          +
**  |   +-----------------+   +-----------------+      |
**  |                      40                          +
**  |      Aisle DE                                    |Door
**  |                      45                          +
**  |   +-----------------+   +-----------|--|--+      |
**  |                      49              09            +
**  |      Aisle DF                                    |Door
**  |                                                  +
**  |                       ^                          |
**  +-----------------------|--------------------------+
**                          |
**                     Cross Aisle
**
**     Records in FORKLIFT_CROSS_AISLE table:
**
**      from_aisle  from_bay  to_aisle  to_bay
**      ----------  --------  --------  ------
**         DC         47         DD       43
**         DD         50         DE       40
**         DE         45         DF       49
**
**    The distance from DC20B4 to DF9A1 will be the sum of:
**       - Bay to bay distance  Aisle DC  Bay 20  Bay 47
**       - Bay to bay distance  Aisle DD  Bay 43  Bay 50
**       - Bay to bay distance  Aisle DE  Bay 40  Bay 45
**       - Bay to bay distance  Aisle DF  Bay 49  Bay 09
**       - Aisle to aisle distance from aisle DC to aisle DF
** 
*****************************************************************************/
    FUNCTION lmd_check_cross_aisle_dist (
        i_dock_num     IN             point_distance.point_dock%TYPE,
        i_from_aisle   IN             aisle_info.name%TYPE,
        i_from_bay     IN             bay_distance.bay%TYPE,
        i_to_aisle     IN             aisle_info.name%TYPE,
        i_to_bay       IN             bay_distance.bay%TYPE,
        o_dist         OUT            lmd_distance_obj
    ) RETURN NUMBER AS

        l_ret_val             NUMBER := c_swms_normal;
        l_func_name           VARCHAR2(50) := 'lmd_check_cross_aisle_dist';
        l_message             VARCHAR2(1024);
        l_done                NUMBER := c_false;           /* while loop flag */
        l_bay_to_bay_dist     lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_curr_aisle_dist     lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_aisle_dist          NUMBER;                     /* Distance between aisles */
        l_buf                 VARCHAR2(512);                       /* Work area */
        l_cross_aisle_found   NUMBER := c_false;      /* Flag indicating if cross aisle
                                                 found between aisles */
        l_first_fetch         NUMBER := c_true;             /* Flag */
        l_from_cross_aisle    VARCHAR2(10);
        l_from_cross_bay      VARCHAR2(10);
        l_hold                NUMBER;                           /* Work area */
        l_previous_to_aisle   VARCHAR2(10); /* Previous "to" aisle */
        l_previous_to_bay     VARCHAR2(10);   /* Previous "to" bay */
        l_to_cross_aisle      VARCHAR2(10);
        l_to_cross_bay        VARCHAR2(10);
        l_total_aisle_dist    NUMBER := 0.0;
        l_use_aisle_name      VARCHAR2(2);  /* Designates if to use the aisle name
                                     or aisle_info.physical_aisle_order
                                     when finding the aisles between the
                                     from aisle and the to aisles. */
        l_from_aisle          VARCHAR2(10);
        l_from_bay            VARCHAR2(10);
        l_to_aisle            VARCHAR2(10);
        l_to_bay              VARCHAR2(10);

    /* Variables used in ordering records */
        l_from_seq            NUMBER := 0;
        l_to_seq              NUMBER := 0;
        l_from_seq_new        NUMBER := 0;
        l_to_seq_new          NUMBER := 0;
    /*
    ** This cursor selects the aisles between the "from" and
    ** "to" points.
    */
        CURSOR c_aisle_cur IS
        SELECT
            pd.point_a,
            pd.point_b,
            nvl(point_dist, 0)
        FROM
            point_distance   pd,
            aisle_info       ai1,
            aisle_info       ai2
        WHERE
            pd.point_type = 'AA'
            AND pd.point_dock = i_dock_num
            AND pd.point_a = ai1.name
            AND pd.point_b = ai2.name
            AND DECODE(l_use_aisle_name, 'Y',(ascii(substr(pd.point_a, 1, 1)) * 100) + ascii(substr(pd.point_a, 2, 1)), ai1.physical_aisle_order
            ) BETWEEN l_from_seq AND l_to_seq
            AND DECODE(l_use_aisle_name, 'Y',(ascii(substr(pd.point_b, 1, 1)) * 100) + ascii(substr(pd.point_b, 2, 1)), ai2.physical_aisle_order
            ) BETWEEN l_from_seq AND l_to_seq
        ORDER BY
            DECODE(l_use_aisle_name, 'N', lpad(ai1.physical_aisle_order, 10, '0'), pd.point_a);

        CURSOR c_cross_c_aisle_cur IS
        SELECT
            from_bay,
            to_bay
        FROM
            forklift_cross_aisle
        WHERE
            from_aisle = l_from_cross_aisle
            AND to_aisle = l_to_cross_aisle
        UNION
        SELECT
            to_bay,
            from_bay
        FROM
            forklift_cross_aisle
        WHERE
            from_aisle = l_to_cross_aisle
            AND to_aisle = l_from_cross_aisle;

        CURSOR c_aisle_order_cur (
            cp_aisle VARCHAR2
        ) IS
        SELECT
            physical_aisle_order
        FROM
            aisle_info
        WHERE
            name = cp_aisle;

    BEGIN
        o_dist := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);

        IF ( g_forklift_audit ) THEN
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
            l_message := 'Calculate cross aisle distance.  Dock: '
                         || i_dock_num
                         || '  From Aisle: '
                         || i_from_aisle
                         || '  From Bay: '
                         || i_from_bay
                         || '  To Aisle: '
                         || i_to_aisle
                         || '  To Bay: '
                         || i_to_bay;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        lmd_clear_distance(o_dist);

    /*
    ** Determine the values to use in selecting the aisles between the
    ** "from" aisle and the "to" aisle.
    */
        BEGIN
            OPEN c_aisle_order_cur(i_from_aisle);
            FETCH c_aisle_order_cur INTO l_from_seq;
            CLOSE c_aisle_order_cur;
            OPEN c_aisle_order_cur(i_to_aisle);
            FETCH c_aisle_order_cur INTO l_to_seq;
            CLOSE c_aisle_order_cur;
            IF ( l_from_seq IS NULL OR l_to_seq IS NULL ) THEN
                l_from_seq_new := ( ascii(substr(i_from_aisle, 1, 1)) * 100 ) + ascii(substr(i_from_aisle, 2, 1));

                l_to_seq_new := ( ascii(substr(i_to_aisle, 1, 1)) * 100 ) + ascii(substr(i_to_aisle, 2, 1));

                l_use_aisle_name := 'Y';
            ELSE
                l_from_seq_new := l_from_seq;
                l_to_seq_new := l_to_seq;
                l_use_aisle_name := 'N';
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Failed to get the physical aisle order.', sqlcode, sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_aca;
        END;

        IF ( l_ret_val = c_swms_normal ) THEN  
    
    
        /* 
        ** The starting aisle and ending aisle need to be in
        ** ascending order so i_from_aisle and i_to_aisle are
        ** compared and if i_from_aisle > i_to_aisle then the
        ** from and to aisle and bay will be switched.
        */
            IF ( l_from_seq_new > l_to_seq_new ) THEN
                l_hold := l_to_seq_new;
                l_to_seq_new := l_from_seq_new;
                l_from_seq_new := l_hold;
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

            OPEN c_aisle_cur;
            WHILE ( l_done = c_true AND l_ret_val = c_swms_normal ) LOOP
                FETCH c_aisle_cur INTO
                    l_from_cross_aisle,
                    l_to_cross_aisle,
                    l_aisle_dist;
                IF ( sqlcode = c_oracle_not_found ) THEN
                    l_done := c_true;
                ELSIF ( sqlcode <> 0 ) THEN
                /*
                ** Got an oracle error.
                */
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to find aisles for cross aisle processing.', sqlcode, sqlerrm
                    );
                    l_ret_val := c_lm_pt_dist_badsetup_aca;
                ELSE
                    IF ( g_forklift_audit ) THEN
                        l_message := 'Aisle to Aisle Distance  Dock: '
                                     || i_dock_num
                                     || '  From Aisle: '
                                     || l_from_cross_aisle
                                     || '  To Aisle: '
                                     || l_to_cross_aisle;

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_aisle_dist);
                    END IF;

                    OPEN c_cross_c_aisle_cur;
                    FETCH c_cross_c_aisle_cur INTO
                        l_from_cross_bay,
                        l_to_cross_bay;
                    IF ( sqlcode = c_oracle_not_found ) THEN
                    /*
                    ** Did not find a cross aisle which is OK.
                    */
                        CLOSE c_cross_c_aisle_cur;
                        l_cross_aisle_found := c_false;
                        l_done := c_true;
                    ELSIF ( sqlcode = c_swms_normal ) THEN
                    /*
                    ** Found a cross aisle.  Get the bay to bay distance.
                    */
                        CLOSE c_cross_c_aisle_cur;
                        l_cross_aisle_found := c_true;
                        IF ( l_first_fetch = c_true ) THEN
                        /*
                        ** Get the distance from the starting bay to the cross
                        ** bay on the starting aisle.
                        */
                            l_first_fetch := c_false;
                            lmd_clear_distance(l_bay_to_bay_dist);
                            l_ret_val := lmd_get_b2b_on_aisle_dist(l_from_cross_aisle, l_from_bay, l_from_cross_bay, l_bay_to_bay_dist
                            );
                        ELSE
                    
                        /*
                        ** Get the distance between the cross aisle bays
                        ** on the aisle.
                        */

                        /*
                        ** Check that current record "from" aisle is the same
                        ** as the previous record "to" aisle.  If not then
                        ** we are done processing as there is not a continuous
                        ** cross aisle between the source and destination
                        ** aisles or the aisle setup could be incorrect.
                        */
                            IF ( l_previous_to_aisle <> l_from_cross_aisle ) THEN
                                CLOSE c_cross_c_aisle_cur;
                                l_cross_aisle_found := c_false;
                                l_done := c_true;
                                l_buf := 'The previous aisle record \"to\" aisle['
                                         || l_previous_to_aisle
                                         || '] is not the same as the current aisle record \"from\" aisle['
                                         || l_previous_to_aisle
                                         || '].  Causes could be incorrect aisle to aisle distance setup or the aisle_info.physical_aisle_order has not been entered.  Cross aisle distance ignored.'
                                         ;
                                IF ( g_forklift_audit ) THEN
                                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_buf, -1);
                                    NULL;
                                END IF;

                            ELSE
                                lmd_clear_distance(l_bay_to_bay_dist);
                                l_ret_val := lmd_get_b2b_on_aisle_dist(l_from_cross_aisle, l_previous_to_bay, l_from_cross_bay
                                , l_bay_to_bay_dist);
                            END IF;
                        END IF;

                    /*
                    ** Save the "to" cross bay and aisle as they are needed
                    ** in processing the next record.
                    */

                        l_previous_to_bay := l_to_cross_bay;
                        l_previous_to_aisle := l_to_cross_aisle;
                        lmd_add_distance(o_dist, l_bay_to_bay_dist);
                        l_curr_aisle_dist.total_distance := l_curr_aisle_dist.total_distance + l_aisle_dist;
                    ELSE
                
                    /*
                    ** Got an oracle error selecting the cross aisle.
                    */
                        CLOSE c_cross_c_aisle_cur;
                        l_ret_val := c_cross_aisle_sel_fail;
                    END IF;

                END IF;

            END LOOP;  /* end while */

        END IF;

        CLOSE c_aisle_cur;
	 /*
    ** If things normal up to this point and cross aisles have been found
    ** upto the destination aisle then get the distance from the destination
    ** aisle cross bay to the destination bay.
    */
        IF ( l_ret_val = c_swms_normal ) THEN
            IF ( l_cross_aisle_found = c_true ) THEN
                IF ( l_to_aisle = l_to_cross_aisle ) THEN
                /*
                ** Found cross aisles up to the destination aisle.
                */
                    lmd_add_distance(o_dist, l_curr_aisle_dist);
                    lmd_clear_distance(l_bay_to_bay_dist);
                    l_ret_val := lmd_get_b2b_on_aisle_dist(l_to_cross_aisle, l_previous_to_bay, l_to_bay, l_bay_to_bay_dist
                    );
                    IF ( l_ret_val = c_swms_normal ) THEN
                        lmd_add_distance(o_dist, l_bay_to_bay_dist);
                    END IF;
                ELSE
            
                /*
                ** The last aisle processed was not the destination aisle.
                ** Causes could be incorrect aisle to aisle distance setup or
                ** the aisle_info.physical_aisle_order has not been entered.
                ** This is not a fatal error.  Write an aplog message
                ** and set the cross aisle distance to a large value the will
                ** effectively cause the distance not to be used.
                */
                    l_buf := 'The last aisle processed['
                             || l_to_cross_aisle
                             || '] was not the destination aisle['
                             || l_to_aisle
                             || '].  Causes could be incorrect aisle to aisle distance setup or the aisle_info.physical_aisle_order has not been entered.  Cross aisle distance ignored.'
                             ;
                    o_dist.total_distance := c_big_float;
                    IF ( g_forklift_audit ) THEN
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_buf, -1);
                    END IF;

                END IF;
            ELSE
        
            /*
            ** No cross aisles between the starting and ending bays
            ** or the cross aisles did not extend from the starting to
            ** the ending bay.  Set the cross aisle distance to a large
            ** value the will effectively cause the distance not to be used.
            */
                o_dist.total_distance := c_big_float;
            END IF;

            IF ( g_forklift_audit ) THEN
                IF ( o_dist.total_distance = c_big_float ) THEN
                    l_message := 'There are no cross aisles.';
                ELSE
                    l_message := 'The cross aisle distance is '
                                 || o_dist.total_distance
                                 || ' feet.';
                END IF;

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, C_audit_msg_divider, -1);
            END IF; /* end audit */

        END IF;

        return(l_ret_val);
    END lmd_check_cross_aisle_dist;
	
/****************************************************************************
**  Function:  lmd_get_last_drop_point
**
**  Description:
**    This function finds the location of the last completed drop of a
**    forklift batch.
**
**  Parameters:
**      i_psz_batch_no         - The batch to find the last drop point for.
**      o_psz_pallet_id        - The pallet id of the last drop.  Used for
**                               the audit report.
**      o_psz_last_drop_point  - The last drop point.
**
**  Return values:
**    c_swms_normal       - Successful
**    NO_LM_BATCH_FOUND - Could not find the last drop point.
**    DATA_ERROR        - Unhandled type of batch or an oracle error.
**
**  Modification History
**        DATE         DESIGNER       COMMENTS
**     02/17/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_last_drop_point (
        i_psz_batch_no          IN                      batch.batch_no%TYPE,
        o_psz_pallet_id         OUT                     floats.pallet_id%TYPE,
        o_psz_last_drop_point   OUT                     VARCHAR2
    ) RETURN NUMBER AS

        l_ret_val        NUMBER := c_swms_normal;
        l_func_name      VARCHAR2(50) := 'lmd_get_last_drop_point';
        l_message        VARCHAR2(1024);
        l_r_drop_point   pl_lmd_drop_point.t_drop_point_rec;
    BEGIN
        BEGIN
            pl_lmd_drop_point.get_last_drop_point(i_psz_batch_no, l_r_drop_point);
            o_psz_pallet_id := l_r_drop_point.pallet_id;
            o_psz_last_drop_point := l_r_drop_point.drop_point;
        EXCEPTION
            WHEN OTHERS THEN
                l_message := l_func_name
                             || ':  batch_no['
                             || i_psz_batch_no
                             || '[  Error in pl/sql block looking for last drop point';
                pl_text_log.ins_msg_async('WARN', l_func_name, l_message, sqlcode, sqlerrm);
                SELECT
                    ref_no,
                    kvi_from_loc
                INTO
                    o_psz_pallet_id,
                    o_psz_last_drop_point
                FROM
                    batch
                WHERE
                    batch_no = i_psz_batch_no
                    AND ROWNUM <= 1;

        END;

        pl_text_log.ins_msg_async('WARN', l_func_name, 'Found last drop point, i_psz_batch_no['
                                            || i_psz_batch_no
                                            || '] o_psz_pallet_id['
                                            || o_psz_pallet_id
                                            || '], o_psz_last_drop_point['
                                            || o_psz_last_drop_point
                                            || ']', sqlcode, sqlerrm);

        return(l_ret_val);
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Error in pl/sql block when looking for the last drop point.', sqlcode
            , sqlerrm);
            l_ret_val := c_data_error;
            return(l_ret_val);
    END lmd_get_last_drop_point;
	

 
/****************************************************************************
**  Function:  lmd_get_next_point
**
**  Description:
**    This function fetches the ending point for the batch being completed.
**    The ending point will be one of the following:
**       - The kvi_from_loc of the batch the user is signing onto.
**       - The kvi_to_loc of the batch the user is signing onto.
**       - The last completed drop point of a suspended batch which the user
**         is in the process of reattaching to.
**
**    Look for last scanned batch first--status = N.  This is the batch
**       the user is in the process of signing onto.  Earlier in a different
**       function the status was updated to N.
**    Then look for suspended batch first--status = W.  A suspended batch is
**       a batch the operator was in the middle of then broke away to perform
**       another batch.  When the operator finishes this other batch(es) the
**       operator is made active again on the suspended batch.  An example of
**       this is a NDM performed during multi-pallet putaway.  When a
**       user is in the process of reattaching to a W batch the user should
**       not have an N batch.  The program that calls
**       lmf_signon_to_forklift_batch() checks for a suspended batch and if
**       one find then will pass the suspended batch number to
**       lmf_signon_to_forklift_batch().  An example of this is in putaway.pc.
**
**  Parameters:
**      (The char array input parameters need to be null terminated)
**      i_batch_no         - The batch being completed.
**      i_user_id          - User performing the task.
**      io_point            - The ending point.
**
**  Return values:
**    C_SWMS_NORMAL       - Successful
**    C_NO_LM_BATCH_FOUND - Could not find batch suspended batch and could
**                        not find the last scanned batch.  This is OK
**                        when the user is signing onto an indirect.
**    C_DATA_ERROR        - Oracle error occurred.
**
**        DATE         DESIGNER       COMMENTS
**     17/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_next_point (
        i_batch_no   IN           arch_batch.batch_no%TYPE,
        i_user_id    IN           arch_batch.user_id%TYPE,
        io_point     IN OUT       arch_batch.kvi_from_loc%TYPE
    ) RETURN NUMBER AS
        l_func_name   VARCHAR2(30) := 'lmd_get_next_point';  /* Aplog message buffer. */
        l_ret_val     NUMBER := c_swms_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_next_point i_batch_no='
                                            || i_batch_no
                                            || ', i_user_id='
                                            || i_user_id
                                            || ', io_point='
                                            || io_point, sqlcode, sqlerrm);

        BEGIN
		--
		-- Get the ending point for the batch being completed.
		--
            pl_lmd.get_next_point(i_batch_no, replace(i_user_id,'OPS$',NULL), io_point);
            IF ( io_point IS NULL ) THEN
			/*
			** No next point found.  Return C_NO_LM_BATCH_FOUND.
			** The calling object will handle this.*/
        
                l_ret_val := c_no_lm_batch_found;
            END IF; -- end no data found 
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to get the next point', sqlcode, sqlerrm);
                l_ret_val := c_data_error;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_next_point i_batch_no='
                                            || i_batch_no
                                            || ', i_user_id='
                                            || i_user_id
                                            || ', io_point='
                                            || io_point, sqlcode, sqlerrm);

        RETURN l_ret_val;
    END lmd_get_next_point; /* end lmd_get_next_point */
	
/****************************************************************************
**  PROCEDURE:  lmd_segment_distance
**
**  Description:
**    This subroutine segments the distance in total distance into three 
**    distances for KVI calculations.
**
**  Parameters:
**      io_dist - Pointer to distance structure.
**
**        DATE         DESIGNER       COMMENTS
**     17/02/2020      Infosys     Initial version0.0
****************************************************************************/

    PROCEDURE lmd_segment_distance (
        io_dist IN OUT lmd_distance_obj
    ) AS
        l_func_name             VARCHAR2(30) := 'lmd_segment_distance';  /* Aplog message buffer. */
        l_include_accel_decel   VARCHAR2(1) := 'B';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_segment_distance l_include_accel_decel='
                                            || l_include_accel_decel
                                            || ', io_dist.accel_distance='
                                            || io_dist.accel_distance
                                            || ', io_dist.decel_distance='
                                            || io_dist.decel_distance
                                            || ', io_dist.travel_distance='
                                            || io_dist.travel_distance
                                            || ', io_dist.total_distance='
                                            || io_dist.total_distance
                                            || ', io_dist.distance_rate='
                                            || io_dist.distance_rate, sqlcode, sqlerrm);

        CASE ( l_include_accel_decel )
            WHEN 'A' THEN
			/* Include only the accelerate distance. */
                IF ( io_dist.total_distance > c_accelerate_distance ) THEN
                    io_dist.accel_distance := c_accelerate_distance;
                ELSE
                    io_dist.accel_distance := io_dist.total_distance;
                END IF; /* end accel distance set up */

                io_dist.decel_distance := 0.0;
                io_dist.travel_distance := io_dist.total_distance - io_dist.accel_distance;
            WHEN 'D' THEN
			/* Include only the decelerate distance. */
                IF ( io_dist.total_distance > c_decelerate_distance ) THEN
                    io_dist.decel_distance := c_decelerate_distance;
                ELSE
                    io_dist.decel_distance := io_dist.total_distance;
                END IF; /* end accel distance set up */

                io_dist.decel_distance := 0.0;
                io_dist.travel_distance := io_dist.total_distance - io_dist.decel_distance;
            WHEN 'B' THEN
			/*
			** Include both the accelerate and decelerate distance.  If the
			** total distance is less than the accelerate and decelerate distances
			** then prorate the distances.
			*/
                IF ( io_dist.total_distance > ( c_accelerate_distance + c_decelerate_distance ) ) THEN
                    io_dist.accel_distance := c_accelerate_distance;
                    io_dist.decel_distance := c_decelerate_distance;
                    io_dist.travel_distance := io_dist.total_distance - ( io_dist.accel_distance + io_dist.decel_distance );

                ELSE
                    io_dist.accel_distance := io_dist.total_distance * ( c_accelerate_distance / ( c_accelerate_distance + c_decelerate_distance
                    ) );

                    io_dist.decel_distance := io_dist.total_distance - io_dist.accel_distance;
                    io_dist.travel_distance := 0.0;
                END IF; /* end accel distance set up */
            WHEN 'N' THEN
			/* Do not include the accelerate and decelerate distances. */
                io_dist.accel_distance := 0.0;
                io_dist.decel_distance := 0.0;
                io_dist.travel_distance := io_dist.total_distance;
            ELSE
                pl_text_log.ins_msg_async('WARN', l_func_name, 'variable l_include_accel_decel has an unhandled value of ' || l_include_accel_decel
                , sqlcode, sqlerrm);
        END CASE; /* end case include accel decel*/

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_segment_distance l_include_accel_decel='
                                            || l_include_accel_decel
                                            || ', io_dist.accel_distance='
                                            || io_dist.accel_distance
                                            || ', io_dist.decel_distance='
                                            || io_dist.decel_distance
                                            || ', io_dist.travel_distance='
                                            || io_dist.travel_distance
                                            || ', io_dist.total_distance='
                                            || io_dist.total_distance
                                            || ', io_dist.distance_rate='
                                            || io_dist.distance_rate, sqlcode, sqlerrm);

    END lmd_segment_distance; /* end lmd_segment_distance*/
	
/****************************************************************************
**  PROCEDURE:  lmd_add_distance
**
**  Description:
**    This subroutine adds the distances in the new object to the old
**    object.
**
**  Parameters:
**      io_old - old distance object.
**      i_new  - new distance object.
**
**        DATE         DESIGNER       COMMENTS
**     17/02/2020      Infosys     Initial version0.0
****************************************************************************/

    PROCEDURE lmd_add_distance (
        io_old   IN OUT   lmd_distance_obj,
        i_new    IN       lmd_distance_obj
    ) AS
        l_func_name VARCHAR2(30) := 'lmd_add_distance';  /* Aplog message buffer. */
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_add_distance', sqlcode, sqlerrm);
        io_old.total_distance := io_old.total_distance + i_new.total_distance;
        io_old.accel_distance := io_old.accel_distance + i_new.accel_distance;
        io_old.decel_distance := io_old.decel_distance + i_new.decel_distance;
        io_old.tia_time := io_old.tia_time + i_new.tia_time;
        io_old.travel_distance := io_old.travel_distance + i_new.travel_distance;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_add_distance', sqlcode, sqlerrm);
    END lmd_add_distance; /* end lmd_add_distance */
	
/****************************************************************************
**  PROCEDURE:  lmd_clear_distance
**
**  Description:
**    This subroutine clears the specified distance structure.
**
**  Parameters:
**      io_dist - Pointer to distance structure.
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/

    PROCEDURE lmd_clear_distance (
        io_dist IN OUT lmd_distance_obj
    ) AS
        l_func_name VARCHAR2(30) := 'lmd_clear_distance';  /* Aplog message buffer. */
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_clear_distance', sqlcode, sqlerrm);
        io_dist := lmd_distance_obj(0,0,0,0,0,0);
        io_dist.total_distance := 0.0;
        io_dist.accel_distance := 0.0;
        io_dist.decel_distance := 0.0;
        io_dist.travel_distance := 0.0;
        io_dist.tia_time := 0.0;
        io_dist.distance_rate := 0.0;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_clear_distance', sqlcode, sqlerrm);
    END lmd_clear_distance; /* end lmd_clear_distance */
	
/****************************************************************************
**  Function:  lmd_get_warehouse_to_wh_dist
**
**  Description:
**    This subroutine finds the distance between the two warehouses for the
**    specified docks.
**
**  Parameters:
**    i_from_dock_num - From dock.
**    i_to_dock_num   - To dock.
**    io_dist         - Distance.
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/

    FUNCTION lmd_get_warehouse_to_wh_dist (
        i_from_dock_num      IN                   point_distance.point_dock%TYPE,
        i_to_dock_num        IN                   point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name     VARCHAR2(40) := 'lmd_get_warehouse_to_wh_dist';  /* Aplog message buffer. */
        l_w_to_w_dist   NUMBER := 0.0;
        l_ret_val       NUMBER := c_swms_normal;
        l_vc_message    VARCHAR2(1024);
        l_dummy         point_distance.point_a%TYPE;  /* Work area */
	-- This cursor selects the WW distance.  Select the dock level
	-- record first if there is one.
        CURSOR c_point_distance_cur IS
        SELECT
            1 sortval,
            point_dist      /* Dock level */
        FROM
            point_distance
        WHERE
            point_type = 'WW'
            AND point_dock = i_from_dock_num
            AND point_a = i_from_dock_num
            AND point_b = i_to_dock_num
        UNION
        SELECT
            2 sortval,
            point_dist      /* Area level */
        FROM
            point_distance
        WHERE
            point_type = 'WW'
            AND point_dock = i_from_dock_num
            AND point_a = substr(i_from_dock_num, 1, 1)
            AND point_b = substr(i_to_dock_num, 1, 1)
        ORDER BY
            1;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_warehouse_to_wh_dist(i_from_dock_num='
                                            || i_from_dock_num
                                            || ', i_to_dock_num'
                                            || i_to_dock_num
                                            || ', io_dist)', sqlcode, sqlerrm);

        BEGIN
            OPEN c_point_distance_cur;
            FETCH c_point_distance_cur INTO
                l_dummy,
                l_w_to_w_dist;
            CLOSE c_point_distance_cur;
            IF ( l_w_to_w_dist IS NULL ) THEN
			/* Found no point distance record therefore the distance is not setup. */
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE The warehouse to warehouse point distance is not setup.', sqlcode
                , sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wtw;
            ELSE
			/* Found no point distance record. */
                io_dist.total_distance := l_w_to_w_dist;
            END IF; /* end no point distance record process */

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from warehouse to warehouse.', sqlcode
                , sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wtw;
        END;

        IF ( ( g_forklift_audit  ) AND ( l_ret_val = c_swms_normal ) ) THEN
            l_vc_message := 'Warehouse to Warehouse Distance  From Dock: '
                            || i_from_dock_num
                            || '  To Dock: '
                            || i_to_dock_num;
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_vc_message, l_w_to_w_dist);
        END IF; /* end audit */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_warehouse_to_wh_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_warehouse_to_wh_dist; /* end lmd_get_warehouse_to_wh_dist */
	

/****************************************************************************
**  Function:  lmd_get_warehouse_to_door_dist
**
**  Description:
**    This subroutine finds the distance between a dock and the closest
**    door in another dock for docks in different warehouses.
**
**  Parameters:
**    i_from_dock_num - "from" dock.
**    i_to_dock_num   - "to" dock.
**    io_first_door   - Door in the "to" dock that is closest to the
**                      "from" dock.  Determined by this function.
**    io_dist         - Distance between the "from" dock and the closest
**                      door in the "to" dock.
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/

    FUNCTION lmd_get_warehouse_to_door_dist (
        i_from_dock_num      IN                   point_distance.point_dock%TYPE,
        i_to_dock_num        IN                   point_distance.point_a%TYPE,
        io_first_door        IN OUT               point_distance.point_b%TYPE,
        io_dist              IN OUT               lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name        VARCHAR2(40) := 'lmd_get_warehouse_to_door_dist';  /* Aplog message buffer. */
        l_w_to_door_dist   NUMBER := 0.0;
        l_first_door       point_distance.point_b%TYPE;
        l_ret_val          NUMBER := c_swms_normal;
        l_vc_message       VARCHAR2(1024);
	-- This cursor selects the warehouse to first door distance and
	-- the door.  The door is used elsewhere for other distance
	-- calculations.
        CURSOR c_point_distance_cur IS
        SELECT
            nvl(point_dist, 0),
            point_b
        FROM
            point_distance
        WHERE
            point_dock = i_from_dock_num
            AND point_type = 'WD'
            AND ( point_a = i_to_dock_num
                  OR point_a = substr(i_to_dock_num, 1, 1) )
        ORDER BY
            point_a DESC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_warehouse_to_door_dist(i_from_dock_num='
                                            || i_from_dock_num
                                            || ', i_to_dock_num'
                                            || i_to_dock_num
                                            || ', io_first_door, io_dist)', sqlcode, sqlerrm);

        io_first_door := NULL;
        BEGIN
            OPEN c_point_distance_cur;
            FETCH c_point_distance_cur INTO
                l_w_to_door_dist,
                l_first_door;
            CLOSE c_point_distance_cur;
            IF ( l_first_door IS NULL ) THEN
			/* Found no point distance record therefore the distance is not setup. */
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE The warehouse to first door point distance is not setup.', sqlcode
                , sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wfd;
            ELSE
			/* Found the distance. */
                io_first_door := l_first_door;
                io_dist.total_distance := l_w_to_door_dist;
            END IF; /* end no point distance record process */

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from warehouse dock to first door on dock.'
                , sqlcode, sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wfd;
        END;

        IF ( ( g_forklift_audit  ) AND ( l_ret_val = c_swms_normal ) ) THEN
            l_vc_message := 'Warehouse to Door Distance  From Dock: '
                            || i_from_dock_num
                            || ' To Dock: '
                            || i_to_dock_num
                            || '  To Door: '
                            || io_first_door;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_vc_message, l_w_to_door_dist);
        END IF; /* end audit */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_warehouse_to_door_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_warehouse_to_door_dist; /* end lmd_get_warehouse_to_door_dist */
	
/****************************************************************************
**  Function:  lmd_get_wh_to_aisle_dist
**
**  Description:
**    This subroutine finds the distance between a dock and the closest aisle
**    in another dock for docks in different warehouses.
**
**  Parameters:
**      i_from_dock_num - "from" dock.
**      i_to_dock_num   - "to" dock.
**      io_first_aisle  - Aisle in the "to" dock that is closest to the
**                        "from"dock.  This aisle is determined by
**                        this function.
**      io_dist         - Distance between the "from" dock and the closest
**                        aisle in the "to" dock".
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_wh_to_aisle_dist (
        i_from_dock_num   IN                point_distance.point_dock%TYPE,
        i_to_dock_num     IN                point_distance.point_a%TYPE,
        io_first_aisle    IN OUT            point_distance.point_b%TYPE,
        io_dist           IN OUT            lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name         VARCHAR2(40) := 'lmd_get_wh_to_aisle_dist';  /* Aplog message buffer. */
        l_w_to_aisle_dist   NUMBER := 0.0;
        l_first_aisle       point_distance.point_b%TYPE;
        l_ret_val           NUMBER := c_swms_normal;
        l_vc_message        VARCHAR2(1024);
	-- This cursor orders by point_a so that the point distance for the
	-- dock is selected first if there are records for the dock
	-- and the area.
        CURSOR c_point_distance_cur IS
        SELECT
            nvl(point_dist, 0),
            point_b
        FROM
            point_distance
        WHERE
            point_dock = i_from_dock_num
            AND point_type = 'WA'
            AND ( point_a = i_to_dock_num
                  OR point_a = substr(i_to_dock_num, 1, 1) )
        ORDER BY
            point_a DESC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_wh_to_aisle_dist(i_from_dock_num='
                                            || i_from_dock_num
                                            || ', i_to_dock_num'
                                            || i_to_dock_num
                                            || ', io_first_aisle, io_dist)', sqlcode, sqlerrm);

        io_first_aisle := NULL;
        BEGIN
            OPEN c_point_distance_cur;
            FETCH c_point_distance_cur INTO
                l_w_to_aisle_dist,
                l_first_aisle;
            CLOSE c_point_distance_cur;
            IF ( l_first_aisle IS NULL ) THEN
			/* Found no point distance record therefore the distance is not setup. */
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE The warehouse to first aisle point distance is not setup.', sqlcode
                , sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wfa;
            ELSE
			/* Found the distance. */
                io_first_aisle := l_first_aisle;
                io_dist.total_distance := l_w_to_aisle_dist;
            END IF; /* end no point distance record process */

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from warehouse to first aisle on dock.'
                , sqlcode, sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_wfa;
        END;

        IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
            l_vc_message := 'Warehouse to Aisle Distance  From Dock: '
                            || i_from_dock_num
                            || ' To Dock: '
                            || i_to_dock_num
                            || '  To Aisle: '
                            || io_first_aisle;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_vc_message, l_w_to_aisle_dist);
        END IF; /* end audit */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_wh_to_aisle_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_wh_to_aisle_dist; /* end lmd_get_wh_to_aisle_dist */
	
/****************************************************************************
**  Function:  lmd_get_batch_dist
**
**  Description:
**    This subroutine calculates the total distance traveled for the specified
**    batch.
**
**  Parameters:
**      i_batch_no        - Batch number for batch needing distance calculation.
**      i_is_parent       - Flag denoting whether or not the specified batch
**                          is a parent.
**      i_e_rec           - Pointer to equipment tmu values.
**      i_3_part_move_bln - Designates if 3 part move for demand replenishments
**                          is active.  For any other type of forklift batch
**                          the value will be FALSE.
**      io_last_point     - Last Point.
**      io_dist           - Total distance traveled processing batch.
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_batch_dist (
        i_batch_no          IN                  batch.batch_no%TYPE,
        i_is_parent         IN                  VARCHAR2,
        i_e_rec             IN                  pl_lm_goal_pb.type_lmc_equip_rec,
        i_3_part_move_bln   IN                  NUMBER,
        io_last_point       IN OUT              VARCHAR2,
        io_dist             IN OUT              lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name       VARCHAR2(40) := 'lmd_get_batch_dist';  /* Aplog message buffer. */
        l_ret_val         NUMBER := c_swms_normal;
        l_dist            lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_b_rec           lmd_batch_rec_obj := lmd_batch_rec_obj(0, 0, 0, 0, 0, 0, 0, 0);
        l_last_location   VARCHAR2(10);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_batch_dist i_batch_no='
                                            || i_batch_no
                                            || ', i_is_parent='
                                            || i_is_parent, sqlcode, sqlerrm);

        IF ( i_is_parent = 'Y' ) THEN
            l_b_rec.parent_batch_no := i_batch_no;
            l_last_location := rpad(l_last_location, 10, ' ');
            l_ret_val := lmd_calc_parent_dist(l_b_rec, i_e_rec, l_last_location, l_dist);
            IF ( l_ret_val = c_swms_normal ) THEN
                io_last_point := l_last_location;
            END IF; /* end last point calc */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'drops distances (l_dist.total_distance='
                                                || l_dist.total_distance
                                                || ', l_dist.accel_distance='
                                                || l_dist.accel_distance
                                                || ', l_dist.decel_distance='
                                                || l_dist.decel_distance
                                                || ', l_dist.travel_distance='
                                                || l_dist.travel_distance
                                                || ', l_dist.distance_rate='
                                                || l_dist.distance_rate
                                                || ')', sqlcode, sqlerrm);

        ELSE
            l_b_rec.batch_no := i_batch_no;
            l_ret_val := lmd_calc_batch_dist(l_b_rec, i_e_rec, l_dist);
            IF ( l_ret_val = c_swms_normal ) THEN
                io_last_point := l_b_rec.dest_loc;
            END IF; /* end last point calc */
        END IF; /* end is parent check */

        IF ( l_ret_val = c_swms_normal ) THEN
            lmd_add_distance(io_dist, l_dist);
        END IF; /* end add distance */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_batch_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_batch_dist; /* end lmd_get_batch_dist */
	

/****************************************************************************
**  Function:  lmd_get_next_point_dist
**
**  Description:
**    Calculates the distance from the last point specified to the source 
**    of the next batch the user will process.
**
**  Parameters:
**      i_batch_no           - The batch being completed.
**      i_user_id            - User performing the task.
**      i_last_point         - Last point visited of the batch being
**                             completed.
**      i_e_rec              - Pointer to equipment tmu values.
**      i_3_part_move_bln    - Designates if 3 part move for demand
**                             replenishments is active.  For any other
**                             type of forklift batch the value will be
**                             FALSE.
**      io_dist              - Pointer to distance values to be returned.
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_next_point_dist (
        i_batch_no          IN                  batch.batch_no%TYPE,
        i_user_id           IN                  VARCHAR2,
        i_last_point        IN                  VARCHAR2,
        i_e_rec             IN                   pl_lm_goal_pb.type_lmc_equip_rec,
        i_3_part_move_bln   IN                  NUMBER,
        io_dist             IN OUT              lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(40) := 'lmd_get_next_point_dist';  /* Aplog message buffer. */
        l_ret_val      NUMBER := c_swms_normal;
        l_dist         lmd_distance_obj := NEW lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_next_point   VARCHAR2(10);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_next_point_dist i_batch_no='
                                            || i_batch_no
                                            || ', i_user_id='
                                            || i_user_id
                                            || ', i_last_point='
                                            || i_last_point, sqlcode, sqlerrm);

        l_ret_val := lmd_get_next_point(i_batch_no, i_user_id, l_next_point);
        IF ( l_ret_val = c_swms_normal ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'next_point=' || l_next_point, sqlcode, sqlerrm);
            l_ret_val := lmd_get_pt_to_pt_dist(i_last_point, l_next_point, i_e_rec, l_dist);
            IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, i_last_point, l_next_point, l_dist);
            END IF; /* end audit */

            IF ( l_ret_val = c_swms_normal ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'next_loc distances (l_dist.total_distance='
                                                    || l_dist.total_distance
                                                    || ', l_dist.accel_distance='
                                                    || l_dist.accel_distance
                                                    || ', l_dist.decel_distance='
                                                    || l_dist.decel_distance
                                                    || ', l_dist.travel_distance'
                                                    || l_dist.travel_distance
                                                    || ', l_dist.distance_rate='
                                                    || l_dist.distance_rate
                                                    || ')', sqlcode, sqlerrm);

                lmd_add_distance(io_dist, l_dist);
            END IF; /* end add distance */

        END IF; /* end get next point */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_next_point_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_next_point_dist; /* end lmd_get_next_point_dist */
	

/****************************************************************************
**  Function:  lmd_get_dr_to_bay_dist_dtb
**
**  Description:
**    This subroutine finds the shortest distance between the specified door
**    and bay on the specified dock using door to bay point distances. 
**    This comes into play for docks that run parallel to the aisles.
**    When door to bay distances are setup, point type DB, there should
**    be a distance from the door to the front of the aisle and a distance
**    from the door to the end of the aisle.
**
**    First the distance from the door to the bay setup as a point distance
**    is determined then the distance from the bay to the destination bay is
**    determined.  If the destination bay is on the aisle that has the
**    door to bay distances setup then the distance from the door directly
**    to the bay is calculated.
**
**    A door can have a distance setup to more than one bay.  At most four
**    bays will be selected when determining the shortest distance.
**       - The destination bay if it is setup as a door to bay distance.
**       - The bay setup closest to the front of the aisle.  There should be
**         a distance setup from the door to the front of the aisle.
**       - The bay setup closest to the end of the aisle.  There should be
**         a distance setup from the door to the end of the aisle.
**       - The bay setup nearest the cross bay if a cross bay exists.
**
**    Following is a sample setup of door to bay distances in the
**    POINT_DISTANCE table.  POINT_B must have the aisle and bay.
**    The last sample record is the distance to the bay at the cross aisle.
**
**     POINT_DOCK   POINT_TYPE   POINT_A   POINT_B   POINT_DIST
**     ----------   ----------   -------   -------   ----------
**        D3           DB         D380      DB00        300
**        D3           DB         D380      DB99        610
**        D3           DB         D380      DB45        340
**
**  Parameters:
**      i_dock_num  - Specified dock.  This needs to be the door dock number.
**      i_from_door - Specified door.
**      i_to_bay    - Specified bay.  Can either be a location or the aisle
**                    and bay (ie. from haul).
**                    Examples:  DB01A2, DC03
**      o_dist      - Distance between the door and the bay on the
**                    specified dock.
**
**
**                     Side Dock
**
**          Door         Door         Door
**  +------+====+-------+=====+------+====+------------+
**  |                                                  |
**  |                    cross bay                     |
**  |   +-----------------+ * +-----------------+      +
**  |                                                  |Door      Front Dock
**  |   +-----------------+   +-----------------+      +
**  |                                                  |
**  |   +-----------------+   +-----------------+      +
**  |                                                  |Door
**  |   +-----------------+   +-----------------+      +
**  |                       ^                          |
**  +-----------------------|--------------------------+
**                          |
**                     Cross Aisle
**
**        DATE         DESIGNER       COMMENTS
**     18/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_dr_to_bay_dist_dtb (
        i_dock_num    IN            point_distance.point_dock%TYPE,
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_bay      IN            bay_distance.bay%TYPE,
        o_dist        OUT           lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name                  VARCHAR2(50) := 'lmd_get_dr_to_bay_dist_dtb';
        l_done                       NUMBER := c_false;
        l_ret_val                    NUMBER := c_swms_normal;
        l_db_aislebay                VARCHAR2(10);      /* Door to bay distance bay */
        l_db_aislebay_ind            NUMBER;
        l_db_min_aislebay            VARCHAR2(10);  	   /* Door to bay distance bay */
        l_db_min_aislebay_ind        NUMBER;
        l_db_min_aislebay_dist       NUMBER;
        l_db_min_aislebay_dist_ind   NUMBER;
        l_db_max_aislebay            VARCHAR2(10); 	   /* Door to bay distance bay */
        l_db_max_aislebay_ind        NUMBER;
        l_db_max_aislebay_dist       NUMBER;
        l_db_max_aislebay_dist_ind   NUMBER;
        l_dummy1                     NUMBER;        /* Place to hold a fetched value */
        l_dummy1_ind                 NUMBER;
        l_dummy2                     VARCHAR2(10); 	   /* Place to hold a fetched value */
        l_dummy2_ind                 NUMBER;
        l_dist                       NUMBER := 0.0; /* Door to bay distance */
        l_dist_ind                   NUMBER;
        l_to_aislebay                VARCHAR2(4);   /* Destination bay. Includes aisle and bay.  No position or level. */
        l_to_aisle                   VARCHAR2(2);   /* Destination aisle */
        l_bay_to_bay_dist            lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0); --doubt
        l_door_to_bay_dist           lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0); --doubt
        l_save_bay                   VARCHAR2(10);
        l_message                    VARCHAR2(1024); 

	/*
    ** This cursor selects the two bays closest to the destination bay when
    ** the destination aisle has door to bay distances setup.
    ** If the destination bay is setup as a door to bay distance then
    ** this will be the first record selected.  No more than two records
    ** will be selected.
    **
    ** Note that only one bay will be selected if only one door to bay
    ** distance is setup.
    */
        CURSOR c_db_dist_same_aisle_cur IS
        SELECT
            pd.point_b,
            nvl(pd.point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            pd.point_b
        FROM
            point_distance pd
        WHERE
            point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a = i_from_door
            AND substr(pd.point_b, 1, 2) = l_to_aisle
            AND point_b = (
                SELECT
                    MAX(pd2.point_b)
                FROM
                    point_distance pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND substr(pd2.point_b, 1, 2) = substr(pd.point_b, 1, 2)
                    AND pd2.point_b <= l_to_aislebay
            )
        UNION
        SELECT
            pd.point_b,
            nvl(pd.point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            pd.point_b
        FROM
            point_distance pd
        WHERE
            point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a = i_from_door
            AND substr(pd.point_b, 1, 2) = l_to_aisle
            AND point_b = (
                SELECT
                    MIN(pd2.point_b)
                FROM
                    point_distance pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND substr(pd2.point_b, 1, 2) = substr(pd.point_b, 1, 2)
                    AND pd2.point_b > l_to_aislebay
            )
        ORDER BY
            3,
            4;

	/*
    ** This cursor selects the door to bay distances setup for the door.
    ** The min bay, max bay and the bay nearest the cross bay (if there is
    ** a cross aisle) for each aisle defined for the door are selected.
    ** This cursor is used when the destination aisle does not have any
    ** door to bay distances.
    */

        CURSOR c_db_dist_cur IS
        SELECT
            pd.point_b,
            nvl(pd.point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            pd.point_b
        FROM
            point_distance pd
        WHERE
            point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a = i_from_door
            AND point_b = (
                SELECT
                    MIN(pd2.point_b)
                FROM
                    point_distance pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND substr(pd2.point_b, 1, 2) = substr(pd.point_b, 1, 2)
            )
        UNION
        SELECT
            pd.point_b,
            nvl(pd.point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            pd.point_b
        FROM
            point_distance pd
        WHERE
            point_type = 'DB'
            AND point_dock = i_dock_num
            AND point_a = i_from_door
            AND point_b = (
                SELECT
                    MAX(pd2.point_b)
                FROM
                    point_distance pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND substr(pd2.point_b, 1, 2) = substr(pd.point_b, 1, 2)
            )
        UNION
        SELECT
            pd.point_b,
            nvl(pd.point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            point_b
        FROM
            forklift_cross_aisle   ca,
            point_distance         pd
        WHERE
            pd.point_type = 'DB'
            AND pd.point_dock = i_dock_num
            AND pd.point_a = i_from_door
            AND ca.from_aisle = substr(pd.point_b, 1, 2)
            AND abs(ca.from_bay - substr(pd.point_b, 3, 2)) = (
                SELECT
                    MIN(abs(ca2.from_bay - substr(pd2.point_b, 3, 2)))
                FROM
                    forklift_cross_aisle   ca2,
                    point_distance         pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND ca2.from_aisle = substr(pd2.point_b, 1, 2)
            )
        UNION
        SELECT
            point_b,
            nvl(point_dist, 0),
            DECODE(pd.point_b, l_to_aislebay, 0, 1),
            pd.point_b
        FROM
            forklift_cross_aisle   ca,
            point_distance         pd
        WHERE
            pd.point_type = 'DB'
            AND pd.point_dock = i_dock_num
            AND pd.point_a = i_from_door
            AND ca.to_aisle = substr(pd.point_b, 1, 2)
            AND abs(ca.to_bay - substr(pd.point_b, 3, 2)) = (
                SELECT
                    MIN(abs(ca2.to_bay - substr(pd2.point_b, 3, 2)))
                FROM
                    forklift_cross_aisle   ca2,
                    point_distance         pd2
                WHERE
                    pd2.point_type = pd.point_type
                    AND pd2.point_dock = pd.point_dock
                    AND pd2.point_a = pd.point_a
                    AND ca2.to_aisle = substr(pd2.point_b, 1, 2)
            )
        ORDER BY
            3,
            4;

    BEGIN
        o_dist := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_to_aisle:=substr(i_to_bay,1,2);
        l_to_aislebay:=substr(i_to_bay,1,4);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_dock_num = '
                                            || i_dock_num
                                            || ' i_from_door= '
                                            || i_from_door
                                            || ' i_dock_num= '
                                            || i_dock_num, sqlcode, sqlerrm);

        o_dist.total_distance := c_big_float;
        --l_to_aisle := i_to_bay;
        --l_to_aislebay := i_to_bay;
        IF ( g_forklift_audit ) THEN
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
            l_message := concat('Calculate door to bay distance using door to bay point distances. Dock ', concat(i_dock_num, concat
            (' Door ', concat(i_from_door, concat(' Bay ', l_to_aislebay)))));

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_db_min_aislebay_dist := c_big_float;
        l_db_max_aislebay_dist := c_big_float;
        BEGIN
        OPEN c_db_dist_same_aisle_cur;
        FETCH c_db_dist_same_aisle_cur INTO
            l_db_min_aislebay,
            l_db_min_aislebay_dist,
            l_dummy1,
            l_dummy2;
        IF c_db_dist_same_aisle_cur%notfound THEN
           pl_text_log.ins_msg_async('INFO', l_func_name, 'No records to select for door to bay distances on same aisle as destination bay.'
            , sqlcode, sqlerrm);
        END IF;
        IF ( g_forklift_audit ) THEN
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Found door to bay distance setup. From Door= '
                                                || i_from_door
                                                || 'To Bay= '
                                                || l_db_min_aislebay, sqlcode, sqlerrm);

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_db_min_aislebay_dist);
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
        END IF;
        EXCEPTION
        WHEN OTHERS THEN
         pl_text_log.ins_msg_async('INFO', l_func_name, 'LMD ORACLE Unable to select door to bay distances on same aisle as destination bay.'
            , sqlcode, sqlerrm);
            l_ret_val := rf.status_lm_pt_dist_badsetup_dta;
            END;
        --close c_db_dist_same_aisle_cur;
        

        IF ( l_db_min_aislebay = l_to_aislebay ) THEN
            o_dist.total_distance := l_db_min_aislebay_dist;
            l_save_bay := l_to_aislebay;
            IF ( g_forklift_audit ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Destination bay is setup as a door to bay distance', sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_db_min_aislebay_dist);
            END IF;

        ELSE
            FETCH c_db_dist_same_aisle_cur INTO
                l_db_max_aislebay,
                l_db_max_aislebay_dist,
                l_dummy1,
                l_dummy2;
            IF ( g_forklift_audit ) THEN
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Found door to bay distance setup. From Door= '
                                                    || i_from_door
                                                    || ' To Bay= '
                                                    || l_db_max_aislebay, sqlcode, sqlerrm);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
            END IF;

        END IF;

        CLOSE c_db_dist_same_aisle_cur;
	/*
    ** If there are door to bay distances for the destination aisle and
    ** one of these was not the destination bay then calculate the
    ** distance to the destination bay.
    */
        IF ( o_dist.total_distance = c_big_float AND l_db_min_aislebay_dist != c_big_float AND l_ret_val = c_swms_normal ) THEN
            IF ( l_db_max_aislebay_dist != c_big_float ) THEN
			/*
            ** Found two door to bay distances going to the
            ** destination aisle.  Calculate the distance from the door
            ** directly to the destination bay.
            */
                IF ( g_forklift_audit ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'There are door to bay distances setup for the destination aisle', sqlcode
                    , sqlerrm);
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                l_ret_val := lmd_get_dr_to_bay_direct_dist(i_dock_num, i_from_door, i_to_bay, l_db_min_aislebay, l_db_max_aislebay

                , l_db_min_aislebay_dist, l_db_max_aislebay_dist, o_dist);

                IF ( o_dist.total_distance = c_big_float AND l_ret_val = c_swms_normal ) THEN
				/*
                ** Unable to calculate the distance from the door directly
                ** to the destination bay.  Use the shortest of the following
                ** as the distance from the door to the destination bay.
                ** - Door -> min bay -> destination bay 
                ** - Door -> max bay -> destination bay 
                */
                    IF ( g_forklift_audit ) THEN
                        l_message := concat('Unable to calculate the distance from door directly to bay. Door ', concat(i_from_door
                        , concat(' Bay ', l_to_aislebay)));

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Use the shortest of the following as the distance from the door to the destination bay using door to bay distances'
                        , -1);
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Distance from i_from_door to l_db_min_aislebay = ' || l_db_min_aislebay_dist
                        , sqlcode, sqlerrm);
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Distance from i_from_door to l_db_max_aislebay = ' || l_db_max_aislebay_dist
                        , sqlcode, sqlerrm);
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    lmd_clear_distance(l_bay_to_bay_dist);
                    l_ret_val := lmd_get_bay_to_bay_dist(i_dock_num, l_db_min_aislebay, i_to_bay, l_bay_to_bay_dist);
                    IF ( l_ret_val = c_swms_normal ) THEN
                        o_dist.total_distance := l_db_min_aislebay_dist + l_bay_to_bay_dist.total_distance;
                        l_save_bay := l_db_min_aislebay;
                        lmd_clear_distance(l_bay_to_bay_dist);
                        IF ( l_ret_val = c_swms_normal AND ( o_dist.total_distance > ( l_db_max_aislebay_dist + l_bay_to_bay_dist
                        .total_distance ) ) ) THEN
                            o_dist.total_distance := l_db_max_aislebay_dist + l_bay_to_bay_dist.total_distance;
                            l_save_bay := l_db_max_aislebay;
                        END IF;

                    END IF;

                END IF;

            ELSE 
			/*
            ** Found one door to bay distance going to the destination
            ** aisle meeting the selection criteria.  The distance to the
            ** destination bay will be from the door to the "door to bay"
            ** bay then to the destination bay.
            */
                IF ( g_forklift_audit ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'The distance from i_from_door to l_to_aislebay using door to bay distances will be from i_from_door to l_db_min_aislebay to l_to_aislebay.'
                    , sqlcode, sqlerrm);
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                lmd_clear_distance(l_bay_to_bay_dist);
                l_ret_val := lmd_get_bay_to_bay_dist(i_dock_num, l_db_min_aislebay, i_to_bay, l_bay_to_bay_dist);
                IF ( l_ret_val = c_swms_normal ) THEN
                    o_dist.total_distance := l_bay_to_bay_dist.total_distance + l_db_min_aislebay_dist;
                    l_save_bay := l_db_min_aislebay;
                END IF;

            END IF;
        END IF;

        IF ( o_dist.total_distance = c_big_float AND l_ret_val = c_swms_normal ) THEN
            l_done := c_false;
            OPEN c_db_dist_cur;
            WHILE ( l_done = c_true AND l_ret_val = c_swms_normal ) LOOP
                BEGIN
                    FETCH c_db_dist_cur INTO
                        l_db_aislebay,
                        l_dist,
                        l_dummy1,
                        l_dummy2;
                    IF c_db_dist_cur%notfound THEN
                        l_done := c_true;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'LMD ORACLE Unable to calculate distance from the door to the bay.', sqlcode
                        , sqlerrm);
                        l_ret_val := rf.status_lm_pt_dist_badsetup_dta;
                END;

                IF ( g_forklift_audit ) THEN
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
                    l_message := 'Found door to bay distance setup. From Door= '
                                 || i_from_door
                                 || ' To Bay= '
                                 || l_db_aislebay;
                    pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, l_dist);
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, c_audit_msg_divider, -1);
                END IF;

                lmd_clear_distance(l_bay_to_bay_dist);
                l_ret_val := lmd_get_bay_to_bay_dist(i_dock_num, l_db_aislebay, i_to_bay, l_bay_to_bay_dist);
                IF ( l_ret_val = c_swms_normal ) THEN
                    IF ( o_dist.total_distance > ( l_bay_to_bay_dist.total_distance + l_dist ) ) THEN
                        o_dist.total_distance := l_bay_to_bay_dist.total_distance + l_dist;
                        l_save_bay := l_db_aislebay;
                    END IF;
                END IF;

            END LOOP;

            CLOSE c_db_dist_cur;
        END IF;

        IF ( g_forklift_audit AND l_ret_val = c_swms_normal ) THEN
            IF ( o_dist.total_distance = c_big_float ) THEN
                l_message := 'No Door to Bay Distances found for door = ' || i_from_door;
                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            ELSE
                l_message := 'Shortest Door to Bay Distance Using Door to Bay Distances. Dock = '
                             || i_dock_num
                             || ' From Door= '
                             || i_from_door
                             || ' To Bay= '
                             || l_save_bay
                             || ' Then To Bay= '
                             || l_to_aislebay;

                pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, o_dist.total_distance);
            END IF;
        END IF;

        RETURN l_ret_val;
    END lmd_get_dr_to_bay_dist_dtb;
	
/****************************************************************************
**  Function:  lmd_get_door_to_door_dist
**
**  Description:
**    This subroutine finds the distance between two doors within the
**    same area.  The doors can be on different docks but the docks need
**    to be in the same area.
**     
**  Parameters:
**    i_from_door      		- Starting door.
**    i_to_door        		- Ending door.
**    io_dist           	- Distance between the specified doors.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_door_to_door_dist (
        i_from_door   IN            point_distance.point_a%TYPE,
        i_to_door     IN            point_distance.point_b%TYPE,
        io_dist       IN OUT        lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name           VARCHAR2(40) := 'lmd_get_door_to_door_dist';  /* Aplog message buffer. */
        l_ret_val             NUMBER := c_swms_normal;
        l_door_to_door_dist   NUMBER := 0.0;
        l_from_dock_no        point_distance.point_dock%TYPE;
        l_to_dock_no          point_distance.point_dock%TYPE;
        l_message             VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_door_to_door_dist i_from_door='
                                            || i_from_door
                                            || ', i_to_door='
                                            || i_to_door
                                            || ', io_dist)', sqlcode, sqlerrm);
	
	/* Extract the dock numbers from the doors. */

        io_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        l_from_dock_no := substr(i_from_door, 1, 2);
        l_to_dock_no := substr(i_to_door, 1, 2);
        IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
            l_message := 'Calculate door to door distance.  From Dock: '
                         || l_from_dock_no
                         || '  To Dock: '
                         || l_to_dock_no
                         || '  From Door: '
                         || i_from_door
                         || '  To Door: '
                         || i_to_door
                         || '';

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF; /* end audit check */
	
	/*
    ** Calculate the distance between the doors if they are different.
    ** If it is the same door then the distance will be 0.
    */

        IF ( i_from_door != i_to_door ) THEN
		/*
        **  The from and to doors are different.
        **  Check the dock the doors are on and perform the appropriate
        **  processing.
        */
            IF ( l_from_dock_no = l_to_dock_no ) THEN
			/* The doors are on the same dock. */
                BEGIN
                    SELECT
                        SUM(point_dist)
                    INTO l_door_to_door_dist
                    FROM
                        point_distance
                    WHERE
                        point_dock = l_from_dock_no
                        AND point_type = 'DD'
                        AND ( ( ( i_from_door < i_to_door )
                                AND ( point_a >= i_from_door )
                                AND ( point_b <= i_to_door ) )
                              OR ( ( i_from_door > i_to_door )
                                   AND ( point_a >= i_to_door )
                                   AND ( point_b <= i_from_door ) ) );

                    io_dist.total_distance := l_door_to_door_dist;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Unable to calculate distance from door to door on dock.',
                        sqlcode, sqlerrm);
                        l_ret_val := c_lm_pt_dist_badsetup_dtd;
                END;

            ELSE
			/*
            ** The doors are on different docks in the same area.
            */
                l_ret_val := lmd_get_d2d_dist_on_diff_dock(l_from_dock_no, l_to_dock_no, i_from_door, i_to_door, io_dist
                );
            END IF;
        ELSE
		/*
        ** The doors are the same so the distance is 0.
        */
            io_dist.total_distance := 0.0;
        END IF; /* end check doors */

        IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
            l_message := 'Door to Door Distance  From Dock: '
                         || l_from_dock_no
                         || '  To Dock: '
                         || l_to_dock_no
                         || '  From Door: '
                         || i_from_door
                         || '  To Door: '
                         || i_to_door
                         || '';

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF; /* end audit check */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_door_to_door_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_door_to_door_dist; /* end lmd_get_door_to_door_dist */
	
/****************************************************************************
**  Function:  lmd_get_point_type
**
**  Description:
**    This subroutine determines the type of the point specified.
**
**  Parameters:
**    i_point      - Point needing type.
**    o_point_type - Point type returned.
**    o_dock_num   - Dock number returned.
**
**  Return values:
**    C_SWMS_NORMAL            	-- Successfully determined the point type.
**    C_LM_PT_DIST_BADSETUP_PT 	-- Unable to determine the point type because
**                              	the point was not found in the
**                              	point_distance or bay_distance tables
**                              	or an oracle error occurred.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_point_type (
        i_point        IN             point_distance.point_a%TYPE,
        o_point_type   OUT            point_distance.point_type%TYPE,
        o_dock_num     OUT            point_distance.point_dock%TYPE
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(40) := 'lmd_get_point_type';  /* Aplog message buffer. */
        l_ret_val      NUMBER := c_swms_normal;
        l_point_type   point_distance.point_type%TYPE;
        l_aisle        bay_distance.aisle%TYPE;
        l_bay          bay_distance.bay%TYPE;
        CURSOR c_bay_cur IS
        SELECT
            'B',
            p.point_dock
        FROM
            dock             d,
            point_distance   p,
            bay_distance     b
        WHERE
            p.point_type = 'DA'
            AND p.point_b = b.aisle
            AND b.bay = l_bay
            AND b.aisle = l_aisle
            AND d.dock_no = p.point_dock
        ORDER BY
            DECODE(d.location, 'F', 1, 'S', 2, 'B', 3);

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_point_type i_point=' || i_point, sqlcode, sqlerrm);
	    /* Initialization */
        l_aisle := substr(i_point, 1, 2);
        l_bay := substr(i_point, 3, 2);
        /*
        ** Check if the point is a warehouse.
        */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Checking if point ' || i_point || ' is a warehouse.', sqlcode, sqlerrm);
        BEGIN
            SELECT
                'W',
                point_dock
            INTO
                l_point_type,
                o_dock_num
            FROM
                point_distance
            WHERE
                point_type = 'WW'
                AND point_a = i_point
                AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Point [' || i_point || '] is not a warehouse.  Checking if it is a door.', sqlcode, sqlerrm);
                BEGIN
                    SELECT
                        'D',
                        point_dock
                    INTO
                        l_point_type,
                        o_dock_num
                    FROM
                        point_distance
                    WHERE
                        point_type = 'DA'
                        AND point_a = i_point
                        AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Point [' || i_point || '] is not a door.  Checking if it is an aisle.', sqlcode, sqlerrm);
                        BEGIN
                            SELECT
                                'A',
                                point_dock
                            INTO
                                l_point_type,
                                o_dock_num
                            FROM
                                point_distance
                            WHERE
                                point_type = 'AA'
                                AND ( point_a = i_point
                                    OR point_b = i_point )
                                AND ROWNUM = 1;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'Point [' || i_point || '] is not an aisle. Checking if it is a bay.', sqlcode, sqlerrm);
                                /*
                                ** This query can return more than one row.  If there is more than
                                ** one dock for the area select the front dock first if it
                                ** exists and if not select the side dock first.  If there
                                ** is no front or side dock then the back dock is used.  The dock
                                ** is significant in that it affects the path used when calculating
                                ** the distance between two points in different areas (sections).
                                ** What is meant by sections is how the warehouse is divided when the
                                ** warehouse distances are setup up.  It can be that a warehouse area
                                ** is divided into sections in order for the distances to be calculated
                                ** correctly.  Within each section there will be at least one dock with
                                ** at least one door with the full complement of distances defined-WA,
                                ** WD, WW, AA and DD.
                                */
                                BEGIN
                                    OPEN c_bay_cur;
                                    FETCH c_bay_cur INTO
                                        l_point_type,
                                        o_dock_num;
                                    IF ( c_bay_cur%notfound ) THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Point ' || i_point || ' is not a bay.', sqlcode, sqlerrm);
                                        l_ret_val := c_lm_pt_dist_badsetup_pt;
                                    END IF; /* end check point not bay */

                                    CLOSE c_bay_cur;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ORACLE Error checking the bay_distance table for the point type.', sqlcode, sqlerrm);
                                        l_ret_val := c_lm_pt_dist_badsetup_pt;
                                END;
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR GETTING point_type. POINT TYPE=AA', sqlcode, sqlerrm);
                                l_ret_val := c_lm_pt_dist_badsetup_pt;
                        END; /* end check point not aisle */
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR GETTING point_type. POINT TYPE=DA', sqlcode, sqlerrm);
                        l_ret_val := c_lm_pt_dist_badsetup_pt;
                END; /* end check point not door */
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR GETTING point_type. POINT TYPE=WW', sqlcode, sqlerrm);
                l_ret_val := c_lm_pt_dist_badsetup_pt;
        END; /* end check point not warehouse */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Point [' || i_point || '] l_ret_val = [' || l_ret_val || ']', sqlcode, sqlerrm);
        
        IF ( l_ret_val = c_swms_normal ) THEN
            o_point_type := l_point_type;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Point ' || i_point || ' is point type ' || o_point_type || ', dock ' || o_dock_num, sqlcode, sqlerrm);
        ELSE
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Could not determine the point type after checking the point_distance and bay_distance tables.', sqlcode, sqlerrm);
            l_ret_val := c_lm_pt_dist_badsetup_pt;
        END IF; /* end update out parameters */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_point_type. l_ret_val = [' || l_ret_val || ']', sqlcode, sqlerrm);
        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN 
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Could not determine the point type after checking the point_distance and bay_distance tables.', sqlcode, sqlerrm);
            l_ret_val := c_lm_pt_dist_badsetup_pt;
            RETURN l_ret_val;
    END lmd_get_point_type; /* end lmd_get_point_type */
	
	
/****************************************************************************
**  Function:  lmd_calc_batch_dist
**
**  Description:
**    This subroutine calculates the distance traveled for the specified
**    batch.
**
**  Parameters:
**      io_b_rec           	- Pointer to record containing batch information.
**                          	This is the batch to calculate the distance for.
**      io_e_rec           	- Pointer to equipment tmu values.
**      io_dist            	- Distance between points.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_calc_batch_dist (
        io_b_rec   IN OUT     lmd_batch_rec_obj,
        i_e_rec   IN      pl_lm_goal_pb.type_lmc_equip_rec,
        io_dist    IN OUT     lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name         VARCHAR2(40) := 'lmd_calc_batch_dist';  /* Aplog message buffer. */
        l_ret_val           NUMBER := c_swms_normal;
        three_part_move_active NUMBER := c_swms_normal;
        l_message           VARCHAR2(1024);
        l_dist              lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_3_part_move_bln   BOOLEAN;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_calc_batch_dist', sqlcode, sqlerrm);
        io_dist := lmd_distance_obj(0, 0, 0, 0, 0, 0);
        --io_b_rec := lmd_batch_rec_obj('', '', '', '', '', '', '', '');
        --io_e_rec := pl_lm_goal_pb.type_lmc_equip_rec('', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '');
        BEGIN
            SELECT
                b.kvi_to_loc,
                b.kvi_from_loc,
                b.user_id,
                'N'
            INTO
                io_b_rec.dest_loc,
                io_b_rec.src_loc,
                io_b_rec.user_id,
                io_b_rec.miniload_reserve_put_back_flag
            FROM
                batch b
            WHERE
                b.batch_no = io_b_rec.batch_no;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE batch not found', sqlcode, sqlerrm);
                l_ret_val := c_no_lm_batch_found;
        END;

        IF ( l_ret_val = c_swms_normal ) THEN
		/*
        ** Right trim spaces.  Embedded spaces within the value will
        ** cause problems because anything after the space is essentially
        ** lost.
        */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'batch_no='
                                                || io_b_rec.batch_no
                                                || ' src_loc='
                                                || io_b_rec.src_loc
                                                || ', dest_loc='
                                                || io_b_rec.dest_loc
                                                || ' - Getting point to point distances', sqlcode, sqlerrm);

            lmd_add_distance(io_dist, l_dist);
            lmd_clear_distance(l_dist);
		
		/*
        ** If 3 part move is active calculate the distance from the batches
        ** "to" location to the "from" location.  See modification history in
        ** lm_goaltime.pc for more information about 3 part moves.
        ** 3 part move is for demand replenishments only.
        */
            three_part_move_active := pl_rf_lm_common.lmc_is_three_part_move_active(io_b_rec.dest_loc);
            IF ( ( ( substr(io_b_rec.batch_no, 1, 1) = c_forklift_batch_id ) AND ( substr(io_b_rec.batch_no, 2, 1) = c_forklift_demand_rpl
            ) ) AND ( three_part_move_active = 1 ) ) THEN
                l_3_part_move_bln := true;
                IF ( g_forklift_audit  ) THEN
                    pl_lm_goaltime.lmg_3_part_move_audit_message(io_b_rec.dest_loc);
                END IF;

            ELSE
                l_3_part_move_bln := false;
            END IF; /* end set l_3_part_move_bln  */

            IF ( l_3_part_move_bln ) THEN
                l_ret_val := lmd_get_pt_to_pt_dist(io_b_rec.dest_loc, io_b_rec.src_loc, i_e_rec, l_dist);
                IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                    pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, io_b_rec.src_loc, io_b_rec.dest_loc, l_dist);
                END IF; /* end audit */

                IF ( l_ret_val = c_swms_normal ) THEN
                    lmd_add_distance(io_dist, l_dist);
                    lmd_clear_distance(l_dist);
                END IF; /* end add distance */

            END IF; /* end get distance */

            IF ( l_ret_val = c_swms_normal ) THEN
                l_ret_val := lmd_get_pt_to_pt_dist(io_b_rec.src_loc, io_b_rec.dest_loc, i_e_rec, l_dist);
            END IF; /* end get pt to pt distance */

            IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, io_b_rec.src_loc, io_b_rec.dest_loc, l_dist);
            END IF; /* end audit */

            IF ( l_ret_val = c_swms_normal ) THEN
                lmd_add_distance(io_dist, l_dist);
                lmd_clear_distance(l_dist);
			
			/*
			** Calculate the put back to reserve distance if a put back was made.
			** A reserve to miniload replenishment can have the LP put back to
			** reserve when only some of the qty on the pallet is being
			** replenished.  Only look for the put back to reserve if it was
			** made before the drop to the induction location.  This is done by
			** looking at the time of the PPB transaction and the RPL transaction.
			** If the put back to reserve was after the drop to the induction
			** location then there will be a separate labor batch for the put back
			** with the labor batch number starting with FM.
			*/
                BEGIN
                    SELECT
                        b.kvi_to_loc,
                        b.kvi_from_loc,
                        b.user_id,
                        'Y'
                    INTO
                        io_b_rec.dest_loc,
                        io_b_rec.src_loc,
                        io_b_rec.user_id,
                        io_b_rec.miniload_reserve_put_back_flag
                    FROM
                        trans   t,
                        batch   b
                    WHERE
                        b.batch_no = io_b_rec.batch_no
                        AND b.kvi_to_loc IN (
                            SELECT
                                induction_loc
                            FROM
                                zone
                        )
                        AND t.trans_type = 'PPB'
                        AND t.labor_batch_no = b.batch_no
                        AND t.trans_date >= b.actl_start_time
                        AND t.trans_date =      -- In case there are multiple PPBs
                         (
                            SELECT
                                MIN(t2.trans_date)    -- for the LP
                            FROM
                                trans t2
                            WHERE
                                t2.trans_type = 'PPB'
                                AND t2.labor_batch_no = b.batch_no
                                AND t2.trans_date >= b.actl_start_time
                        )
                        AND t.trans_date <                 -- The PPB needs to be before
                         (
                            SELECT
                                t3.trans_date    -- the RPL.
                            FROM
                                trans t3
                            WHERE
                                t3.trans_type = 'RPL'
                                AND t3.labor_batch_no = b.batch_no
                        );
				
				/*
				** Found the pallet was put back to reserve before the drop to the
				** induction location.  Calculate the distance to the put back
				** location.
				**
				** Right trim spaces.  Embedded spaces within the value will
				** cause problems because anything after the space is essentially
				** lost.
				*/

                    pl_text_log.ins_msg_async('INFO', l_func_name, 'batch_no='
                                                        || io_b_rec.batch_no
                                                        || ' src_loc='
                                                        || io_b_rec.src_loc
                                                        || ', dest_loc='
                                                        || io_b_rec.dest_loc
                                                        || ' - Getting point to point distances,  LP put back to reserve', sqlcode
                                                        , sqlerrm);

                    l_ret_val := lmd_get_pt_to_pt_dist(io_b_rec.src_loc, io_b_rec.dest_loc, i_e_rec, l_dist);
                    IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                        pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, io_b_rec.src_loc, io_b_rec.dest_loc, l_dist);
                    END IF; /* end audit */

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                         pl_text_log.ins_msg_async('WARN', l_func_name, 'Found no putback transaction for the pallet which is OK.', sqlcode
                        , sqlerrm);
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed looking for a put back to reserve of the original LP', sqlcode
                        , sqlerrm);
                        l_ret_val := c_data_error;
                END;

            END IF;

        END IF; /* end batch check */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'single batch distances=('
                                            || io_dist.total_distance
                                            || ', '
                                            || io_dist.accel_distance
                                            || ', '
                                            || io_dist.decel_distance
                                            || ', '
                                            || io_dist.travel_distance
                                            || ', '
                                            || io_dist.distance_rate
                                            || ')', sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_calc_batch_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_calc_batch_dist; /* end lmd_calc_batch_dist */
	
/****************************************************************************
**  Function:  lmd_calc_parent_dist
**
**  Description:
**    This subroutine calculates the distance traveled for the specified
**    parent batch.
**    1.  Sum pick up distances first.
**    2.  Add distance from last pickup to first drop.
**    3.  Add distances from drops.
**    4.  Add distance from last drop to start of next batch.
**
**  Parameters:
**      io_b_rec         	- Pointer to record containing batch information.
**      io_e_rec         	- Pointer to equipment tmu values.
**      o_last_location  	- The last location visited.
**      io_dist          	- Distance between points.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_calc_parent_dist (
        io_b_rec          IN OUT            lmd_batch_rec_obj,
        i_e_rec          IN             pl_lm_goal_pb.type_lmc_equip_rec,
        o_last_location   OUT               batch.kvi_to_loc%TYPE,
        io_dist           IN OUT            lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name          VARCHAR2(40) := 'lmd_calc_parent_dist';  /* Aplog message buffer. */
        l_ret_val            NUMBER := c_swms_normal;
        l_message            VARCHAR2(1024);
        l_curr_drop_loc      batch.kvi_to_loc%TYPE;
        l_curr_pickup_loc    batch.kvi_to_loc%TYPE;
        l_pickup_rec_count   NUMBER := 0;
        l_drop_rec_count     NUMBER := 0;
        l_first_record_bln   BOOLEAN := true;
        l_pickup_dist        lmd_distance_obj := NEW lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_mid_travel_dist    lmd_distance_obj := NEW lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_drop_dist          lmd_distance_obj := NEW lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_distance           lmd_distance_obj := NEW lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        CURSOR c_parent_pickup_dist_cur IS
        SELECT
            b.batch_no,
            b.kvi_from_loc      loc,
            b.user_id,
            b.actl_start_time   curdate,
            'N' miniload_reserve_put_back_flag
        FROM
            batch b
        WHERE
            b.parent_batch_no = io_b_rec.parent_batch_no
            AND substr(b.batch_no, 1, 2) != 'FM'
            AND substr(b.batch_no, 1, 1) != 'T'
        UNION
               --
               -- Miniload reserve in main warehouse replenishment.
               -- Get the pallet put back location.
               --
               -- The pallet put back is designated by a PPB transaction which
               -- will have the original LP in pallet_id.  The FN batch and
               -- the corresponding RPL transaction have the "temporary LP"
               -- in the ref_no and pallet_id respectively.  To match the PPB
               -- transaction to the FN batch and to the RPL transaction we
               -- will look at the trans.labor_batch_no.  This means the PPB
               -- transaction needs to have the labor_batch_no populated with
               -- the FN batch and the RPL transaction needs to have the
               -- labor_batch_no populated with the FN batch.
        SELECT
            b.batch_no,
            t.dest_loc     loc,
            t.user_id,
            t.trans_date   curdate,
            'Y' miniload_reserve_put_back_flag
        FROM
            trans   t,
            batch   b
        WHERE
            b.parent_batch_no = io_b_rec.parent_batch_no
            AND substr(b.batch_no, 1, 2) != 'FM'
            AND substr(b.batch_no, 1, 1) != 'T'
                  --
                  -- Only look at batches where the
                  -- kvi_to_loc is an induction location.  Hopefully when
                  -- it is not an induction location the sub-queries below
                  -- on the TRANS table will not be executed so the select
                  -- will return faster.
            AND b.kvi_to_loc IN (
                SELECT
                    induction_loc
                FROM
                    zone
            )
            AND t.trans_type = 'PPB'
            AND t.labor_batch_no = b.parent_batch_no
            AND t.trans_date >= b.actl_start_time
            AND t.trans_date =        -- In case there are multiple PPB
             (
                SELECT
                    MIN(t2.trans_date)    -- for the LP
                FROM
                    trans t2
                WHERE
                    t2.trans_type = 'PPB'
                    AND t2.labor_batch_no = b.parent_batch_no
                    AND t2.trans_date >= b.actl_start_time
            )
                  --
                  -- The PPB needs to be before the RPL as this indicates
                  -- the LP pulled down then put back up before dropping
                  -- the pallet(s) at the induction location.
            AND t.trans_date < (
                SELECT
                    t3.trans_date
                FROM
                    trans t3
                WHERE
                    t3.trans_type = 'RPL'
                    AND t3.labor_batch_no = b.parent_batch_no
            )
        ORDER BY
            4;

        CURSOR c_parent_drop_dist_cur IS
        SELECT
            b.batch_no,
            b.kvi_to_loc,
            b.user_id
        FROM
            batch b
        WHERE
            b.parent_batch_no = io_b_rec.parent_batch_no
            AND substr(b.batch_no, 1, 1) != 'T'
        ORDER BY
            DECODE(substr(b.batch_no, 1, 2), 'FM', '2', '1'),
            b.kvi_to_loc;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_calc_parent_dist', sqlcode, sqlerrm);
        FOR l_pickup_rec IN c_parent_pickup_dist_cur LOOP
            l_pickup_rec_count := l_pickup_rec_count + 1;
            io_b_rec.batch_no := l_pickup_rec.batch_no;
            io_b_rec.src_loc := l_pickup_rec.loc;
            io_b_rec.user_id := l_pickup_rec.user_id;
            io_b_rec.miniload_reserve_put_back_flag := l_pickup_rec.miniload_reserve_put_back_flag;
		/* Right trim spaces. */
            io_b_rec.batch_no := rtrim(nvl(io_b_rec.batch_no, ''));
            io_b_rec.src_loc := rtrim(nvl(io_b_rec.src_loc, ''));
            io_b_rec.user_id := rtrim(nvl(io_b_rec.user_id, ''));
            l_curr_pickup_loc := rtrim(nvl(io_b_rec.src_loc, ''));
		/*
		** Calculate the distance between the pickup points.
		*/
            IF ( l_pickup_rec_count > 1 ) THEN
                lmd_clear_distance(l_distance);
			
			/*
            ** Calculate the distance from the last drop completed for a
            ** suspended batch, if one exists, to the first pickup point of
            ** the batch being completed.
            */
                IF ( l_first_record_bln ) THEN
                    l_first_record_bln := false;
                    lmd_add_distance(l_pickup_dist, l_distance);
                    lmd_clear_distance(l_distance);
                END IF;

                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling pt_to_pt in calc_parent_dist function 2222', sqlcode, sqlerrm);
                l_ret_val := lmd_get_pt_to_pt_dist(l_curr_pickup_loc, io_b_rec.src_loc, i_e_rec, l_distance);
                IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                    pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, l_curr_pickup_loc, io_b_rec.src_loc, l_distance);
                END IF; /* end audit */

                IF ( l_ret_val = c_swms_normal ) THEN
                    lmd_add_distance(l_pickup_dist, l_distance);
                END IF; /* end add distance */
                l_curr_pickup_loc := rtrim(nvl(io_b_rec.src_loc, ''));
            END IF; /* end calc distance b/w pickup points */

        END LOOP; /* end loop for c_parent_pickup_dist_cur */

        IF ( l_pickup_rec_count = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Child batches for pickup not found', sqlcode, sqlerrm);
            l_ret_val := c_no_lm_batch_found;
        END IF;
	
	 /*
    ** Now calculate the distance between the drop points.
    ** The first distance will be from the last pickup location to
    ** the first drop location then the next distances will be from drop
    ** location to drop location.
    */

        l_curr_drop_loc := l_curr_pickup_loc;
	
	/*
    ** Leave out the T batch for returns putaway.  It is not part of the
    ** distance calculation.
    ** Only process the batches where the task is not completed.
    ** These will have split_from_batch_no not null.
    */
        FOR l_drop_rec IN c_parent_drop_dist_cur LOOP
            l_drop_rec_count := l_drop_rec_count + 1;
            io_b_rec.batch_no := l_drop_rec.batch_no;
            io_b_rec.dest_loc := l_drop_rec.kvi_to_loc;
            io_b_rec.user_id := l_drop_rec.user_id;
            io_b_rec.batch_no := rtrim(nvl(l_drop_rec.batch_no, ''));
            io_b_rec.dest_loc := rtrim(nvl(l_drop_rec.kvi_to_loc, ''));
            io_b_rec.user_id := rtrim(nvl(l_drop_rec.user_id, ''));
            IF ( l_drop_rec_count = 1 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling pt_to_pt in calc_parent_dist function 3333', sqlcode, sqlerrm);
                l_ret_val := lmd_get_pt_to_pt_dist(l_curr_drop_loc, io_b_rec.dest_loc, i_e_rec, l_mid_travel_dist);
                IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                    pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, l_curr_drop_loc, io_b_rec.dest_loc, l_mid_travel_dist
                    );
                END IF; /* end audit */

                l_curr_drop_loc := io_b_rec.dest_loc;
			
			/*
			** Assign the first drop location to the last location visited to
			** handle the situation where there is a T batch with one child FP
			** batch.  This is a parent child batch relationship but the distance
			** processing will be looking at only the the single FP batch for the
			** distance.
			*/
                o_last_location := io_b_rec.dest_loc;
            ELSE
                lmd_clear_distance(l_distance);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Calling pt_to_pt in calc_parent_dist function 4444', sqlcode, sqlerrm);
                l_ret_val := lmd_get_pt_to_pt_dist(l_curr_drop_loc, io_b_rec.dest_loc, i_e_rec, l_distance);
                IF ( ( g_forklift_audit ) AND ( l_ret_val = c_swms_normal ) ) THEN
                    pl_lm_goaltime.lmg_audit_travel_distance(pl_lm_goaltime.g_audit_batch_no, l_curr_drop_loc, io_b_rec.dest_loc, l_distance);
                END IF; /* end audit */

                lmd_add_distance(l_drop_dist, l_distance);
                l_curr_drop_loc := io_b_rec.dest_loc;
                o_last_location := io_b_rec.dest_loc;
            END IF;
		
		/* Calculate the distance between the drop points. */

        END LOOP; /* end loop for c_parent_drop_dist_cur */

        IF ( l_drop_rec_count = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Child batches for drop not found', sqlcode, sqlerrm);
            l_ret_val := c_no_lm_batch_found;
        END IF;

        lmd_add_distance(io_dist, l_pickup_dist);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup travel distances=('
                                            || l_pickup_dist.total_distance
                                            || ', '
                                            || l_pickup_dist.accel_distance
                                            || ', '
                                            || l_pickup_dist.decel_distance
                                            || ', '
                                            || l_pickup_dist.travel_distance
                                            || ', '
                                            || l_pickup_dist.tia_time
                                            || ', '
                                            || l_pickup_dist.distance_rate
                                            || ')', sqlcode, sqlerrm);

        lmd_add_distance(io_dist, l_mid_travel_dist);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'mid travel distances=('
                                            || l_mid_travel_dist.total_distance
                                            || ', '
                                            || l_mid_travel_dist.accel_distance
                                            || ', '
                                            || l_mid_travel_dist.decel_distance
                                            || ', '
                                            || l_mid_travel_dist.travel_distance
                                            || ', '
                                            || l_mid_travel_dist.tia_time
                                            || ', '
                                            || l_mid_travel_dist.distance_rate
                                            || ')', sqlcode, sqlerrm);

        lmd_add_distance(io_dist, l_drop_dist);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'drop distances=('
                                            || l_drop_dist.total_distance
                                            || ', '
                                            || l_drop_dist.accel_distance
                                            || ', '
                                            || l_drop_dist.decel_distance
                                            || ', '
                                            || l_drop_dist.travel_distance
                                            || ', '
                                            || l_drop_dist.tia_time
                                            || ', '
                                            || l_drop_dist.distance_rate
                                            || ')', sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_calc_parent_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_calc_parent_dist; /* end lmd_calc_parent_dist */
	
	
/****************************************************************************
**  Function:  lmd_get_suspended_batch
**
**  Description:
**    This function determines if to use the last drop point of a suspended
**    batch for a user in the distance calculation and if so returns the
**    suspended batch in a parameter.
**
**    This function works differently from lmf_find_suspended_batch in that
**    this function is getting a suspended batch to use in a distance 
**    calculation and only if the suspended batch meets the criteria of
**    having no completed batches after it that were started before the
**    batch being completed.
**    08/11/03 prpbcb   The following test cases were handled correctly.
**       1.  Putaway.  NDM during putaway is active.
**           Three pallet putaway with a NDM performed after the 1st putaway
**           and a NDM performed after the 2nd putaway.
**       2.  Putaway.  NDM during putaway is active.
**           Two pallet putaway with 2 NDM's going to the same home slot so
**           they were merged after the putaway of the 1st pallet.  For each
**           NDM a demand HST was performed.
**
**  Parameters:
**      i_psz_batch_being_completed - The batch being completed.  It needs to
**                                    be excluded in the select statement.
**      i_psz_user_id               - The current user.
**      o_psz_suspended_batch_no    - The suspended batch if one found.
**
**  Return values:
**    SWMS_NORMAL       - Successful.  Found a suspended batch meeting the
**                        criteria.  Use the last drop point of the suspended
**                        batch.
**    NO_LM_BATCH_FOUND - Do not use the last drop point for a suspended batch
**                        or the user has no suspended batch.
**    DATA_ERROR        - Oracle error occurred.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_suspended_batch (
        i_psz_batch_being_completed   IN                            arch_batch.batch_no%TYPE,
        i_psz_user_id                 IN                            arch_batch.user_id%TYPE,
        o_psz_suspended_batch_no      OUT                           arch_batch.batch_no%TYPE
    ) RETURN NUMBER AS

        l_func_name            VARCHAR2(40) := 'lmd_get_suspended_batch';  /* Aplog message buffer. */
        l_ret_val              NUMBER := c_swms_normal;
        l_suspended_batch_no   arch_batch.batch_no%TYPE;       -- Suspended batch
	-- This cursor selects the last suspended batch for a user but
	-- only if there are no completed batches after the last suspended
	-- batch and the completed batch start time is before the start time
	-- of the batch being completed.
	-- cp_batch_being_completed is the batch being completed and
	-- is left out in the subquery because its status could have already
	-- been updated to 'C'.
        CURSOR c_suspended_batch (
            cp_user_id                 arch_batch.user_id%TYPE,
            cp_batch_being_completed   arch_batch.batch_no%TYPE
        ) IS
        SELECT
            b.batch_no
        FROM
            batch b
        WHERE
            b.status = 'W'
            AND b.user_id = cp_user_id
            AND b.actl_start_time =          -- Get the last suspended batch
             (
                SELECT
                    MAX(b2.actl_start_time)
                FROM
                    batch b2
                WHERE
                    b2.status = b.status
                    AND b2.user_id = b.user_id
            )
            AND NOT EXISTS (
                SELECT
                    'x'
                FROM
                    batch b3
                WHERE
                    b3.user_id = b.user_id
                    AND b3.status = 'C'
                    AND b3.batch_no != cp_batch_being_completed
                    AND b3.actl_start_time >= b.batch_suspend_date
                    AND b3.actl_start_time <
                             -- Only look at completed batches with a start
                             -- time before the start time of the batch being
                             -- completed.  This is to handle test case 2 as
                             -- noted in the function description.
                     (
                        SELECT
                            bc.actl_start_time
                        FROM
                            batch bc
                        WHERE
                            bc.batch_no = cp_batch_being_completed
                    )
            );

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_suspended_batch', sqlcode, sqlerrm);
        BEGIN
            OPEN c_suspended_batch(i_psz_user_id, i_psz_batch_being_completed);
            FETCH c_suspended_batch INTO l_suspended_batch_no;
            IF ( c_suspended_batch%notfound ) THEN
		  -- Did not found a suspended batch for the user which is OK.
                l_suspended_batch_no := NULL;
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, ' suspended batch ['
                                                    || l_suspended_batch_no
                                                    || '] found suspended batch for the user.', sqlcode, sqlerrm);
            END IF;

            CLOSE c_suspended_batch;
            o_psz_suspended_batch_no := l_suspended_batch_no;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'exception looking for suspended batch for the use', sqlcode, sqlerrm);           
			-- Cursor cleaup.
                IF ( c_suspended_batch%isopen ) THEN
                    CLOSE c_suspended_batch;
                END IF;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_suspended_batch', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_suspended_batch; /* end lmd_get_suspended_batch */
	
	
/****************************************************************************
**  Function:  lmd_get_pt_to_pt_dist
**
**  Description:
**    This subroutine calculates the distance between the specified points.
**
**  Parameters:
**      i_src_point  		- Starting point.
**      i_dest_point 		- Ending point.
**      io_e_rec      		- Pointer to equipment tmu values.
**      io_dist       		- Distance between points.
**
**        DATE         DESIGNER       COMMENTS
**     25/02/2020      Infosys     Initial version0.0
****************************************************************************/
    FUNCTION lmd_get_pt_to_pt_dist (
        i_src_point    IN             VARCHAR2,
        i_dest_point   IN             VARCHAR2,
        i_e_rec       IN          pl_lm_goal_pb.type_lmc_equip_rec,
        io_dist        IN OUT         lmd_distance_obj
    ) RETURN NUMBER AS

        l_func_name             VARCHAR2(40) := 'lmd_get_pt_to_pt_dist';  /* Aplog message buffer. */
        l_ret_val               NUMBER := c_swms_normal;
        l_message               VARCHAR2(1024);
        l_src_pt_type           point_distance.point_type%TYPE;
        l_src_dock_num          point_distance.point_dock%TYPE;
        l_dest_pt_type          point_distance.point_type%TYPE;
        l_dest_dock_num         point_distance.point_dock%TYPE;
        l_r_src_point           pl_lmd.t_point_info_rec;
        l_r_dest_point          pl_lmd.t_point_info_rec;
        l_src_area              VARCHAR2(5);
        l_dest_area             VARCHAR2(5);
        l_areas_are_different   BOOLEAN := false;
        l_docks_are_different   BOOLEAN := false;
        l_tia_time              NUMBER := 0.0;
        l_dist                  lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_w_dist                lmd_distance_obj := lmd_distance_obj(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        l_first_door            point_distance.point_b%TYPE;
        l_first_aisle           point_distance.point_b%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmd_get_pt_to_pt_dist - i_src_point='
                                            || i_src_point
                                            || ', i_dest_point='
                                            || i_dest_point, sqlcode, sqlerrm);

        IF ( g_forklift_audit ) THEN
            l_message := '*** Get Point to Point Distance   '
                         || i_src_point
                         || ' -> '
                         || i_dest_point
                         || ' ***';
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF; /* end audit */
	
	/*
    ** Get the point type of the source point and the dock it is on.
    */

        l_src_pt_type := ' ';
        l_src_dock_num := ' ';
        l_ret_val := lmd_get_point_type(i_src_point, l_src_pt_type, l_src_dock_num);
        IF ( l_ret_val = c_swms_normal ) THEN
		/*
        ** Get the point type of the destination point and the dock it is on.
        */
            l_dest_pt_type := ' ';
            l_dest_dock_num := ' ';
            l_ret_val := lmd_get_point_type(i_dest_point, l_dest_pt_type, l_dest_dock_num);
        END IF; /* end get point type of destination point */

        IF ( l_ret_val = c_swms_normal ) THEN
		/*
        ** If necessary, reset the travel docks the points are tied based on
        ** the setup in table DOCK_TRAVEL_PATH.  Package procedure
        ** pl_lmd.set_travel_docks() is called to set the travel docks.  If
        ** there is no change then pl_lmd.set_travel_docks will return the
        ** docks unchanged.  pl_lmd.set_travel_docks will be called only
        ** when the points are in different sections (forklift labor mgmt
        ** areas) to avoid unnecessary calls to the package procedure.
        **
        ** By default the distance calculation is expecting the travel between
        ** two sections will be from front dock to front dock but this is not
        ** necessarily the case (ie OpCo 96 Abbott).  
        **
        ** The section is the first character in the dock number.
        */
            IF ( substr(l_src_dock_num, 1, 1) != substr(l_dest_dock_num, 1, 1) ) THEN
			/*
            ** Populate the varchar variables that the PL/SQL block
            ** will reference.
            */
                l_r_src_point.pt_type := l_src_pt_type;
                l_r_src_point.dock_num := l_src_dock_num;
                l_r_src_point.point := i_src_point;
                l_r_src_point.area := substr(l_r_src_point.dock_num, 1, 1);
                l_r_dest_point.pt_type := l_dest_pt_type;
                l_r_dest_point.dock_num := l_dest_dock_num;
                l_r_dest_point.point := i_dest_point;
                l_r_dest_point.area := substr(l_r_dest_point.dock_num, 1, 1);
			
			/* Set the docks the forklift operator will travel. */
                BEGIN
                    pl_lmd.set_travel_docks(l_r_src_point, l_r_dest_point);
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'i_src_point='
                                                        || i_src_point
                                                        || ', i_dest_point='
                                                        || i_dest_point
                                                        || ', l_src_dock_num='
                                                        || l_src_dock_num
                                                        || ', l_dest_dock_num='
                                                        || l_dest_dock_num, sqlcode, sqlerrm);

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMD ORACLE Error in pl/sql block when setting the travel docks.', sqlcode
                        , sqlerrm);
                        l_ret_val := c_data_error;
                END;

            END IF; /* end checking if it is necessary to set the travel docks */
        END IF; /* end set travel docks */
        l_src_area:=substr(l_src_dock_num, 1, 1);
        l_dest_area:=substr(l_dest_dock_num, 1, 1);
        IF ( l_ret_val = c_swms_normal ) THEN
		/* The area is the first character in the dock number. */
            IF ( substr(l_src_area, 1, 1) = substr(l_dest_area, 1, 1) ) THEN
                l_areas_are_different := false;
            ELSE
                l_areas_are_different := true;
            END IF;

            IF ( l_src_dock_num = l_dest_dock_num ) THEN
                l_docks_are_different := false;
            ELSE
                l_docks_are_different := true;
            END IF;
		
		/*
        ** Give turn into aisle time when appropriate.
        */

            IF ( ( ( substr(l_src_pt_type, 1, 1) = c_pt_type_door ) AND ( substr(l_dest_pt_type, 1, 1) = c_pt_type_bay ) ) OR ( (

            substr(l_src_pt_type, 1, 1) = c_pt_type_bay ) AND ( substr(l_dest_pt_type, 1, 1) = c_pt_type_door ) ) OR ( ( substr(

            l_src_pt_type, 1, 1) = c_pt_type_aisle ) AND ( substr(l_dest_pt_type, 1, 1) = c_pt_type_bay ) ) OR ( ( substr(l_src_pt_type

            , 1, 1) = c_pt_type_bay ) AND ( substr(l_dest_pt_type, 1, 1) = c_pt_type_aisle ) ) ) THEN
                l_tia_time := l_tia_time + i_e_rec.tia;
                IF ( g_forklift_audit ) THEN
                    pl_lm_goaltime.lmg_audit_movement('TIA', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, ' ');
                END IF; /* end audit */

            ELSIF ( ( ( substr(l_src_pt_type, 1, 1) = c_pt_type_door ) AND ( substr(l_dest_pt_type, 1, 1) = c_pt_type_bay ) ) AND

            ( i_src_point != i_dest_point ) ) THEN
                l_tia_time := l_tia_time + ( i_e_rec.tia * 2 );
                IF ( g_forklift_audit ) THEN
                    pl_lm_goaltime.lmg_audit_movement('TIA', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, ' ');
                    pl_lm_goaltime.lmg_audit_movement('TIA', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, ' ');
                END IF; /* end audit */

            END IF; /* end turn into aisle */

        END IF; /* end find if same area and docks */

        IF ( ( l_ret_val = c_swms_normal ) AND ( l_areas_are_different = false ) ) THEN
		/*
        ** The source and destination points are in the same area (section).
        ** The docks may be different.
        */
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_src_pt_type='
                                                || l_src_pt_type
                                                || ', l_dest_pt_type='
                                                || l_dest_pt_type, sqlcode, sqlerrm);

            CASE ( l_src_pt_type )
                WHEN c_pt_type_door THEN
                    CASE ( l_dest_pt_type )
                        WHEN c_pt_type_door THEN	/* Door to Door */
                            l_ret_val := lmd_get_door_to_door_dist(i_src_point, i_dest_point, l_dist
                            );
                        WHEN c_pt_type_aisle THEN	/* Door to Aisle */
                         pl_text_log.ins_msg_async('INFO', l_func_name, 'calling door to aisle l_src_pt_type='
                                                || l_src_pt_type
                                                ||' c_pt_type_aisle = '||c_pt_type_aisle
                                                || ', l_dest_pt_type='
                                                || l_dest_pt_type, sqlcode, sqlerrm);
                            l_ret_val := lmd_get_door_to_aisle_dist(l_src_dock_num, i_src_point, i_dest_point, l_dist);
                        WHEN c_pt_type_bay THEN		/* Door to Bay */
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'calling door to bay l_src_pt_type='
                                                || l_src_pt_type
                                                ||' c_pt_type_bay = '||c_pt_type_bay
                                                || ', l_dest_pt_type='
                                                || l_dest_pt_type, sqlcode, sqlerrm);

                            l_ret_val := lmd_get_door_to_bay_dist(l_src_dock_num, i_src_point, i_dest_point, l_dist);
                        ELSE
                            NULL;
                    END CASE; /* end l_dest_pt_type case */
                WHEN c_pt_type_aisle THEN
                    CASE ( l_dest_pt_type )
                        WHEN c_pt_type_door THEN	/* Aisle to Door */
                            l_ret_val := lmd_get_door_to_aisle_dist(l_dest_dock_num, i_dest_point, i_src_point, l_dist);
                        WHEN c_pt_type_aisle THEN	/* Aisle to Aisle */
                            l_ret_val := lmd_get_aisle_to_aisle_dist(l_src_dock_num, i_src_point, i_dest_point, l_dist);
                        WHEN c_pt_type_bay THEN		/* Aisle to Bay */
                            
                            l_ret_val := lmd_get_aisle_to_bay_dist(l_src_dock_num, i_src_point, i_dest_point, l_dist);
                        ELSE
                            NULL;
                    END CASE; /* end l_dest_pt_type case */
                WHEN c_pt_type_bay THEN
                    CASE ( l_dest_pt_type )
                        WHEN c_pt_type_door THEN	/* Bay to Door */
                            l_ret_val := lmd_get_door_to_bay_dist(l_dest_dock_num, i_dest_point, i_src_point, l_dist);
                        WHEN c_pt_type_aisle THEN	/* Bay to Aisle */
                            l_ret_val := lmd_get_aisle_to_bay_dist(l_src_dock_num, i_dest_point, i_src_point, l_dist);
                        WHEN c_pt_type_bay THEN		/* Bay to Bay */
                            IF ( i_src_point < i_dest_point ) THEN
                                l_ret_val := lmd_get_bay_to_bay_dist(l_src_dock_num, i_src_point, i_dest_point, l_dist);
                            ELSE
                                l_ret_val := lmd_get_bay_to_bay_dist(l_src_dock_num, i_dest_point, i_src_point, l_dist);
                            END IF; /* end */
                        ELSE
                            NULL;
                    END CASE; /* end l_dest_pt_type case */
                ELSE
                    NULL;
            END CASE; /* end l_src_pt_type case */

        ELSIF ( l_ret_val = c_swms_normal ) THEN
		/*
        ** The source and destination points are in different areas 
        ** which also means they are on different docks.
        */
            l_first_door := ' ';
            l_first_aisle := ' ';
            pl_text_log.ins_msg_async('INFO', l_func_name, 'W to W:  src_dock = '
                                                || l_src_dock_num
                                                || ', src_type = '
                                                || l_src_pt_type
                                                || ', dest_dock = '
                                                || l_dest_dock_num
                                                || ', l_dest_pt_type='
                                                || l_dest_pt_type, sqlcode, sqlerrm);

            CASE ( l_src_pt_type )
                WHEN c_pt_type_door THEN
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'lmd_get_warehouse_to_door_dist 1:  l_src_dock_num = '
                                                || l_src_dock_num
                                                || ', l_dest_dock_num = '
                                                || l_dest_dock_num
                                                || ', dest_dock = '
                                                , sqlcode, sqlerrm);
                    l_ret_val := lmd_get_warehouse_to_door_dist(l_dest_dock_num, l_src_dock_num
                    , l_first_door, l_w_dist);
                    IF ( l_ret_val = c_swms_normal ) THEN
                        l_ret_val := lmd_get_door_to_door_dist( i_src_point, l_first_door, l_dist)
                        ;
                    END IF; /* end get door to door distance */

                    IF ( l_ret_val = c_swms_normal ) THEN
                        lmd_add_distance(l_dist, l_w_dist);
                        lmd_clear_distance(l_w_dist);
                        l_ret_val := lmd_get_warehouse_to_wh_dist( l_src_dock_num, l_dest_dock_num
                        , l_w_dist);
                    END IF; /* end get warehouse to warehouse distance */

                    IF ( l_ret_val = c_swms_normal ) THEN
                        lmd_add_distance(l_dist, l_w_dist);
                        lmd_clear_distance(l_w_dist);
                        CASE ( l_dest_pt_type )
                            WHEN c_pt_type_door THEN
                             pl_text_log.ins_msg_async('INFO', l_func_name, 'lmd_get_warehouse_to_door_dist 2:  l_src_dock_num = '
                                                || l_src_dock_num
                                                || ', l_dest_dock_num = '
                                                || l_dest_dock_num
                                                || ', dest_dock = '
                                                , sqlcode, sqlerrm);
                                l_ret_val := lmd_get_warehouse_to_door_dist( l_src_dock_num, l_dest_dock_num
                                , l_first_door, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_door_to_door_dist( l_first_door, i_dest_point
                                    , l_w_dist);
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end get door to door distance */

                            WHEN c_pt_type_aisle THEN
                                l_ret_val := lmd_get_wh_to_aisle_dist( l_src_dock_num, l_dest_dock_num
                                , l_first_aisle, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_aisle_to_aisle_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist
                                    );
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end get aisle to aisle distance */

                            WHEN c_pt_type_bay THEN
                                l_ret_val := lmd_get_wh_to_aisle_dist(l_src_dock_num, l_dest_dock_num
                                , l_first_aisle, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_aisle_to_bay_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist
                                    );
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end aisle to bay distance */

                            ELSE
                                NULL;
                        END CASE; /* end l_dest_pt_type case */

                    END IF; /* end process by destination point type */

                WHEN c_pt_type_aisle THEN
                    l_ret_val := lmd_get_wh_to_aisle_dist( l_dest_dock_num, l_src_dock_num
                    , l_first_aisle, l_w_dist);
                    IF ( l_ret_val = c_swms_normal ) THEN
                        l_ret_val := lmd_get_aisle_to_aisle_dist(l_src_dock_num, i_src_point, l_first_aisle, l_dist);
                        IF ( l_ret_val = c_swms_normal ) THEN
                            lmd_add_distance(l_dist, l_w_dist);
                            lmd_clear_distance(l_w_dist);
                        END IF; /* end add distance */

                    END IF; /* end get aisle to aisle distance */

                    IF ( l_ret_val = c_swms_normal ) THEN
                        l_ret_val := lmd_get_warehouse_to_wh_dist( l_src_dock_num, l_dest_dock_num
                        , l_w_dist);
                        IF ( l_ret_val = c_swms_normal ) THEN
                            lmd_add_distance(l_dist, l_w_dist);
                            lmd_clear_distance(l_w_dist);
                        END IF; /* end add distance */

                    END IF; /* end get warehouse to warehouse distance */

                    IF ( l_ret_val = c_swms_normal ) THEN
                        CASE ( l_dest_pt_type )
                            WHEN c_pt_type_door THEN
                             pl_text_log.ins_msg_async('INFO', l_func_name, 'lmd_get_warehouse_to_door_dist 3:  l_src_dock_num = '
                                                || l_src_dock_num
                                                || ', l_dest_dock_num = '
                                                || l_dest_dock_num
                                                || ', dest_dock = '
                                                , sqlcode, sqlerrm);
                                l_ret_val := lmd_get_warehouse_to_door_dist( l_src_dock_num, l_dest_dock_num
                                , l_first_door, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_door_to_door_dist(l_dest_dock_num, l_first_door
                                    , l_w_dist);
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end get door to door distance */

                            WHEN c_pt_type_aisle THEN
                                l_ret_val := lmd_get_wh_to_aisle_dist(l_src_dock_num, l_dest_dock_num
                                , l_first_aisle, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_aisle_to_aisle_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist
                                    );
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end get aisle to aisle distance */

                            WHEN c_pt_type_bay THEN
                                l_ret_val := lmd_get_wh_to_aisle_dist( l_src_dock_num, l_dest_dock_num
                                , l_first_aisle, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                    lmd_clear_distance(l_w_dist);
                                    l_ret_val := lmd_get_aisle_to_bay_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist
                                    );
                                    IF ( l_ret_val = c_swms_normal ) THEN
                                        lmd_add_distance(l_dist, l_w_dist);
                                    END IF; /* end add distance */
                                END IF; /* end get aisle to bay distance */

                            ELSE
                                NULL;
                        END CASE; /* end l_dest_pt_type case */
                    END IF; /* end process by destination point type */

                WHEN c_pt_type_bay THEN
                    l_ret_val := lmd_get_wh_to_aisle_dist( l_dest_dock_num, l_src_dock_num
                    , l_first_aisle, l_w_dist);
                    IF ( l_ret_val = c_swms_normal ) THEN
                        l_ret_val := lmd_get_aisle_to_bay_dist(l_src_dock_num, l_first_aisle, i_src_point, l_dist);
                        IF ( l_ret_val = c_swms_normal ) THEN
                            lmd_add_distance(l_dist, l_w_dist);
                            lmd_clear_distance(l_w_dist);
                            l_ret_val := lmd_get_warehouse_to_wh_dist( l_src_dock_num, l_dest_dock_num
                            , l_w_dist);
                            IF ( l_ret_val = c_swms_normal ) THEN
                                lmd_add_distance(l_dist, l_w_dist);
                                lmd_clear_distance(l_w_dist);
                            END IF; /* end add distance */

                        END IF; /* end get warehouse to warehouse distance */

                    END IF; /* end get aisle to bay distance */

                    CASE ( l_dest_pt_type )
                        WHEN c_pt_type_door THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'lmd_get_warehouse_to_door_dist 4:  l_src_dock_num = '
                                                || l_src_dock_num
                                                || ', l_dest_dock_num = '
                                                || l_dest_dock_num
                                                || ', dest_dock = '
                                                , sqlcode, sqlerrm);
                            l_ret_val := lmd_get_warehouse_to_door_dist( l_src_dock_num, l_dest_dock_num
                            , l_first_door, l_w_dist);
                            IF ( l_ret_val = c_swms_normal ) THEN
                                lmd_add_distance(l_dist, l_w_dist);
                                lmd_clear_distance(l_w_dist);
                                l_ret_val := lmd_get_door_to_door_dist(l_first_door, i_dest_point
                                , l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                END IF; /* end add distance */
                            END IF; /* end get door to door distance */

                        WHEN c_pt_type_aisle THEN
                            l_ret_val := lmd_get_wh_to_aisle_dist( l_src_dock_num, l_dest_dock_num
                            , l_first_aisle, l_w_dist);
                            IF ( l_ret_val = c_swms_normal ) THEN
                                lmd_add_distance(l_dist, l_w_dist);
                                lmd_clear_distance(l_w_dist);
                                l_ret_val := lmd_get_aisle_to_aisle_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                END IF; /* end add distance */
                            END IF; /* end get aisle to aisle distance */

                        WHEN c_pt_type_bay THEN
                            l_ret_val := lmd_get_wh_to_aisle_dist( l_src_dock_num, l_dest_dock_num
                            , l_first_aisle, l_w_dist);
                            IF ( l_ret_val = c_swms_normal ) THEN
                                lmd_add_distance(l_dist, l_w_dist);
                                lmd_clear_distance(l_w_dist);
                                l_ret_val := lmd_get_aisle_to_bay_dist(l_dest_dock_num, l_first_aisle, i_dest_point, l_w_dist);
                                IF ( l_ret_val = c_swms_normal ) THEN
                                    lmd_add_distance(l_dist, l_w_dist);
                                END IF; /* end add distance */
                            END IF; /* end get aisle to bay distance */

                        ELSE
                            NULL;
                    END CASE; /* end l_dest_pt_type case */

                ELSE
                    NULL;
            END CASE; /* end l_src_pt_type case */

        END IF; /* end process per type */
	
	/*
    ** Determine the accelerate and decelerate distance.
    */

        lmd_segment_distance(l_dist);  

    /*
    ** The TIA time was calculated in this function.
    */
        l_dist.tia_time := l_tia_time;
        lmd_add_distance(io_dist, l_dist);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pt to pt distances=('
                                            || l_dist.total_distance
                                            || ', '
                                            || l_dist.accel_distance
                                            || ', '
                                            || l_dist.decel_distance
                                            || ', '
                                            || l_dist.travel_distance
                                            || ', '
                                            || l_dist.tia_time
                                            || ', '
                                            || l_dist.distance_rate
                                            || ')', sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmd_get_pt_to_pt_dist', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmd_get_pt_to_pt_dist; /* end lmd_get_pt_to_pt_dist */		
END PL_LM_DISTANCE;
/

GRANT EXECUTE ON PL_LM_DISTANCE TO swms_user;