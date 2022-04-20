/****************************************************************************
** Date:       24-May-2020
** File:       R30_7jira2007_rtnsdtl_DML.sql
**
** Script to update some messages and headings in the
** translation table for RTNSDTL for and menu
**
** Modification History:
** Date        Designer           Comments
** -------- -------- ---------------------------------------------------
**    24-May-2020 Vishnupriya K.    
**
****************************************************************************/

Begin

update ml_values
set TEXT = 'Disp'
where FK_ML_MODULES ='12334'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'UOM'
where FK_ML_MODULES ='12299'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'Status'
where FK_ML_MODULES ='12300'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'Shp Qty'
where FK_ML_MODULES ='12298'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'CPV'
where FK_ML_MODULES ='12297'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'TY'
where FK_ML_MODULES ='12294'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'POD'
where FK_ML_MODULES ='102205'
and id_functionality =15
and ID_LANGUAGE = 3;

update ml_values
set TEXT = 'Stop #'
where FK_ML_MODULES ='12291'
and id_functionality =15
and ID_LANGUAGE = 3;

--change the menu name
update ml_values
set TEXT = 'Validate-returns'
where FK_ML_MODULES ='16047';

--change the menu name
update ml_values
set TEXT = 'Data-collect'
where FK_ML_MODULES ='16046'
and id_language =3;

--change menu name for 
update ml_values
set TEXT = 'process-Returns'
where FK_ML_MODULES ='16045'
and id_language =3;


update ml_values
set TEXT = replace(TEXT, 'Missing', 'Mispick')
where FK_ML_MODULES in (12392, 12393)
and id_functionality =15
and ID_LANGUAGE = 3;


update MESSAGE_TABle
set V_MESSAGE = replace (V_MESSAGE, 'Trip master', 'Validate-returns')
where ID_MESSAGE in (6410, 6415, 6435);

update MESSAGE_TABle
set V_MESSAGE = replace (V_MESSAGE, 'over', 'complete')
where ID_MESSAGE in ( 6435);

update MESSAGE_TABle 
set v_message ='Returns Ready For Validation'
where ID_MESSAGE in (11537)
and id_language ='3';

update MESSAGE_TABle
set V_MESSAGE = replace (V_MESSAGE, 'Tripmaster', 'Validate-returns')
where ID_MESSAGE in (6579)
and id_language ='3';


update MESSAGE_TABle 
set v_message ='No putaway tasks exist. Ensure manifest is processed or if returns exist. Return batches will not be created.'
where ID_MESSAGE in (6390)
and id_language ='3';

update MESSAGE_TABle 
set v_message ='The validate-returns process failed. Until errors are resolved, return validation is incomplete'
where ID_MESSAGE in (6432)
and id_language ='3';

commit;

exception when others then
 null;
End;							  
/ 


