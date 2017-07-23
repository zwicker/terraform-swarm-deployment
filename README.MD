# FULL DEPLOY - Directions
Install Terraform then enter AWS details into "variables.tf"

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

# Deploying services to Docker Swarm

## Main Deployment of the full stack

In a CICD environment this command would be 

### Deploy full service to swarm using compose file
```
docker stack deploy --compose-file=docker-compose.yml prod
```

## Individual deployment services
Deploy the Go App Service
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