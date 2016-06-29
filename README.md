# Project-Atlas

Running the Terraform script (Windows & Mac):

1. Download repository locally
2. Change to the root directory of the repository
3. Unzip the rancher_config folder to the root directory of the repository

On Windows (64-bit only):

4. To test the environment, run: ./windows/terraform plan
5. To build the environment, run: ./windows/terraform apply
6. To destroy the environment, run: ./windows/terraform destroy

On Mac:

4. To test the environment, run: ./mac/terraform plan
5. To build the environment, run: ./mac/terraform apply
6. To destroy the environment, run: ./mac/terraform destroy

Once the environment is up, connect to the Rancher Server URL that is provided by the Rancher output when the apply completes.

Login details for the Rancher Server

U: localadmin / P: RanchPa$$
