insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
3, 'RESTRICT', 'MEAT', 'Meat Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'MEAT' and id_language=3); 
insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
3, 'RESTRICT', 'SEAFOOD', 'Seafood Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'SEAFOOD' and id_language=3); 
insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
3, 'RESTRICT', 'CHEMICAL', 'Chemical Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'CHEMICAL' and id_language=3); 
insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
3, 'RESTRICT', 'EGG', 'Egg Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'EGG' and id_language=3); 
insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
3, 'RESTRICT', 'FISH', 'Fish Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'FISH' and id_language=3); 
insert into SWMS_MAINT_LOOKUP 
(ID_LANGUAGE,CODE_TYPE,Code_name, code_desc,corp_control)
select 
 3, 'RESTRICT', 'CHICKEN', 'Chicken Zone Restriction', 'Y' from dual 
where not exists (select 1 from SWMS_MAINT_LOOKUP  where Code_name = 'CHICKEN' and id_language=3); 
commit;
 