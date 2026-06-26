set @locale = 'en';
set @partition = '${partitionNum}';
set @program_id = program('Mental Health');
SELECT encounter_type_id INTO @mh_intake_enc FROM encounter_type WHERE uuid = 'fccd53c2-f802-439b-a7a2-2d680bd8b81b';
set @identifier_type ='0bc545e0-f401-11e4-b939-0800200c9a66';

DROP TABLE IF EXISTS temp_mh_patients;
create temporary table temp_mh_patients
(
enrollment_id int auto_increment primary key,
patient_id int,
program_id int,
encounter_id int,
emr_id varchar(255),
mh_mrn varchar(255),
dob date,
current_age int,
community varchar(255),
district varchar(255),
county varchar(255),
gender varchar(255),
referred_by varchar(255),
referred_from varchar(255),
date_enrolled date,
counseling_plan text,
outcome_date date,
program_outcome varchar(255),
mh_diagnoses text,
index_asc int,
index_desc int
);

INSERT INTO temp_mh_patients (patient_id, program_id, date_enrolled, outcome_date, program_outcome)
SELECT
    patient_id,
    program_id,
    date_enrolled,
    date_completed,
	concept_name(outcome_concept_id, 'en')
FROM patient_program
WHERE program_id = @program_id AND voided = 0;


set @mh_identifier = '23507d1e-4f22-11ea-9717-645d86728797'; -- mental health patient assign number

update temp_mh_patients set emr_id = patient_identifier(patient_id, @identifier_type);
UPDATE temp_mh_patients SET mh_mrn = PATIENT_IDENTIFIER(patient_id, @mh_identifier);
UPDATE temp_mh_patients SET community = PERSON_ADDRESS_ONE(patient_id);
UPDATE temp_mh_patients SET district= person_address_city_village(patient_id);
UPDATE temp_mh_patients SET county = person_address_state_province(patient_id);

UPDATE temp_mh_patients SET current_age = current_age_in_years(patient_id);


DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS
SELECT patient_id, encounter_id, encounter_datetime, encounter_type
FROM encounter e
WHERE e.encounter_type = @mh_intake_enc
AND e.voided =0;

CREATE INDEX t_enc_patient_id ON temp_encounter (patient_id);

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS
SELECT o.person_id, o.obs_id , o.obs_group_id , o.obs_datetime ,o.date_created , o.encounter_id, o.value_coded, o.concept_id, o.value_numeric , o.value_datetime , o.value_text , o.voided
FROM temp_encounter te  INNER JOIN  obs o ON te.encounter_id=o.encounter_id
WHERE o.voided =0;

drop temporary table if exists temp_mh_patients_index_asc;
CREATE TEMPORARY TABLE temp_mh_patients_index_asc
(
    SELECT
			enrollment_id,
            patient_id,
            date_enrolled,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            enrollment_id,
            date_enrolled,
            patient_id,
            @u:= patient_id
      FROM temp_mh_patients tmp,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, date_enrolled ASC
        ) index_ascending );

CREATE INDEX tmhia ON temp_mh_patients_index_asc(patient_id);
update temp_mh_patients tmhp
inner join temp_mh_patients_index_asc tmhia on tmhp.enrollment_id = tmhia.enrollment_id
set tmhp.index_asc = tmhia.index_asc;

drop temporary table if exists temp_mh_patients_index_desc;
CREATE TEMPORARY TABLE temp_mh_patients_index_desc
(
    SELECT
			enrollment_id,
            patient_id,
            date_enrolled,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            enrollment_id,
            date_enrolled,
            patient_id,
            @u:= patient_id
      FROM temp_mh_patients tmp,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id DESC, date_enrolled DESC
        ) index_descending );

CREATE INDEX tmhia ON temp_mh_patients_index_desc(patient_id);
update temp_mh_patients tmhp
inner join temp_mh_patients_index_desc tmhia on tmhp.enrollment_id = tmhia.enrollment_id
set tmhp.index_desc = tmhia.index_desc;

UPDATE temp_mh_patients tmh
SET
	tmh.gender = GENDER(tmh.patient_id),
	tmh.dob = BIRTHDATE(tmh.patient_id);

set @referred_by =  CONCEPT_FROM_MAPPING('PIH', '10647');
UPDATE temp_mh_patients tmh
INNER JOIN temp_obs o ON tmh.patient_id = o.person_id
AND o.concept_id = @referred_by
SET tmh.referred_by = CONCEPT_NAME(value_coded, 'en');

set @referred_from = CONCEPT_FROM_MAPPING('PIH', '1272');
UPDATE temp_mh_patients tmh
INNER JOIN temp_obs o ON tmh.patient_id = o.person_id
AND o.concept_id =  @referred_from
SET tmh.referred_from = CONCEPT_NAME(value_coded, 'en');

set @counseling_plan = CONCEPT_FROM_MAPPING('PIH', '14479');
UPDATE temp_mh_patients tmh
INNER JOIN temp_obs o ON tmh.patient_id = o.person_id
AND o.concept_id = @counseling_plan
SET tmh.counseling_plan = o.value_text;

set @mh_diagnoses = concept_from_mapping('PIH','7942');
DROP temporary table IF EXISTS temp_mh_dx_set;
create temporary table temp_mh_dx_set
select concept_id from concept_set
where concept_set  = @mh_diagnoses;

insert into temp_mh_dx_set  -- in case there are any sets of diagnoses within this set
select concept_id from concept_set
where concept_set in
  (select concept_id from concept_set
where concept_set  = @mh_diagnoses);

set @diagnosis = concept_from_mapping('PIH','3064');
update temp_mh_patients t
inner join
 (select o.person_id, group_concat(distinct concept_name(o.value_coded, @locale)) dxs
from obs o
inner join temp_mh_dx_set s on s.concept_id = o.value_coded
where o.concept_id =@diagnosis and o.voided = 0
group by o.person_id) i on i.person_id = t.patient_id
set t.mh_diagnoses = i.dxs ;

SELECT
    concat(@partition,"-",patient_id) patient_id,
    emr_id,
    mh_mrn,
    dob,
    gender,
    community,
    district,
    county,
    current_age,
    referred_by,
    referred_from,
    date_enrolled,
    outcome_date,
    counseling_plan,
    mh_diagnoses,
    program_outcome,
    index_asc,
    index_desc
FROM
    temp_mh_patients;
