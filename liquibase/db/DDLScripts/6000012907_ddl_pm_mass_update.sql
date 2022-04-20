/****************************************************************************
** Date:       28-Jun-2016
** File:       6000012907_ddl_pm_mass_update.sql
**
**             script for creating default directory pm_mass_update_data_dir 
**             to create external table from .CSV file
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    28-MAY-16 skam7488 Charm#6000012907:New Script to update hazardous codes
**                   	 for items based on excel sheet data.
**
****************************************************************************/
CREATE OR REPLACE DIRECTORY 
PM_MASS_UPDATE_DATA_DIR AS 
'/tmp';

GRANT READ, WRITE ON DIRECTORY PM_MASS_UPDATE_DATA_DIR TO PUBLIC;

GRANT EXECUTE, READ, WRITE ON DIRECTORY PM_MASS_UPDATE_DATA_DIR TO SWMS_USER;
/
