
insert into ml_functionality
values
(1,'Alert_Title');

insert into ml_functionality
values
(2,'Alert_Message_Text');

insert into ml_functionality
values
(3,'Alert_Button1');

insert into ml_functionality
values
(4,'Alert_Button2');

insert into ml_functionality
values
(5,'Alert_Button3');

insert into ml_functionality
values
(6,'Label_For_Display_Items');

insert into ml_functionality
values
(7,'Hint_Text_For_Items');

insert into ml_functionality
values
(8,'ToolTip_Text_For_Items');

insert into ml_functionality
values
(9,'Label_For_Radio_Button');

insert into ml_functionality
values
(10,'Label_For_Tab_Pages');

insert into ml_functionality
values
(11,'Title_For_LOV');

insert into ml_functionality
values
(12,'Title_Column_For_LOV');

insert into ml_functionality
values
(13,'Title_For_Windows');

insert into ml_functionality
values
(14,'Label_For_Menu_Items');

insert into ml_functionality
values
(15,'Prompt_Text_For_Items');

insert into ml_functionality
values
(16,'Prompt_Text_For Radio_Button');

insert into ml_functionality
values
(99,'Set The Content For The Display Items used For Multi-Language');



insert into FORMS_XREF_LOCATION
(form_name,description)
select mod.name_form,v.text
from ml_modules mod,ml_values v
where mod.PK_ML_MODULES = v.FK_ML_MODULES
and v.ID_FUNCTIONALITY = 13
and mod.type_form = 10
and mod.NAME_OBJECT = 'PAGE_1'
and id_language = 3
order by mod.name_form;

select mod.name_form,v.text,mod.NAME_OBJECT
from ml_modules mod,ml_values v
where mod.PK_ML_MODULES = v.FK_ML_MODULES
and  not exists (select 'x' from forms_xref_location f where f.form_name = mod.name_form)
and v.ID_FUNCTIONALITY = 13
and mod.type_form = 10
and mod.NAME_OBJECT not in ('PAGE_1','ROOT_WINDOW','WINDOW1','WIN_MAIN')
and id_language = 3
order by mod.name_form;

insert into FORMS_XREF_LOCATION
(form_name,description)
select mod.name_form,v.text
from ml_modules mod,ml_values v
where mod.PK_ML_MODULES = v.FK_ML_MODULES
and  not exists (select 'x' from forms_xref_location f where f.form_name = mod.name_form)
and v.ID_FUNCTIONALITY = 13
and mod.type_form = 10
and mod.NAME_OBJECT in ('LOGON_WINDOW','WINDOW0','MINILOAD_MESSAGE','HACCP_CODES','SYSPAR_WINDOW','WHMV_MINILOAD_ITEM',
     'PAGE1','VIEW_RECEIVING_DETAILS')
and id_language = 3;
