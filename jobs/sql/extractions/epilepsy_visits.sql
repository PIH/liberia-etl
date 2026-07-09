SET @partition = '${partitionNum}';
SELECT encounter_type_id INTO @epilepsyFollowup FROM encounter_type et WHERE uuid='74e06462-243e-4fad-8d7c-0bb3921322f1';
SELECT encounter_type_id INTO @epilepsyIntake FROM encounter_type et WHERE uuid='7336a05e-4bd1-4e52-81c1-207697afc868';

DROP TABLE IF EXISTS epilepsy_export;
CREATE TEMPORARY TABLE epilepsy_export (
patient_id int,
emr_id varchar(255),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(255),
date_entered date,	
encounter_type varchar(255),
user_entered varchar(255),
encounter_provider varchar(255),
onset_date date,
general_seizure_type varchar(500),
disposition varchar(255),
medications varchar(500),
next_appointment date,
index_asc int,
index_desc int
);

INSERT INTO epilepsy_export(patient_id,emr_id,encounter_id,encounter_datetime,encounter_type,encounter_location,date_entered,user_entered,encounter_provider)
SELECT
patient_id,
patient_identifier(patient_id, '0bc545e0-f401-11e4-b939-0800200c9a66'),
encounter_id,
encounter_datetime,
encounter_type_name_from_id(encounter_type),
encounter_location_name(encounter_id),
date_created,
encounter_creator(encounter_id),
provider(encounter_id)
FROM encounter
WHERE encounter_type in (@epilepsyIntake, @epilepsyFollowup)
AND voided = 0;

-- onset date
UPDATE epilepsy_export s INNER JOIN obs o
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','7538')
AND o.voided =0
SET onset_date= CAST(value_datetime AS date);

-- general_seizure_type
UPDATE epilepsy_export s
SET general_seizure_type =(
SELECT group_concat(distinct value_coded_name(o.obs_id,'en') separator ' | ')
FROM obs o
WHERE o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','12400')
AND o.voided =0
);

-- disposition
UPDATE epilepsy_export s INNER JOIN obs o
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','8620')
AND o.voided =0
SET disposition= value_coded_name(o.obs_id,'en');

-- next appointment date
UPDATE epilepsy_export s INNER JOIN obs o
ON o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','5096')
AND o.voided =0
SET next_appointment= CAST(value_datetime AS date);

-- medications
UPDATE epilepsy_export s
SET medications =(
SELECT group_concat(distinct drugName(o.value_drug) separator ' | ')
FROM obs o
WHERE o.encounter_id =s.encounter_id
AND o.concept_id = concept_from_mapping('PIH','10634')
AND o.voided =0
);

DROP TEMPORARY TABLE IF EXISTS temp_encounter_index_asc;
CREATE TEMPORARY TABLE temp_encounter_index_asc
(
    SELECT
            patient_id,
            encounter_id,
            encounter_datetime,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            patient_id,
            encounter_datetime,
            encounter_id,
            @u:= patient_id
      FROM epilepsy_export,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id ASC, encounter_datetime ASC, encounter_id ASC
        ) index_asc );

UPDATE epilepsy_export t
INNER JOIN temp_encounter_index_asc tsia ON tsia.patient_id = t.patient_id AND tsia.encounter_id = t.encounter_id
SET t.index_asc = tsia.index_asc;

DROP TEMPORARY TABLE IF EXISTS temp_encounter_index_desc;
CREATE TEMPORARY TABLE temp_encounter_index_desc
(
    SELECT
            patient_id,
            encounter_id,
            encounter_datetime,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            patient_id,
            encounter_datetime,
            encounter_id,
            @u:= patient_id
      FROM epilepsy_export,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id ASC, encounter_datetime DESC, encounter_id DESC
        ) index_desc );

UPDATE epilepsy_export t
INNER JOIN temp_encounter_index_desc tsia ON tsia.patient_id = t.patient_id AND tsia.encounter_id = t.encounter_id
SET t.index_desc = tsia.index_desc;

SELECT
    concat(@partition,"-",patient_id) patient_id,
    emr_id,
    concat(@partition,"-",encounter_id) encounter_id,
    encounter_type,
    CAST(encounter_datetime AS date) encounter_date,
    encounter_provider AS provider_name,
    encounter_location,
    onset_date,
    general_seizure_type,
    medications,
    disposition,
    next_appointment AS next_appointment_date,
    date_entered,
    user_entered,
    index_asc,
    index_desc
FROM epilepsy_export;
