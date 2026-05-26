CREATE TABLE all_checkins (
    emr_id                   VARCHAR(50),
    encounter_id             INT,
    encounter_datetime       DATETIME,
    encounter_location       VARCHAR(255),
    datetime_entered         DATETIME,
    user_entered             VARCHAR(255),
    encounter_provider       VARCHAR(255),
    reason_of_visit          VARCHAR(255),
    referred_or_escorted     VARCHAR(255),
    referred_by              VARCHAR(255),
    escorting_person_name    TEXT,
    escorting_person_phone   Text
);
