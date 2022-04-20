/****************************************************************************
**
** Description:
**    Project:
**       R50_0_DML_OPCOF-3872_BUG_Miniload_items_asterisk_when_directed_to_main_whse_reserve
**       Bug fix.
**
**       Miniload items "*" when directed to main warehouse reserve locations.
**
**       This started happening after we took out the extended case cube "magic" cube check because of an issue at the BRAKES OpCo.
**       The putaway logic would turn off extended case cube (if configured to use extended case cube)
**       if the items "home" location cube was >= 900 (the magic cube).
**       For purposes of the putaway logic the home location is:
**          - Items home slot for home slot itims.
**          - Items last ship slot for a floating item
**          - Miniloader induction location for a miniloader item.
**
**       The BRAKES OpCo is using extended case cube and uses cubic centimeters.  The magic cube was hardcoded
**       to 900 which is fine for cubic feet but 900 is small for cubic centimeters as most locations have a cube
**       much more than 900 so for the BRAKES OpCo the extended case cube almost always got turned off.
**
**       When directing a miniloader item pallet to main warehouse reserve the pallet would "*" because the induction
**       location is used to determine the extended case cube.  The cube of the induction location is usually very
**       large so the extended case cube is calculated to a large value thus the cube of the incoming pallet turns
**       out to be too big for any slot.
**
**       This magic cube check to turn off extended case cube will be re-implemented and will use the value of syspar
**       EXTENDED_CASE_CUBE_CUTOFF_CUBE and not hardcode 900.
**       For OpCos using cubic feet the initial value of the syspar will be set to 900.
**       For OpCos using cubic centimeters the initial value of the syspar will be set to 25484400 (900 * 28316).
**
**    Syspar added
**    - EXTENDED_CASE_CUBE_CUTOFF_CUBE
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    01/10/22 bben0556 Brian Bent
**                      Card: R50_0_DML_OPCOF-3872_BUG_Miniload_items_asterisk_when_directed_to_main_whse_reserve
**
**                      Created.
****************************************************************************/

/********************************************************************
**    Insert the syspars
********************************************************************/

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar PARTIAL_NONDEEPSLOT_SEARCH_CLR
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

--
-- Initial value depends if the OpCo is using cubic feet or cubic centimeters.
-- The syspar is not updateable by the user.
--
INSERT INTO sys_config
   (seq_no,
    application_func,
    config_flag_name, 
    config_flag_desc,
    config_flag_val,
    value_required,
    value_updateable,
    value_is_boolean,
    data_type,
    data_precision,
    data_scale,
    sys_config_list,
    validation_type,
    range_low,
    range_high,
    sys_config_help)
SELECT
   (SELECT MAX(seq_no) maxseq_no FROM sys_config) + 1,
   'PUTAWAY'                           application_func, 
   'EXTENDED_CASE_CUBE_CUTOFF_CUBE'    config_flag_name,
   'Extended Case Cube Cutoff'         config_flag_desc,
   --
   CASE (SELECT config_flag_val FROM sys_config WHERE config_flag_name = 'LENGTH_UNIT')
      WHEN 'CM' THEN '25484400'
      ELSE '900'
   END                                 config_flag_val,
   --
   'Y'                                 value_required,
   'N'                                 value_updateable,
   'N'                                 value_is_boolean,
   'NUMBER'                            data_type,
   10                                  data_precision,
   NULL                                data_scale,
   'R'                                 sys_config_list,
   'RANGE'                             validation_type,
   1                                   range_low,
   99999999                            range_high,
'This syspar allows extended case to be turned off for an item/pallet type.
The putaway logic would will not use extended case cube (if configured) if the items "home" location
cube is >= the value of this syspar.
For purposes of the putaway logic the home location is:
   - Items home slot for home slot itms.
   - Items last ship slot for a floating item
   - Miniloader induction location for a miniloader item.'
|| CHR(10) || CHR(10) ||
'An example of the use of the syspar is for a miniloader item (extended case cube is turned on for the pallet type
of the induction location).
When directing a miniloader item pallet to main warehouse reserve the extended case cube is calculated
using the induction location cube.  The cube of the induction location is usually very large so the
extended case cube is calculated to a large value thus the cube of the incoming pallet turns out to be
too big for any slot.  By setting this syspar to a value less than the induction location cube extended
case cube will be turned off and the item''s actual cube is used in calculating the cube of the incoming pallet.'
|| CHR(10) || CHR(10) ||
'NOTE: Applies only when the Putaway Dimension syspar is "C" and extended case cube is turned.
Turning on/off extended case cube is at the pallet type level and set in screen "Pallet Types".' sys_config_help
  FROM DUAL
 WHERE NOT EXISTS
   (SELECT 'x' FROM sys_config WHERE config_flag_name = 'EXTENDED_CASE_CUBE_CUTOFF_CUBE')
/


