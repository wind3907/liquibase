/****************************************************************************
** Date:       24-May-2018
** File:       Jira466_update_mgs_hdgs_paovrv.sql
**
** Script to update some messages and headings in the translation table for paovrv 
**
** 
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    24-May-2018 Vishnupriya K.    
**
****************************************************************************/

BEGIN

update message_table
set v_message = 'out qty(s) should be blank or between 1 and qty allocated.'
where ID_MESSAGE = '5528'
and ID_LANGUAGE = '3';


UPDATE  ml_values
SET TEXT = 'WH
Out
Qty'
WHERE FK_ML_MODULES in ('10135','10010')
and ID_FUNCTIONALITY =15
and ID_LANGUAGE = '3';

UPDATE  ml_values
SET TEXT = 'Enter a WH Out Quantity'
WHERE FK_ML_MODULES='10010'
and ID_FUNCTIONALITY =7
and ID_LANGUAGE = '3';

UPDATE  ml_values
SET TEXT = 'WH Out Quantity'
WHERE FK_ML_MODULES in ('10135')
and ID_FUNCTIONALITY =7
and ID_LANGUAGE = '3';

Commit;

exception when others then
 null;
End;							  
/ 