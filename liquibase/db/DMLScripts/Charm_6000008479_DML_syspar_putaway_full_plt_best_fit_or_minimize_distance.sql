
/****************************************************************************
** Date:       04-DEC-2015
** Programmer: Brian Bent
** File:       Charm_6000008479_DML_syspar_putaway_full_plt_best_fit_or_minimize_distance.sql
** Defect#:    xxx
** Ticket:     xxx
** Project:
** R30.4--WIB#587--Charm6000008479_Open_PO_for_full_pallet_provide_ability_to_find_slot_by_best_fit_or_closest_to_case_home_slot
** 
** This script performs the DML for this project which consists of adding
** three syspars.
**
** This script needs to be run once when the changes are installed at
** the OpCo.  Inadvertently running this script again will not cause any
** problems.
**
** Records are inserted into tables:
**    - SYS_CONFIG
**    - SYS_CONFIG_VALID_VALUES
**
** Syspars Added: (did not want to abbreviate pallet to plt but column
**                 not large enough)
**    - full_plt_minimize_option_clr  Value will be S.
**    - full_plt_minimize_option_frz  Value will be S.
**    - full_plt_minimize_option_dry  Value will be S.
**
**
** Description of the Syspars
**    - full_plt_minimize_option_clr
**
**         This syspar designates if to minimize the travel distance from
**         the home slot or find the best fit by size (the way it always
**         worked) when finding a suitable reserve slot for a full
**         pallet for a COOLER item with a home slot.  The valid values are
**         'D' for distance and 'S' for size.
**         The order by clauses for the cursors in
**         pl_rcv_open_po_cursors.sql look at this.
**
**
**    - full_plt_minimize_option_frz
**
**         This syspar designates if to minimize the travel distance from
**         the home slot or find the best fit by size (the way it always
**         worked) when finding a suitable reserve slot for a full
**         pallet for a FREEZER item with a home slot.  The valid values are
**         'D' for distance and 'S' for size.
**         The order by clauses for the cursors in
**         pl_rcv_open_po_cursors.sql look at this.
**
**
**    - full_plt_minimize_option_dry
**
**         This syspar designates if to minimize the travel distance from
**         the home slot or find the best fit by size (the way it always
**         worked) when finding a suitable reserve slot for a full
**         pallet for a DRY item with a home slot.  The valid values are
**         'D' for distance and 'S' for size.
**         The order by clauses for the cursors in
**         pl_rcv_open_po_cursors.sql look at this.
**
**
** NOTE: Partial pallets have existing syspar PARTIAL_MINIMIZE_OPTION.
**       The difference is there is only one syspar for all areas
**       where as for full pallets their is a syspar for each area.
**
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    12/04/15 prpbcb   Created.
**
****************************************************************************/



/********************************************************************
**    Insert the syspars
********************************************************************/

COL maxseq_no NOPRINT NEW_VALUE maxseq;


/********************************************************************
**    Create sypar full_plt_minimize_option_clr
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

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
   &maxseq + 1 seq_no,
   'PUTAWAY'                           application_func, 
   'FULL_PLT_MINIMIZE_OPTION_CLR'      config_flag_name,
   'Full Plt Best Fit/Min Dist Clr'    config_flag_desc,
   'S'                                 config_flag_val,
   'Y'                                 value_required,
   'Y'                                 value_updateable,
   'N'                                 value_is_boolean,
   'CHAR'                              data_type,
   1                                   data_precision,
   0                                   data_scale,
   'L'                                 sys_config_list,
   'LIST'                              validation_type,
   NULL                                range_low,
   NULL                                range_high,
'COOLER Area Full Pallet - Find Best Fit By Size or Minimize Distance From Home Slot
------------------------------------------------------------------------
This syspar designates that when finding a slot for a full pallet
for COOLER items with a home slot to find the best fit by size (cube or
inches--whichever is active) or find the slot closest to the rank 1
case home slot.'
|| chr(10) || chr(10) ||
'The valid values for this syspar are:
Value  Effect
-----  --------------------------------------------------------------
  S    Find best fit by size.
  D    Find slot closest to the home slot.' sys_config_help
 FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_CLR' config_flag_name,
   'S'                            config_flag_val,
   'Find best fit by size'        description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_CLR'     config_flag_name,
   'D'                                config_flag_val,
   'Minimize distance from home slot' description
FROM DUAL
/




COL maxseq_no NOPRINT NEW_VALUE maxseq;


/********************************************************************
**    Create sypar full_plt_minimize_option_frz
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

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
   &maxseq + 1 seq_no,
   'PUTAWAY'                           application_func, 
   'FULL_PLT_MINIMIZE_OPTION_FRZ'      config_flag_name,
   'Full Plt Best Fit/Min Dist Frz'    config_flag_desc,
   'S'                                 config_flag_val,
   'Y'                                 value_required,
   'Y'                                 value_updateable,
   'N'                                 value_is_boolean,
   'CHAR'                              data_type,
   1                                   data_precision,
   0                                   data_scale,
   'L'                                 sys_config_list,
   'LIST'                              validation_type,
   NULL                                range_low,
   NULL                                range_high,
'COOLER Area Full Pallet - Find Best Fit By Size or Minimize Distance From Home Slot
------------------------------------------------------------------------
This syspar designates that when finding a slot for a full pallet
for COOLER items with a home slot to find the best fit by size (cube or
inches--whichever is active) or find the slot closest to the rank 1
case home slot.'
|| chr(10) || chr(10) ||
'The valid values for this syspar are:
Value  Effect
-----  --------------------------------------------------------------
  S    Find best fit by size.
  D    Find slot closest to the home slot.' sys_config_help
 FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_FRZ' config_flag_name,
   'S'                            config_flag_val,
   'Find best fit by size'        description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_FRZ'     config_flag_name,
   'D'                                config_flag_val,
   'Minimize distance from home slot' description
FROM DUAL
/



COL maxseq_no NOPRINT NEW_VALUE maxseq;


/********************************************************************
**    Create sypar full_plt_minimize_option_dry
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

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
   &maxseq + 1 seq_no,
   'PUTAWAY'                           application_func, 
   'FULL_PLT_MINIMIZE_OPTION_DRY'      config_flag_name,
   'Full Plt Best Fit/Min Dist Dry'    config_flag_desc,
   'S'                                 config_flag_val,
   'Y'                                 value_required,
   'Y'                                 value_updateable,
   'N'                                 value_is_boolean,
   'CHAR'                              data_type,
   1                                   data_precision,
   0                                   data_scale,
   'L'                                 sys_config_list,
   'LIST'                              validation_type,
   NULL                                range_low,
   NULL                                range_high,
'DRY Area Full Pallet - Find Best Fit By Size or Minimize Distance From Home Slot
------------------------------------------------------------------------
This syspar designates that when finding a slot for a full pallet
for DRY items with a home slot to find the best fit by size (cube or
inches--whichever is active) or find the slot closest to the rank 1
case home slot.'
|| chr(10) || chr(10) ||
'The valid values for this syspar are:
Value  Effect
-----  --------------------------------------------------------------
  S    Find best fit by size.
  D    Find slot closest to the home slot.' sys_config_help
 FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_DRY' config_flag_name,
   'S'                            config_flag_val,
   'Find best fit by size'        description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'FULL_PLT_MINIMIZE_OPTION_DRY'     config_flag_name,
   'D'                                config_flag_val,
   'Minimize distance from home slot' description
FROM DUAL
/

