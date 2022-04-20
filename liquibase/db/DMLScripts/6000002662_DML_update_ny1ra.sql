/****************************************************************************
** Date:       19-May-2016
** File:       6000002662_DML_update_ny1ra.sql
**
**             Script to 
**             1. Modification global_report_dict configuation
**
**    - SCRIPTS
**
**    Modification History:
**    Date        Designer Comments
**    --------    -------- --------------------------------------------------- 
**    19-May-2016 skam7488 Charm#6000002662
**                         Project: SWMS Cycle Count Report
**
****************************************************************************/

update SWMS.global_report_dict set fld_lbl_desc='Pk/Sz/Unit' 
where report_name = 'ny1ra' and fld_lbl_name='6' and lang_id=3;

update SWMS.global_report_dict set fld_lbl_desc='Pk  z  nité'
where report_name = 'ny1ra' and fld_lbl_name='6' and lang_id=12;

COMMIT;
