
-- September 2014
-- Main Symbotic DML script.
--
-- Thu Sep 18 12:29:28 CDT 2014  Brian Bent
-- Remove old syspar MX_STAGING_OR_INDUCTION.
-- This syspar is now at the area level.
-- Added syspars:
--    - MX_MSKU_STAGING_OR_INDUCT_DRY
--    - MX_MSKU_STAGING_OR_INDUCT_CLR
--    - MX_MSKU_STAGING_OR_INDUCT_FRZ
-- The above are the same as the following but for MSKU pallets.
--    - MX_STAGING_OR_INDUCTION_DRY
--    - MX_STAGING_OR_INDUCTION_CLR
--    - MX_STAGING_OR_INDUCTION_FRZ
--
-- Changed the lov_query for the "staging or induct" syspars to select only
-- the locations in the area designated for the syspar.
--

spool /tmp/DML_Insert_Matrix_Location.lis


--MX_REPLEN_TYPE TABLE
INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('NXL', 'Non-demand: Reserve to Matrix', 'N', 'N', 'LOW');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('NSP', 'Non-demand: Matrix to Split Home', 'N', 'Y', 'ABS');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('DSP', 'Demand: Matrix to Split Home', 'N', 'Y', 'HIGH');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('DXL', 'Demand: Reserve to Matrix', 'N', 'N', 'LOW');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('UNA', 'Unassign Item: Matrix to Main Warehouse', 'Y', 'Y', 'ABS');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('MXL', 'Assign Item: Home Location to Matrix', 'Y', 'N', 'LOW');

INSERT INTO mx_replen_type ( type, descrip, print_lpn, show_travel_key, mx_exact_pallet_imp) VALUES ('MRL', 'Manual Release: Matrix to Reserve', 'Y', 'Y', 'LOW');


-- SYS_CONFIG TABLE

INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_DEFAULT_SPUR_LOCATION', 'Matrix default Spur location', 'SP9999', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default spur location of Matrix', NULL,
                       NULL, NULL, NULL, NULL);
                       
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_MAX_BATCH_CASE_CUBE', 'Max case cube for Matrix batch', '45', 'Y',
                       'Y', 'N', 'NUMBER', 7, 4, 'L',
                       'Maximum case cube for a Matrix batch', NULL,
                       NULL, NULL, NULL, NULL);

INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,
                        LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_STAGING_OR_INDUCTION_DRY', 'Matrix Induction Location Dry', 'LX1111', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default induction location for Matrix dry items.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''D'' order by 1',
                       'LIST', NULL, NULL, NULL);


INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,
                        LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_STAGING_OR_INDUCTION_CLR', 'Matrix Induction Location Clr', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default induction location for Matrix cooler items.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''C'' order by 1',
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,
                        LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_STAGING_OR_INDUCTION_FRZ', 'Matrix Induction Location Fzr', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default induction location for Matrix freezer items.', 
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''C'' order by 1',
                       'LIST', NULL, NULL, NULL);

--
-- SYS_CONFIG MSKU syspars
--
INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_MSKU_STAGING_OR_INDUCT_DRY', 'Matrix MSKU Induction Locn Dry', 'LX1111', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default MSKU induction location for Matrix dry items.  When a SN is opened the MSKU child LP''s for matrix dry items are directed to this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''D'' order by 1',
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_MSKU_STAGING_OR_INDUCT_CLR', 'Matrix MSKU Induction Locn Clr', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default MSKU induction location for Matrix cooler items.  When a SN is opened the MSKU child LP''s for matrix cooler items are directed to this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''C'' order by 1',
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_MSKU_STAGING_OR_INDUCT_FRZ', 'Matrix MSKU Induction Locn Fzr', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default MSKU induction location for Matrix freezer items.  When a SN is opened the MSKU child LP''s for matrix freezer items are directed to this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXI'', ''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''F'' order by 1',
                       'LIST', NULL, NULL, NULL);

--
-- SYS_CONFIG Interface Maintanance
--

INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'INTERFACE', 'MX_INTERFACE_ACTIVE', 'To Turn On/Off All Interfaces', 'Y', 'Y',
                       'N', 'Y', 'CHAR', 1, NULL, 'L',
                       'Interface switch on Y/N', NULL,
                       NULL, NULL, NULL, NULL);

-- matrix_task_priority  table

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('UNA','NORMAL',70,'Normal UnAssigned replenishments from Matrix to Main WH');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('UNA','HIGH',75,'High level UnAssigned replenishments from Matrix to Main WH');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('UNA','URGENT',80,'Urgent level UnAssigned replenishments from Matrix to Main WH');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('MXL','CRITICAL',5,'Selection batch for this item is active or complete. The user has shorted this item.');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NXL','CRITICAL',7,'A selector has shorted this item. Non Demand replenishment is forced from the short screen');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NSP','CRITICAL',10,'At least one of the selection batches completed for this truck has a stop number lower than the stop number for this Matrix non-demand replenishment');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DXL','URGENT',15,'Selection batch for this item is active or complete. The user has not picked this item yet or fully picked this item. So, another user may get a short soon.');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NSP','URGENT',20,'At least one of the selection batches for this truck is in complete status');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DXL','HIGH',25,'Selection batch for this item is not active yet. There is a miniload replenishment depending on this');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DXL','MEDIUM',35,'Selection batch for this item is not active yet. There is a split home replenishment depending on this');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DXL','NORMAL',45,'All other demand replenishments');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NSP','NORMAL',50,'All other Matrix non-demand replenishment tasks');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NXL','URGENT',55,'Non Demand replenishment for an actual order for the day');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NXL','HIGH',60,'Non Demand replenishment for anticipated orders for the day');

insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('NXL','NORMAL',75,'User created Non Demand replenishments (Using Min/Max, Location cube etc.)');

Insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DSP','CRITICAL',5,'At least one of the selection batches completed for this truck has a stop number lower than the stop number for this Matrix demand replenishment');

Insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DSP','NORMAL',5 ,'All other Matrix demand replenishment tasks');

Insert into matrix_task_priority (MATRIX_TASK_TYPE,SEVERITY,PRIORITY,REMARKS) values ('DSP','URGENT',5,'At least one of the selection batches for this truck is in complete status');

-- Trans_type table

insert into trans_type(trans_type, descrip, retention_days, inv_affecting) values('MXE', 'Matrix Exception', 55,'N');
          
insert into trans_type(trans_type, descrip, retention_days, inv_affecting) values('MXP', 'Matrix Exception PUT for Proforma', 55,'N');

-- SOS_batch_priority TABLE

INSERT INTO SOS_batch_priority (priority_code, priority_value, description) VALUES ('HIGH', 1, 'High Priority SOS Batch');

INSERT INTO SOS_batch_priority (priority_code, priority_value, description) VALUES ('NORMAL', 2, 'Normal Priority SOS Batch');

INSERT INTO SOS_batch_priority (priority_code, priority_value, description) VALUES ('LOW', 3, 'Low Priority SOS Batch');

--sys_config Table

INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'ORDER PROCESSING', 'PRINT_LOGO_ON_SOS_LABEL', 'Print Logo on SOS Label', 'N', 'Y',
                       'N', 'Y', 'CHAR', 1, NULL, 'L',
                       'Print Logo on SOS Label Y/N', NULL,
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('PRINT_LOGO_ON_SOS_LABEL', 'N', 'Print Logo on SOS Label - No');
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('PRINT_LOGO_ON_SOS_LABEL', 'Y', 'Print Logo on SOS Label - Yes');
                               
                               
                               
                               
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'GENERAL', 'LENGTH_UNIT', 'Length Measurement Unit', 'IN', 'Y',
                       'N', 'N', 'CHAR', 2, NULL, 'L',
                       'Length Measurement Unit IN/CM', NULL,
                       'LIST', NULL, NULL, NULL);   
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('LENGTH_UNIT', 'IN', 'Length Measurement Unit - Inch');     
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('LENGTH_UNIT', 'CM', 'Length Measurement Unit - Centimeter');
                               
                               
                               
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'GENERAL', 'SYSCO_LOGO_TYPE', 'Sysco Logo Type', 'Sysco English', 'Y',
                       'N', 'N', 'CHAR', 20, NULL, 'L',
                       'Sysco Logo Type - Sysco English (1)/ Sysco French(2)/ Pallas(3)', NULL,
                       'LIST', NULL, NULL, NULL);         
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Sysco English', 'Sysco Logo Type - Sysco English');    
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Sysco French', 'Sysco Logo Type - Sysco French');   
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Pallas', 'Sysco Logo Type - Pallas');       


INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_DEFAULT_STAGING_DRY', 'Matrix Default Staging Loc Dry', 'LX2222', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default staging location for Matrix dry items.  Order generation will create demand replenishment task to move pallet to this staging location and allocate quantity from this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''D'' order by 1',
                       'LIST', NULL, NULL, NULL);
                                           
INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_DEFAULT_STAGING_CLR', 'Matrix Default Staging Loc Clr', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default staging location for Matrix cooler items.  Order generation will create demand replenishment task to move pallet to this staging location and allocate quantity from this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''C'' order by 1',
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config (seq_no, application_func, config_flag_name, config_flag_desc, config_flag_val, value_required,
                        value_updateable, value_is_boolean, data_type, data_precision, data_scale, sys_config_list,
                        sys_config_help,
                        lov_query,
                        validation_type,range_low, range_high, disabled_flag) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'MATRIX', 'MX_DEFAULT_STAGING_FRZ', 'Matrix Default Staging Loc Frz', '', 'Y',
                       'Y', 'N', 'CHAR', 10, NULL, 'L',
                       'Default staging location for Matrix freezer items.  Order generation will create demand replenishment task to move pallet to this staging location and allocate quantity from this location.',
                       'select loc.logi_loc, loc.descrip from loc, aisle_info ai, swms_sub_areas ssa where loc.slot_type in (''MXT'') and substr(loc.logi_loc, 1, 2) = ai.name and ai.sub_area_code = ssa.sub_area_code and ssa.area_code = ''F'' order by 1',
                       'LIST', NULL, NULL, NULL);                                          

--matrix_interface_maint Table

----Interface outbound-----
INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS01', 'Item_Master', 'pl_xml_matrix_out.sys01_item_master', 'matrix_pm_out', 'Y'); 

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS03', 'Add_Pallet', 'pl_xml_matrix_out.sys03_mx_inv_induct', 'matrix_out', 'Y'); 

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS04', 'Add_Order', 'pl_xml_matrix_out.sys04_add_order', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS05', 'Add_Internal_Order', 'pl_xml_matrix_out.sys05_internal_order', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS06', 'Notify_Case_Removed_Spur', 'pl_xml_matrix_out.sys06_spur_case_removal', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS07', 'Notify_Batch_Status', 'pl_xml_matrix_out.sys07_batch_status', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS08', 'Notify_Update_Pallet', 'pl_xml_matrix_out.sys08_pallet_update', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS09', 'Bulk_File_Request', 'pl_xml_matrix_out.sys09_bulk_request', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS10', 'Bulk_File_Notification', 'pl_xml_matrix_out.sys10_bulk_notification', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS11', 'Update_Order_Batch', 'pl_xml_matrix_out.sys11_update_batch_priority', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS12', 'Cancel_Order_Batch', 'pl_xml_matrix_out.sys12_cancel_order_batch', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS13', 'Cancel_Order_Detail', 'pl_xml_matrix_out.sys13_cancel_order_detail', 'matrix_out', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYS14', 'Add_Order_Detail', 'pl_xml_matrix_out.sys14_add_order_detail', 'matrix_out', 'Y');


