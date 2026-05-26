CREATE TABLE all_visits (
    patient_id           VARCHAR(50),
    emr_id               VARCHAR(50),
    visit_id             VARCHAR(50),
    visit_date_started   DATETIME,
    visit_date_stopped   DATETIME,
    datetime_entered     DATETIME,
    user_entered         VARCHAR(255),
    visit_type           VARCHAR(255),
    visit_location       VARCHAR(255),
    index_asc            INT,
    index_desc           INT
);
