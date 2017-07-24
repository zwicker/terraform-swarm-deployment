# Docker Swarm to AWS using Terraform

This repo sets out a deployment of docker swarm on AWS. As a slave gets created it will automatically be added as a worker service in the docker swarm group. This repo could be easily modified to accomodate Kubernetes. 

This repo also comes with an example stack which uses internal swarm components to allow haproxy routing of url redirects to a go docker container and a node docker container.

## Prerequisites

* Terraform
* AWS access key and secret key
* AWS pem file

## FULL DEPLOY - Directions
Install Terraform then enter AWS details into "variables.tf" this can be modified to use environment variables.

Put the AWS private key file in this directory and set the relevant AWS configuration variables in variables.tf

This terraform command will create a new terraform plan and build the following in AWS leveraging docker containers on EC2 instances.
* VPC
* Subnet
* Security Group
* Docker Swarm Master
* 2 Docker Swarm Servers

```
cd devops/

terraform plan
terraform apply

Follow the output prompt after servers have deployed
```

## Deploying services to Docker Swarm

### Main Deployment of the full stack

In a CICD environment this command would be used to manage creation of builds (any that use ssh bash scripting).

#### Deploy full service to swarm using compose file
```
docker stack deploy --compose-file=docker-compose.yml prod
```

## Individual deployment services
Deploy the Go App Service, the services of the swarm are managed at the swarm master.

```
docker service create -p 8080:8080 --name go zwicker/go-app
```

Deploy the Node app service

```
docker service create -p 3000:3000 --name node zwicker/node-app
```

Deploy the load balancer

```
docker service create -p 80:80 --name haproxy zwicker/haproxy_v1
```

## Notes

After this build has deployed, due to the default instance being t2.micro it may take an extra 5-10 minutes after it is reported as completed. This deployment is setup to show the creation and adoption of swarm manager and it's workers.

Slaves can be increased by using the count in 'deploy.tf', once the count is increased terraform plan and apply can be run to add more instances.

It is recommended to deploy the extended Elastic Load Balancers to this, these can be added easily even after the infrastructure is deployed.

## Extensions

This repo can be easily extended to accomodate Elastic Load Balancers (ELB) and RDS instances as part of the build.