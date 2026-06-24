SET @locale = global_property_value('default_locale', 'en');
SET @partition = '${partitionNum}';
set sql_safe_updates = 0;

drop temporary table if exists temp_diagnoses;
create temporary table temp_diagnoses (
    obs_id                  int not null,
    obs_group_id            int,
    patient_id              int,
    encounter_id            int,
    encounter_datetime      datetime,
    date_entered            datetime,
    user_created_id         int,
    diagnosis_concept_id    int,
    emr_id                  varchar(50),
    encounter_type          varchar(255),
    encounter_location      varchar(255),
    user_entered            varchar(255),
    encounter_provider      varchar(255),
    diagnosis_order         varchar(50),
    diagnosis               varchar(255)
);
create index temp_diagnoses_group_idx on temp_diagnoses(obs_group_id);
create index temp_diagnoses_patient_idx on temp_diagnoses(patient_id);
create index temp_diagnoses_encounter_idx on temp_diagnoses(encounter_id);
create index temp_diagnoses_user_created_idx on temp_diagnoses(user_created_id);

set @mentalHealthDiagnosisSet = concept_from_mapping('PIH', 'HUM Psychological diagnosis');
set @diagnosisConcept = concept_from_mapping('PIH', 'DIAGNOSIS');

insert into temp_diagnoses (obs_id, obs_group_id, patient_id, encounter_id, encounter_datetime, date_entered, user_created_id, diagnosis_concept_id)
select o.obs_id, o.obs_group_id, o.person_id, o.encounter_id, e.encounter_datetime, e.date_created, o.creator, o.value_coded
from obs o
inner join encounter e on o.encounter_id = e.encounter_id
inner join patient p on e.patient_id = p.patient_id
where o.voided = 0 and e.voided = 0 and p.voided = 0
and o.concept_id = @diagnosisConcept
and o.value_coded in (select concept_id from concept_set where concept_set = @mentalHealthDiagnosisSet);

update temp_diagnoses set emr_id = primary_emr_id(patient_id);
update temp_diagnoses set encounter_type = encounter_type_name(encounter_id);
update temp_diagnoses set encounter_location = encounter_location_name(encounter_id);
update temp_diagnoses set user_entered = person_name_of_user(user_created_id);
update temp_diagnoses set encounter_provider = provider(encounter_id);
update temp_diagnoses set diagnosis_order = obs_from_group_id_value_coded(obs_group_id, 'PIH', 'Diagnosis order', @locale);
update temp_diagnoses set diagnosis = concept_name(diagnosis_concept_id, @locale);

select
    concat(@partition,"-",patient_id) patient_id,
    emr_id,
    concat(@partition,"-",encounter_id) encounter_id,
    encounter_type,
    encounter_datetime,
    encounter_location,
    date_entered,
    user_entered,
    encounter_provider,
    diagnosis_order,
    diagnosis
from temp_diagnoses;
