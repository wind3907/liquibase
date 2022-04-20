/****************************************************************************
** File:       STS_OPCO_DCID_DML.sql
**
** Desc: Script to insert  data for sts templates
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    24-Oct-2018 Vishnupriya K.     setup data for STS_OPCO_DCID table
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM STS_OPCO_DCID;
  

IF (v_column_exists = 0)  THEN

--REM INSERTING into STS_OPCO_DCID
--SET DEFINE OFF; 
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1055','025','Albany_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1060','049','Arizona_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1050','029','Arkansas_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('9995','103','AsianFoods','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1065','002','Atlanta_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1070','020','Austin_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('5450','335','Bahamas_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1075','012','Baltimore_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1080','018','Baraboo_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1085','056','Boston_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3015','181','CACalgary_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3085','077','CACentralON_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3010','257','CAEdmonton_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3065','265','CAHalifax_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3020','162','CAKelowna_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3100','273','CAKingston_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3105','256','CAMilton_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3080','262','CAMoncton_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3055','272','CAMontreal_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3075','268','CANASYS_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3005','258','CARegina_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3125','338','CASouthWesternOntario_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('838','838','CASouthWesternOntario_RDC','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3070','264','CAStJohns_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3115','274','CAThunderBay_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3090','180','CAToronto_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3030','044','CAVancouver_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3025','139','CAVictoria_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3130','309','CAWindsor_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('3110','259','CAWinnipeg_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1090','046','CentralAlabama_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1095','004','CentralCA_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1100','022','CentralFlorida_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1105','194','CentralIllinois_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1115','051','CentralPA_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1335','013','CentralTexas_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1120','048','Charlotte_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1125','024','Chicago_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1130','019','Cincinnati_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1135','015','Cleveland_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1140','137','Columbia_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1145','054','Connecticut_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1150','006','Dallas_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1155','059','Denver_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1160','058','Detroit_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('331','331','Distagro_OpCo','temp_fre2');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1170','010','EasternMaryland_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1165','293','EastTexas_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1175','035','EastWisconsin_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1180','068','GrandRapids_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1185','164','GulfCoast_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1190','073','HamptonRoads_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1195','067','Houston_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1200','040','Idaho_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1205','038','Indianapolis_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1210','005','Intermountain_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1215','039','Iowa_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1220','001','Jackson_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1225','003','Jacksonville_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1230','057','KansasCity_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1235','288','Knoxville_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1240','017','LasVegas_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1245','061','Lincoln_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1415','306','LongIsland_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1250','045','LosAngeles_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1255','011','Louisville_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1260','014','Memphis_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1265','076','MetroNewYork_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1705','146','MidWest_CW','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1270','047','Minnesota_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1275','043','Montana_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1280','060','Nashville_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1285','066','NewMexico_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1290','023','NewOrleans_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1700','042','NorthCentral_CW','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1295','195','NorthDakota_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1720','148','NorthEast_CW','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1300','008','NorthernNewEngland_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1305','026','Oklahoma_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1310','075','Philadelphia_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1315','009','Pittsburgh_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1320','052','Portland_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1325','163','Raleigh_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1425','320','Riverside_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1330','031','Sacramento_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1340','036','SanDiego_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1345','050','SanFrancisco_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1350','055','Seattle_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1360','032','SouthEastFL_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1355','016','SouthFlorida_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1365','102','Spokane_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1370','064','StLouis_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1375','027','Syracuse_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1380','101','Ventura_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1385','007','Virginia_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1390','037','WestFlorida_OpCo','temp_eng');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1395','078','WestTexas_OpCo','temp_tale');
Insert into STS_OPCO_DCID (DCID,OPCO_ID,OPCO_NAME,TMPLT) values ('1430','332','WMinnesota_OpCo','temp_tale');
commit;
                         
End If;
End;	
/						  