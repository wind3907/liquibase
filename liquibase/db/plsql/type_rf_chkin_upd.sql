/****************************************************************************
** Date:       21-NOV-2019
** File:       type_rf_chkin_upd.sql
**
**             Script for creating objects for chkin_upd
**             client
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    21/11/19   chyd9155  type_rf_chkin_upd.sql
**                  

****************************************************************************/

/********    client Object  ************/

create or replace TYPE  upd_chkin_client_obj FORCE AS OBJECT(
	pallet_id			VARCHAR2(18),
	qty					VARCHAR2(7),
	lot_id				VARCHAR2(30),
	exp_date			VARCHAR2(6),
	mfg_date			VARCHAR2(6),
	temp				VARCHAR2(6),
	clam_bed_num		VARCHAR2(10),
	harvest_date		VARCHAR2(6),
	tti_value			VARCHAR2(1),
	cryovac_value		VARCHAR2(1),
	cooler_temp			VARCHAR2(6),
	freezer_temp		VARCHAR2(6),
	reason_code			VARCHAR2(3)
    );	   

/	

grant execute on upd_chkin_client_obj  to swms_user;
/
