/****************************************************************************
** Date:       28-OCT-2015
** File:       Charm-6000008851_DDL_MODIFY_HACCP_CODES.sql
**
**             Script to MODITY table HACCP_CODES
**             Add column report_type VARCHAR2(50).
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    28-OCT-2015 AKLU6632  Init
**
****************************************************************************/

ALTER TABLE haccp_codes ADD report_type VARCHAR2(50);