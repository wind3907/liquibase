--CRQ #33411, created for keeping track of damage quantity


/********************************************************************
**    Create records in CC_REASON table__aver0639__9/29/12
********************************************************************/

insert into cc_reason
(cc_reason_code,description,cc_priority,cc_delete,rf_method,adj_by_reason,host_gl_account,adj_priority)
values('SP','Spoilage',7,'Y','Item/Aisle','N','CC',7);

insert into cc_reason
(cc_reason_code,description,cc_priority,cc_delete,rf_method,adj_by_reason,host_gl_account,adj_priority)
values('SR','Sales Returns or Damage',7,'Y','Item/Aisle','N','CC',7);

insert into cc_reason
(cc_reason_code,description,cc_priority,cc_delete,rf_method,adj_by_reason,host_gl_account,adj_priority)
values('TD','Truck Damage',7,'Y','Item/Aisle','N','CC',7);

insert into cc_reason
(cc_reason_code,description,cc_priority,cc_delete,rf_method,adj_by_reason,host_gl_account,adj_priority)
values('WH','Warehouse Damage',7,'Y','Item/Aisle','N','CC',7);

commit;
/
