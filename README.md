# bansila-dashboard-mvp

# Bansi.la Executive Analytics Environment (MVP Infrastructure)

## 1. Business & Architectural Objective
This repository contains the containerized Infrastructure-as-Code (IaC) for the Bansi.la operational dashboard. By migrating to a Dockerized microservices architecture, we have eliminated local-machine dependencies, established strict version control for our analytical logic, and created a secure, reproducible environment for executive reporting and customer success monitoring.

## 2. System Architecture
This deployment orchestrates the following decoupled containers:
* **Analytics Engine:** Jupyter/Python environment for ad-hoc telemetry and subscription deep-dives.
* **Storage Layer:** Localized PostgreSQL/MySQL container replicating our production data warehouse schema.
* **BI Interface:** Metabase application layer for persistent dashboarding and data drill-downs.

## 3. Prerequisites
To deploy this environment, the host machine must have the following installed:
* **Docker Engine & Docker Compose** (Ensure Docker Desktop is running).
* **Git** (For version control access).

## 4. Secure Data Provisioning (Mandatory)
*Security Note: To adhere to strict data governance protocols, raw production data and PII are strictly excluded from this Git repository.*

Before booting the system, you must securely acquire and mount the production data dump:
1. Obtain the latest `full_bansi_export.sql` file via our secure internal transfer protocol.
2. Rename this file to exactly **`01_full_bansi_export.sql`**.
3. Place this file directly into the local `/data-warehouse-init` directory within this repository. 
*(Note: The `02_post_deploy_transformations.sql` script is already present in this folder to handle post-ingestion ETL).*

## 5. Deployment Instructions
Once the data file is provisioned, execute the following command from the root directory:

`docker-compose up -d`

*Architecture Note: The database container utilizes alphanumeric sequencing during its initialization. It will first execute `01_full_bansi_export.sql` to build the raw tables and ingest the data. Immediately after, it will execute `02_post_deploy_transformations.sql` to automatically materialize necessary BI views (e.g., `vw_renewal_pipeline`) and aggregate tables (e.g., `summary_daily_active`). **No manual SQL execution is required.***

## 6. Access Endpoints
Once the containers have stabilized (approx. 2-5 minutes depending on the data size):
* **Metabase UI:** `http://localhost:3000` 