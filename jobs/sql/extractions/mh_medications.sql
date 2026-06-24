SET @partition = '${partitionNum}';
select encounter_type_id into @mh_consult from encounter_type et2 where uuid = 'a8584ab8-cc2a-11e5-9956-625662870761';
select encounter_type_id into @mh_intake from encounter_type et2 where uuid = 'fccd53c2-f802-439b-a7a2-2d680bd8b81b';
select encounter_type_id into @epilepsy_followup from encounter_type et2 where uuid = '74e06462-243e-4fad-8d7c-0bb3921322f1';
select encounter_type_id into @epilepsy_intake from encounter_type et2 where uuid = '7336a05e-4bd1-4e52-81c1-207697afc868';

drop temporary table if exists temp_mh_meds;
create temporary table temp_mh_meds
(
meds_id int auto_increment primary key,
patient_id int(11),
emr_id varchar(50),
encounter_id int(11),
encounter_type_id int(11),
encounter_type varchar(255),
obs_group_id int(11),
encounter_date date,
provider varchar(50),
date_entered date,
user_entered varchar(50),
drug_short_name varchar(255),
drug_name varchar(255),
dose double,
dose_unit varchar(255),
dose_frequency varchar(50),
duration double,
duration_unit varchar(50),
route varchar(50),
additional_medication_comments varchar(255),
index_asc int(5),
index_desc int(5)
);

DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS
SELECT patient_id, encounter_id, encounter_datetime, creator, encounter_type
FROM encounter e
WHERE e.encounter_type in (@mh_consult, @mh_intake, @epilepsy_followup, @epilepsy_intake)
AND e.voided =0;

create index temp_encounter_ci1 on temp_encounter(encounter_id);

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS
SELECT o.person_id, o.obs_id , o.obs_group_id , o.obs_datetime ,o.date_created , o.encounter_id, o.value_coded, o.concept_id, o.value_numeric , o.value_datetime , o.value_text , o.voided
FROM temp_encounter te
INNER JOIN  obs o ON te.encounter_id=o.encounter_id
WHERE o.voided =0;

insert into temp_mh_meds(encounter_id, obs_group_id, patient_id, encounter_date, encounter_type_id)
select
e.encounter_id,
obs_id,
e.patient_id,
e.encounter_datetime,
e.encounter_type
from temp_obs o
inner join temp_encounter e on e.encounter_id  = o.encounter_id
where concept_id = concept_from_mapping('PIH','10742');

set @identifier_type ='0bc545e0-f401-11e4-b939-0800200c9a66';

update temp_mh_meds t
set emr_id = patient_identifier(t.patient_id, @identifier_type);

update temp_mh_meds t
set encounter_type = encounter_type_name_from_id(t.encounter_type_id);

update temp_mh_meds t
set user_entered = encounter_creator(t.encounter_id);

update temp_mh_meds t
set provider = provider(t.encounter_id);

update temp_mh_meds t
set date_entered = encounter_date_created(t.encounter_id);

update temp_mh_meds t
set drug_short_name = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','10634','en');

update temp_mh_meds t
set drug_name = obs_from_group_id_value_drug(t.obs_group_id, 'PIH','10634');

update temp_mh_meds t
set dose_frequency = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','9363','en');

update temp_mh_meds t
set dose_unit = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','10744','en');

update temp_mh_meds t
set dose = obs_from_group_id_value_numeric(t.obs_group_id, 'PIH','9073');

update temp_mh_meds t
set duration = obs_from_group_id_value_numeric(t.obs_group_id, 'PIH','9075');

update temp_mh_meds t
set duration_unit = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','6412', 'en');

update temp_mh_meds t
set route = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','12651','en');

update temp_mh_meds t
set additional_medication_comments = obs_value_text(t.encounter_id, 'PIH','10637');

drop temporary table if exists temp_mh_meds_index_asc;
CREATE TEMPORARY TABLE temp_mh_meds_index_asc
(
    SELECT
            meds_id,
            patient_id,
            drug_short_name,
            encounter_id,
            index_asc
FROM (SELECT
            @r:= IF(@u = drug_short_name, @r + 1,1) index_asc,
            drug_short_name,
            encounter_id,
            patient_id,
            meds_id,
            @u:= drug_short_name
      FROM temp_mh_meds tm,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id ASC, drug_short_name ASC, encounter_id ASC
        ) index_ascending );

CREATE INDEX tmia_e ON temp_mh_meds_index_asc(encounter_id);
update temp_mh_meds tm
inner join temp_mh_meds_index_asc tmia on tmia.meds_id = tm.meds_id
set tm.index_asc = tmia.index_asc;

drop temporary table if exists temp_mh_meds_index_desc;
CREATE TEMPORARY TABLE temp_mh_meds_index_desc
(
    SELECT
            meds_id,
            patient_id,
            drug_short_name,
            encounter_id,
            index_desc
FROM (SELECT
            @r:= IF(@u = drug_short_name, @r + 1,1) index_desc,
            drug_short_name,
            patient_id,
            encounter_id,
            meds_id,
            @u:= drug_short_name
      FROM temp_mh_meds,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id DESC, drug_short_name DESC, encounter_id DESC
        ) index_descending );

CREATE INDEX tmid_e ON temp_mh_meds_index_desc(encounter_id);
update temp_mh_meds mm
inner join temp_mh_meds_index_desc tmid on tmid.meds_id = mm.meds_id
set mm.index_desc = tmid.index_desc;

select
    concat(@partition,"-",patient_id) patient_id,
    emr_id,
    concat(@partition,"-",encounter_id) encounter_id,
    encounter_type,
    concat(@partition,"-",obs_group_id) obs_group_id,
    encounter_date,
    provider,
    date_entered,
    user_entered,
    drug_short_name,
    drug_name,
    dose,
    dose_unit,
    dose_frequency,
    duration,
    duration_unit,
    route,
    additional_medication_comments,
    index_asc,
    index_desc
from temp_mh_meds;
