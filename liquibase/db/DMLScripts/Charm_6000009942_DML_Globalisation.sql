/* To insert new fields for Case dimensions for RP3RA report Charm# 6*9942 */

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','18','Case|Hgt','4');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','19','Case|Len','4');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','20','Case|Wid','4');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','21','Case|Wt','4');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','22','S|P','7');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','23','Case|Cube','11');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','24','P|S','7');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','25','''AR-Area''','10');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','26','''SP-Splitable''','10');

insert into swms.global_report_dict
(lang_id, report_name,fld_lbl_name,fld_lbl_desc,max_len)
values
('3','rp3ra','27','''PS-PO/SN Status (N=NEW,S=SCH)''','20');

Update swms.global_report_dict set fld_lbl_desc = 'S|T',max_len = '4' 
where report_name like '%rp3ra%' and lang_id = '3' and fld_lbl_name = '8';

Commit;
