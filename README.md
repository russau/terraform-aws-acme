terraform workspace list | grep -q ${DEST_REGION} || terraform workspace new ${DEST_REGION}


terraform workspace select ${DEST_REGION}
terraform init
terraform plan -var "region=${DEST_REGION}"
terraform apply -var "region=${DEST_REGION}" --auto-approve




terraform destroy -var "region=${DEST_REGION}" --auto-approve
