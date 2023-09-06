Create a workspace for the region

```
terraform workspace list | grep -q ${DEST_REGION} || terraform workspace new ${DEST_REGION}
```

Switch to the workspace, init, plan and apply

```
terraform workspace select ${DEST_REGION}
terraform init
terraform plan -var "region=${DEST_REGION}"
terraform apply -var "region=${DEST_REGION}" --auto-approve
```

Destroy the stack

```
terraform destroy -var "region=${DEST_REGION}" --auto-approve
```