# AWS Bastion Host

Provision a bastion host in AWS.

Working during business hours.

## Provision Terraform Backend

```
./provision_terraform_backend.py --project devbox --region us-west-2
```

## Run Terraform

```
terraform init -backend-config=tfvars/dev.tfvars
terraform plan -var-file=tfvars/dev.tfvars
terraform apply -var-file=tfvars/dev.tfvars
```
