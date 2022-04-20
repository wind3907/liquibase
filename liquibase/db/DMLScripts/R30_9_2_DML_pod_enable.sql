/****************************************************************************
** File:       FOOD_SAFETY_DCI_DML.sql
**
** Desc: Script to enable POD
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    28-Jul-2020 Vishnupriya K.     setup POD enable script  
**    
****************************************************************************/
update sys_config
set config_flag_val = 'Y'
WHERE APPLICATION_FUNC = 'DRIVER CHECK IN'
AND CONFIG_FLAG_NAME   = 'POD_ENABLE'; 

commit;