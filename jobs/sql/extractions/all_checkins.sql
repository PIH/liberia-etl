-- NOTE:  This script was copied over from an older script that has been uses as the export for years
-- If this starts to get slow, there are many performance improvements that can be made (functions/temp tables etc...) 
SET @locale = GLOBAL_PROPERTY_VALUE('default_locale', 'en');
set @partition = '${partitionNum}';
SELECT encounter_type_id INTO @enctype FROM encounter_type et WHERE uuid='55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b';

DROP TABLE IF EXISTS checkin_details;
CREATE TEMPORARY TABLE checkin_details (
patient_id             int,          
emr_id                 varchar(50),  
encounter_id           int,         
visit_id               int,
encounter_datetime     datetime,     
encounter_location     varchar(255), 
datetime_entered       datetime,     
user_entered           varchar(255), 
encounter_provider     varchar(255), 
reason_of_visit        varchar(255), 
referred_or_escorted   varchar(255), 
referred_by            varchar(255), 
escorting_person_name  text,         
escorting_person_phone text);        

INSERT INTO checkin_details(patient_id,emr_id,encounter_id, visit_id, encounter_datetime,encounter_location,datetime_entered,user_entered,encounter_provider)
SELECT 
patient_id,
patient_identifier(patient_id, '0bc545e0-f401-11e4-b939-0800200c9a66'),
encounter_id,
visit_id,
encounter_datetime ,
encounter_location_name(encounter_id),
date_created,
encounter_creator(encounter_id),
provider(encounter_id)
FROM encounter 
WHERE encounter_type=@enctype;

-- reason_of_visit
UPDATE checkin_details s INNER JOIN obs o 
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','6189')
AND o.voided =0
SET reason_of_visit= value_coded_name(o.obs_id,'en');


-- referred_or_escorted
UPDATE checkin_details s INNER JOIN obs o 
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','6547')
AND o.voided =0
SET referred_or_escorted= value_coded_name(o.obs_id,'en');

-- referred_by
UPDATE checkin_details s INNER JOIN obs o 
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','14494')
AND o.voided =0
SET referred_by= value_coded_name(o.obs_id,'en');

-- escorting_person_name
UPDATE checkin_details s INNER JOIN obs o 
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','11631')
AND o.voided =0
SET escorting_person_name= value_text;

-- escorting_person_phone
UPDATE checkin_details s INNER JOIN obs o 
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','2614')
AND o.voided =0
SET escorting_person_phone= value_text;

SELECT 
	emr_id,
	concat(@partition,"-",encounter_id) as encounter_id,
    concat(@partition,"-",patient_id)  as patient_id,
    concat(@partition,"-",visit_id)  as visit_id,
	encounter_datetime,
	encounter_location,
	datetime_entered,
	user_entered,
	encounter_provider,
	reason_of_visit,
	referred_or_escorted,
	referred_by,
	escorting_person_name,
	escorting_person_phone
	FROM checkin_details
ORDER BY encounter_id desc;