--Interface Inbound--

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM03', 'Pallet_Confirm', 'pl_xml_matrix_in.sym03_mx_inv_induct', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM05', 'Batch_Ready', 'pl_xml_matrix_in.sym05_batch_ready', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM06', 'Case_Skipped', 'pl_xml_matrix_in.sym06_case_skipped', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM07', 'Product_Ready', 'pl_xml_matrix_in.sym07_product_ready', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM12', 'Case_Delivered_Spur', 'pl_xml_matrix_in.sym12_case_delivered_spur', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM15', 'Symbotic_Bulk_file_Notif', 'pl_xml_matrix_in.sym15_bulk_notification', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM16', 'Order_Response', 'pl_xml_matrix_in.sym16_order_response', 'matrix_in', 'Y');

INSERT INTO matrix_interface_maint(interface_name, description, package_proc, staging_table, active_flag)
VALUES ('SYM17', 'Labor_Management', 'pl_xml_matrix_in.sym17_labor_management', 'matrix_in', 'Y');  

--auto_orders Table
UPDATE auto_orders
SET mx_exact_pallet_imp = DECODE(order_type, 'VRT', 'ABS', DECODE(immediate_ind, 'Y', 'HIGH', 'LOW'));

UPDATE auto_orders
SET priority = DECODE(mx_exact_pallet_imp,'ABS',1,'HIGH',2, 'LOW',3);              
              
---Insert into Sos_Config 
Insert Into Sos_Config (Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
values ((SELECT max(seq_no) + 1 FROM Sos_Config),'FREEZER','DATA_COLLECT_STATUS','Show initial data coll status','N','1','Y','1','B',0,'No Help Description available');

Insert Into Sos_Config (Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
values ((SELECT max(seq_no) + 1 FROM Sos_Config),'COOLER', 'DATA_COLLECT_STATUS','Show initial data coll status','N','1','Y','1','B',0,'No Help Description available');

Insert Into Sos_Config (Seq_No,Warehouse_Area,Config_Flag_Name,Config_Flag_Desc,Config_Flag_Val,Value_Required,Value_Updateable,Value_Is_Boolean,Data_Type,Data_Precision,Sys_Config_Help) 
Values ((SELECT max(seq_no) + 1 FROM Sos_Config),'DRY',    'DATA_COLLECT_STATUS','Show initial data coll status','N','1','Y','1','B',0,'No Help Description available');

----Alert creation for Symbotic Interfaces
INSERT INTO swms_alert_notification (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
VALUES ('PL_XML_MATRIX_OUT', 'CRIT', 'Y', 'Y', '000-IT-APPDEV-SWMS@corp.sysco.com',  '000-IT-APPDEV-SWMS@corp.sysco.com');

INSERT INTO swms_alert_notification (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
VALUES ('PL_XML_MATRIX_OUT', 'WARN', 'Y', 'Y', '000-IT-APPDEV-SWMS@corp.sysco.com',  '000-IT-APPDEV-SWMS@corp.sysco.com');

INSERT INTO swms_alert_notification (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
VALUES ('PL_MX_STG_TO_SWMS', 'CRIT', 'Y', 'Y', '000-IT-APPDEV-SWMS@corp.sysco.com',  '000-IT-APPDEV-SWMS@corp.sysco.com');

INSERT INTO swms_alert_notification (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
VALUES ('PL_MX_STG_TO_SWMS', 'WARN', 'Y', 'Y', '000-IT-APPDEV-SWMS@corp.sysco.com',  '000-IT-APPDEV-SWMS@corp.sysco.com');

----Matrix Staging table purge 

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_IN', 25, 'Messages from Symbotic');

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_OUT', 25, 'Messages to Symbotic');

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_PM_OUT', 25, 'Item Master Messages to Symbotic');

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_OUT_LABEL', 25, 'Matrix Label Information to Symbotic');

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_PM_BULK_OUT', 5, 'Matrix Item Master Bulk to Symbotic');

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('MATRIX_INV_BULK_IN', 10, 'Matrix INV Bulk from Symbotic');
			  			  
spool off
