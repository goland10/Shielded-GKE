## Create a bucket in a shared project to store all backends

1. Create the project and link it to a billing account
    ```bash
    PROJECT_ID=terraform-shared-data
    gcloud projects create $PROJECT_ID
    BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(name)"    --filter="open=true")
    gcloud billing projects link $PROJECT_ID --billing-account  $BILLING_ACCOUNT_ID
    ```
2. Create the bucket and enable versioning
    ```bash
    BUCKET_NAME=backends-all-projects
    gcloud storage buckets create gs://$BUCKET_NAME \
    --location=europe-west4 \
    --project $PROJECT_ID \
    --uniform-bucket-level-access 

    gcloud storage buckets update gs://$BUCKET_NAME --versioning --project  $PROJECT_ID
    ```

## Create a project for the internal VPC (GKE)

1.  Create the project and link it to a billing account
    ```bash
    PROJECT_ID=internal-project-mission
    gcloud projects create $PROJECT_ID  --name="Internal Project"
    BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(name)" 
    --filter="open=true")
    gcloud billing projects link $PROJECT_ID --billing-account $BILLING_ACCOUNT_ID
    ```    

2. Enable the required services
    ```bash
    gcloud services enable \
        compute.googleapis.com \
        container.googleapis.com \
        gkehub.googleapis.com \
        connectgateway.googleapis.com
    ```

## Create a project for the external VPC (Cloud Armor + external ALB)

1.  Create the project and link it to a billing account
    ```bash
    PROJECT_ID=external-project-mission
    gcloud projects create $PROJECT_ID --name="External Project"
    BILLING_ACCOUNT_ID=$(gcloud billing accounts list --format="value(name)"    --filter="open=true")
    gcloud billing projects link $PROJECT_ID --billing-account $BILLING_ACCOUNT_ID
    ```
2. Enable the required services
    ```bash
    gcloud services enable --project $PROJECT_ID \
        compute.googleapis.com \
        certificatemanager.googleapis.com \
        networkconnectivity.googleapis.com
    ```
    