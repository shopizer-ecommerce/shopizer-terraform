# shopizer-terraform
Shopizer infrastructure as code with Hashicorp Terraform

Ubuntu image 

- sudo curl -O https://releases.hashicorp.com/terraform/0.11.5/terraform_0.11.5_linux_amd64.zip
- sudo apt-get install unzip
- sudo mkdir /bin/terraform
- sudo unzip terraform_0.11.5_linux_amd64.zip -d /usr/local/bin/

Root 

    main.tf 
    variables.tf 
    outputs.tf 
        Networking 
            main.tf 
            variables.tf 
            outputs.tf 
        Compute 
            main.tf 
            variables.tf 
            outputs.tf 
            userdata.tpl 
        Storage 
            main.tf 
            variables.tf 
            outputs.tf

Create publick key

ssh-keygen

/home/ubuntu/.ssh/id_rsa.pub

- terraform init
- terraform plan
- terraform apply
- terraform destroy
