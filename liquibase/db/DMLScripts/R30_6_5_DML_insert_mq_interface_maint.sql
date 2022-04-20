
insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 1, 'Q_SPL_IM_IN',  'SWMS');


insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 1, 'Q_SPL_PO_IN',  'SWMS');


insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 1, 'Q_SPL_CU_IN', 'SWMS');


insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 1, 'Q_SPL_OR_IN', 'SWMS');


insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 2, 'Q_SPL_IA_OUT', 'SWMS');


insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 2, 'Q_SPL_PW_OUT',  'SWMS');

insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name,queue_owner)
values
('Y', 2, 'Q_SPL_OW_OUT', 'SWMS');

insert into mq_interface_maint
(active_flag, propagation_type, aq_queue_name, queue_owner)
values
('Y', 2, 'Q_SPL_WH_OUT',  'SWMS');

commit;
