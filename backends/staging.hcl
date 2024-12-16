bucket         = "devbox-terraform-state"
key            = "staging/bastion/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "terraform-state-lock"
encrypt        = true 