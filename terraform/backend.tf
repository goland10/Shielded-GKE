terraform {
  backend "gcs" {
    #project = "terraform-shared-data"
    bucket = "backends-all-projects"
  }
}
#t init -reconfigure -backend-config "prefix=dev-01/internalVPC"
#t init -reconfigure -backend-config "prefix=dev-01/app"
#t init -reconfigure -backend-config "prefix=dev-01/externalVPC"
