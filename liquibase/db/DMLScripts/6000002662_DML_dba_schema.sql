/****************************************************************************
** Date:       30-Oct-2015
** File:       Charm-6000002662_DML_dba_schema.sql
**
**             Script to 
**             1. Modification global_report_dict configuation
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    30-Oct-2015 Chua6448 Charm#6000002662
**                       Project: SWMS Cycle Count Report
**
****************************************************************************/

update SWMS.global_report_dict set fld_lbl_desc='Pack/Size/Unit' 
where report_name = 'ny1ra' and fld_lbl_name='6' and lang_id=3 and fld_lbl_desc='Pack/Size';

update SWMS.global_report_dict set fld_lbl_desc='Taille/Packet/Unites' 
where report_name = 'ny1ra' and fld_lbl_name='6' and lang_id=12 and fld_lbl_desc='Taille/Packet';

COMMIT;