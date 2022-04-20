set define off
set serveroutput on
--******************************************************************************************************
-- Language table creation
--*****************************************************************************************************
CREATE TABLE swms.language
 (
  id_language                NUMBER ,
  desc_language              VARCHAR2(50),
  current_language           VARCHAR2(1)  NOT NULL
 );

ALTER TABLE swms.language
 ADD CONSTRAINT pk_language_id PRIMARY KEY (id_language);

--******************************************************************************************************
-- ML_Modules table creation
--******************************************************************************************************
CREATE TABLE swms.ml_modules
 (
  pk_ml_modules              NUMBER  ,
  name_form                  VARCHAR2(256) NOT NULL,
  object_type                NUMBER       NOT null,
  name_object                VARCHAR2(30) NOT NULL,
  aux_info1                  VARCHAR2(30),
  aux_info2                  VARCHAR2(30),
  type_form                  NUMBER       NOT NULL
 );

ALTER TABLE swms.ml_modules
 ADD CONSTRAINT pk_ml_modules PRIMARY KEY (pk_ml_modules);

ALTER TABLE swms.ml_modules
 ADD CONSTRAINT uk_ml_modules UNIQUE (name_form,name_object,aux_info1,aux_info2);

CREATE  INDEX swms.idx1_ml_modules
 ON swms.ml_modules
  ( name_form  );
--******************************************************************************************************
-- ML_VALUES table creation
--******************************************************************************************************
CREATE TABLE swms.ml_values
 (
  fk_ml_modules              NUMBER,
  id_language                NUMBER NOT NULL,
  id_functionality           NUMBER NOT NULL,
  text                       VARCHAR2(4000)
 );

ALTER TABLE swms.ml_values
 ADD CONSTRAINT uk_ml_values UNIQUE (fk_ml_modules,id_language,id_functionality);

ALTER TABLE swms.ml_values
 ADD CONSTRAINT fk_languages FOREIGN KEY (id_language)
      REFERENCES LANGUAGE(id_language);

ALTER TABLE swms.ml_values
 ADD CONSTRAINT fk_ml_modules FOREIGN KEY (fk_ml_modules)
      REFERENCES swms.ML_MODULES(pk_ml_modules) ON DELETE CASCADE ;

CREATE  INDEX swms.idx1_ml_values
 ON swms.ml_values
  ( id_language  );

--******************************************************************************************************
-- ML_LIST_ITEMS_VALUES table creation
--******************************************************************************************************
CREATE TABLE swms.ml_list_items_values
(
list_id                    Number              Not Null,
id_language                Number              Not Null,
list_index                 Number              Not Null,
list_label                 Varchar2(256 Char),
list_value                 Varchar2(256 Char)
);

ALTER TABLE swms.ml_list_items_values
ADD CONSTRAINT uk_ml_list_items_values_xx UNIQUE (list_id, id_language, list_index);

ALTER TABLE swms.ml_list_items_values
ADD CONSTRAINT fk_id_language_xx FOREIGN KEY (id_language)
      REFERENCES swms.language(id_language);

ALTER TABLE swms.ml_list_items_values
ADD CONSTRAINT fk_list_id_xx FOREIGN KEY (list_id)
      REFERENCES swms.ml_modules(pk_ml_modules) ON DELETE CASCADE;

--******************************************************************************************************
-- Message_table table creation
--******************************************************************************************************
CREATE TABLE swms.message_table
(
id_message                 Number              Not Null,
v_message                  Varchar2(4000 Char) Not Null,
id_language                Number              Not Null
);

ALTER TABLE swms.message_table
ADD CONSTRAINT pk_message_xx PRIMARY KEY (id_language,id_message);

--******************************************************************************************************
-- GLOBAL DATE FORMAT table creation
--******************************************************************************************************
CREATE TABLE "SWMS"."GLOBAL_DATE_FORMAT" 
   (	"FORMAT_SEQ" NUMBER(2,0) NOT NULL ENABLE, 
	"FORMAT_MASK" VARCHAR2(30 CHAR) NOT NULL ENABLE, 
	 CONSTRAINT "GLOBAL_DATE_FORMAT_PK" PRIMARY KEY ("FORMAT_SEQ")
   );
--*****************************************************************************************************
-- GLOABAL LANGAUAGE table creation
--*****************************************************************************************************
  CREATE TABLE "SWMS"."GLOBAL_LANGUAGE_MAPPING" 
   (	"LANGUAGE" VARCHAR2(15 CHAR) NOT NULL ENABLE, 
	"TERRITORY" VARCHAR2(15 CHAR) NOT NULL ENABLE,
	"LANG_ID" NUMBER(3,0) NOT NULL ENABLE, 
	"CODE" VARCHAR2(6 CHAR) NOT NULL ENABLE, 
	 CONSTRAINT "GLOBAL_LANGUAGE_MAPPING_PK" PRIMARY KEY ("LANGUAGE", "TERRITORY")
   ); 
--******************************************************************************************************
-- GLOBAL REPORT DICTIONARY table creation
--******************************************************************************************************

  CREATE TABLE "SWMS"."GLOBAL_REPORT_DICT" 
   (	"LANG_ID" NUMBER(2,0) NOT NULL ENABLE, 
	"REPORT_NAME" VARCHAR2(30 CHAR) NOT NULL ENABLE, 
	"FLD_LBL_NAME" VARCHAR2(50 CHAR) NOT NULL ENABLE, 
	"FLD_LBL_DESC" VARCHAR2(100 CHAR), 
	"MAX_LEN" NUMBER(3,0), 
	"ADD_USER" VARCHAR2(50 CHAR), 
	"ADD_DATE" DATE, 
	"UPDATE_USER" VARCHAR2(50 CHAR), 
	"UPDATE_DATE" DATE,
	"FLD_LBL_NO" NUMBER(5),
   CONSTRAINT " GLOBAL_REPORT_DICT_PK" PRIMARY KEY ("LANG_ID","REPORT_NAME","FLD_LBL_NAME")
   ); 
--**********************************************************************************************************
