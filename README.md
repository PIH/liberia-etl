# liberia-etl
ETL repository for Partners In Health Liberia

# Docker image

`partnersinhealth/liberia-etl` layers this project's `datasources/`, `jobs/` and `application-docker.yml`
(as its `application.yml`) on the [PETL](https://github.com/PIH/petl) base image,
`partnersinhealth/petl`. CI builds and pushes it (`Dockerfile`, build context `target/docker/`,
populated by `mvn package`) on every push and on every release, tagged `latest` and the version.
It builds on `partnersinhealth/petl:latest` (the `Dockerfile`'s `PETL_BASE_IMAGE` default). To build it locally: `./build-runtime-docker-image.sh`, which
layers on a locally built `partnersinhealth/petl:local`.

It runs as [openmrs-contrib-distro-tools](https://github.com/PIH/openmrs-contrib-distro-tools)'
`petl` service (see its `docs/services.md`), e.g. for the kouka CI server:

    PETL_IMAGE_NAME=partnersinhealth/liberia-etl
    PETL_FULL_REFRESH_JOBS="create-partitions.yml refresh-ci-warehouse.yml"
    PETL_SQLSERVER_DATABASE=openmrs_kouka

`application-docker.yml` maps the `jjd` OpenMRS datasource and the `warehouse` SQL Server
datasource onto distro-tools' `PETL_MYSQL_*` and `PETL_SQLSERVER_*` variables. The other sites'
datasources aren't set; set one by its Spring environment-variable name where it's needed (e.g.
`DATASOURCES_OPENMRS_<SITE>_HOST`).
