
## Deployment instructions
1. Setup your configuration in [backend.tf](./terraform/backend.tf) and in the desired tfvars file:
2. Nevigate to the `terrform` directory
2. `ENV_NAME=dev-01`
2. Run the following commands on each of the phases in this order:
    1. internalVPC
    2. app
    3. externalVPC
2. `PHASE=internalVPC && cd ./$PHASE`

3. `terraform init -reconfigure -backend-config "prefix=${ENV_NAME}/${PHASE}"`

4. `terraform validate`
5. `terraform plan -var-file ./envs/${ENV_NAME}.tfvars -out $ENV_NAME`
6. `terraform apply -auto-approve $ENV_NAME`
6. `cd ..`
7. `terraform destroy -var-file ./envs/${ENV_NAME}.tfvars -auto-approve`

```bash
for PHASE in internalVPC app externalVPC ; 
do
  terraform -chdir=./$PHASE init -reconfigure -backend-config "prefix=${ENV_NAME}/${PHASE}";
  terraform -chdir=./$PHASE validate;  
  terraform -chdir=./$PHASE plan -var-file ./envs/${ENV_NAME}.tfvars -out $ENV_NAME;  
  terraform -chdir=./$PHASE apply -auto-approve $ENV_NAME;
done
```

## Troubleshot

1. Connect to the cluster to run `kubectl/helm` commands

    `gcloud container fleet memberships get-credentials $ENV_NAME`

2. ssh to one of the worker nodes to invastigate internal connectivty

    `gcloud compute ssh NODE_NAME --zone=ZONE --tunnel-through-iap`
    
    or click on the `ssh` button in the VM instances console
    