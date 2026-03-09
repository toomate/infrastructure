#!/bin/bash

ENDPOINT=http://localhost:4566
REGION=us-east-1

echo "Criando VPC..."
VPC_ID=$(aws --endpoint-url=$ENDPOINT ec2 create-vpc \
  --cidr-block 10.0.0.0/23 \
  --query 'Vpc.VpcId' --output text)

echo "Criando subnets..."
SUBNET_PUBLIC_1=$(aws --endpoint-url=$ENDPOINT ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/25 \
  --availability-zone us-east-1a \
  --query 'Subnet.SubnetId' --output text)

SUBNET_PUBLIC_2=$(aws --endpoint-url=$ENDPOINT ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.128/25 \
  --availability-zone us-east-1b \
  --query 'Subnet.SubnetId' --output text)

SUBNET_PRIVATE_1=$(aws --endpoint-url=$ENDPOINT ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.0.0/25 \
  --availability-zone us-east-1a \
  --query 'Subnet.SubnetId' --output text)

SUBNET_PRIVATE_2=$(aws --endpoint-url=$ENDPOINT ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.0.128/25 \
  --availability-zone us-east-1b \
  --query 'Subnet.SubnetId' --output text)

echo "Criando Internet Gateway..."
IGW_ID=$(aws --endpoint-url=$ENDPOINT ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws --endpoint-url=$ENDPOINT ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

echo "Criando Route Table..."
RT_ID=$(aws --endpoint-url=$ENDPOINT ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)

aws --endpoint-url=$ENDPOINT ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws --endpoint-url=$ENDPOINT ec2 associate-route-table \
  --subnet-id $SUBNET_PUBLIC_1 \
  --route-table-id $RT_ID

aws --endpoint-url=$ENDPOINT ec2 associate-route-table \
  --subnet-id $SUBNET_PUBLIC_2 \
  --route-table-id $RT_ID

echo "Criando Security Groups..."

SG_PUBLIC=$(aws --endpoint-url=$ENDPOINT ec2 create-security-group \
  --group-name sg_publico \
  --description "public sg" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws --endpoint-url=$ENDPOINT ec2 authorize-security-group-ingress \
  --group-id $SG_PUBLIC \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws --endpoint-url=$ENDPOINT ec2 authorize-security-group-ingress \
  --group-id $SG_PUBLIC \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0


SG_ALB=$(aws --endpoint-url=$ENDPOINT ec2 create-security-group \
  --group-name sg_alb \
  --description "alb sg" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws --endpoint-url=$ENDPOINT ec2 authorize-security-group-ingress \
  --group-id $SG_ALB \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0


echo "Criando S3 buckets..."

aws --endpoint-url=$ENDPOINT s3api create-bucket --bucket toomate-raw-2026
aws --endpoint-url=$ENDPOINT s3api create-bucket --bucket toomate-trusted-2026
aws --endpoint-url=$ENDPOINT s3api create-bucket --bucket toomate-client-2026


echo "Criando Load Balancer..."

LB_ARN=$(aws --endpoint-url=$ENDPOINT elbv2 create-load-balancer \
  --name alb-toomate \
  --subnets $SUBNET_PUBLIC_1 $SUBNET_PUBLIC_2 \
  --security-groups $SG_ALB \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "Criando Target Group..."

TG_ARN=$(aws --endpoint-url=$ENDPOINT elbv2 create-target-group \
  --name tg-toomate \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Criando Listener..."

aws --endpoint-url=$ENDPOINT elbv2 create-listener \
  --load-balancer-arn $LB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN


echo "Infraestrutura criada no LocalStack!"