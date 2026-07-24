AWS VPC Lattice Client Workshop: Hands-on Lab & Facilitation Guide

This guide is designed to help you prepare, provision, and successfully run the hands-on lab portion of your AWS VPC Lattice Client Workshop by Epitechnic. It translates the abstract concepts from Joseph's presentation slides into an interactive, multi-VPC learning experience.

### Important Note
To save time, the infrastructure needed for this to work has been created in this repo.

1. Configure you machine to connect to AWS account using the AWSCLi
2. To deploy to the same AWS Account change into Same-Account folder and run terraform plan and apply
3. To deploy to separate accounts, Configure the relevant account and Change to either Account-1 or Account-2 and deploy. Account-1 will be client account and Account-2 will be the backend account



1. Lab Architecture Overview

To demonstrate the real-world power of AWS VPC Lattice (handling IP overlaps, cross-VPC communication, multi-compute integration, and zero-trust authentication), we recommend a Dual-VPC, Multi-Compute Architecture within a single AWS account (which can scale to multi-account using AWS Resource Access Manager if desired).

                      +------------------------------------------+
                      |         AWS VPC LATTICE SERVICE NETWORK   |
                      |                                          |
                      |   +----------------------------------+   |
                      |   |          Lattice Service         |   |
                      |   |   (DNS: my-app.on.aws.lattice)   |   |
                      |   +----------------------------------+   |
                      |       /                          \       |
                      +------/----------------------------\------+
                            /                              \
       [ VPC A: Client / Consumer ]             [ VPC B: Backend / Provider ]
       CIDR: $10.0.0.0/16$                       CIDR: $10.0.0.0/16$ (OVERLAPPING!)
       +----------------------------+            +----------------------------+
       | Private Subnet             |            | Private Subnets            |
       |                            |            |                            |
       |  +----------------------+  |            |  +----------------------+  |
       |  |  Client Instance     |  |            |  |  Target Group 1      |  |
       |  |  (EC2 / Cloud9)      |  |            |  |  (EC2 Auto Scaling)  |  |
       |  +----------------------+  |            |  +----------------------+  |
       +----------------------------+            +----------------------------+
                    |                                          |
                    | (Queries Lattice Service)                | (Serves Traffic)
                    v                                          v
       VPC Association to Service Network         VPC Association / Targets Registered



Key Architectural Highlights to Emphasize

Overlapping IP Addresses: Both VPCs use the exact same CIDR block ($10.0.0.0/16$). Under normal VPC peering or Transit Gateway routing, this would cause an immediate routing failure. VPC Lattice abstracts this completely.

Compute-Agnostic Targets:

Target Group 1 (Primary): EC2 Instance Web Server running a simple HTTP microservice.

Target Group 2 (Canary): AWS Lambda function serving a JSON response representing "V2".

No Gateways / Proxies: Point out to attendees that there is no NAT Gateway, Internet Gateway, Transit Gateway, or ALB sitting between VPC A and VPC B.

2. Infrastructure Provisioning (Pre-Workshop Setup)

To ensure the workshop runs smoothly, you should pre-provision the underlying network and compute resources so attendees can focus purely on configuring VPC Lattice.

We recommend deploying the infrastructure via AWS CloudFormation or Terraform (main.tf). Below is the resource breakdown included in automated templates:

Resources Pre-Provisioned

VPC A (Client/Consumer):

VPC ($10.0.0.0/16$), 2 Private Subnets, Route Tables.

AWS Systems Manager (SSM) VPC Endpoints for browser-based terminal access without internet access or SSH keys.

1 EC2 Instance (Amazon Linux 3) acting as the client with an attached IAM Role enabling AmazonSSMManagedInstanceCore.

Security Group allowing outbound egress and inbound traffic on Ports $80$ and $443$ from $10.0.0.0/16$ for Lattice Managed ENIs.

VPC B (Backend/Provider):

VPC ($10.0.0.0/16$), 2 Private Subnets, Route Tables.

1 EC2 Instance running a lightweight web server on Port $80$, returning "Hello from App V1".

Security Group allowing inbound HTTP traffic on Port $80$ from the VPC Lattice link-local prefix block $169.254.171.0/24$.

Serverless Component:

1 AWS Lambda function returning a JSON body: {"message": "Hello from App V2 (Canary)"}.

3. Step-by-Step Lab Execution & Facilitation

Lab 1: Initialize the Service Network (Setup)

Goal: Create the secure boundary and associate the isolated VPC networks.

Attendee Actions:

Navigate to VPC Console -> VPC Lattice -> Service Networks and click Create service network.

Name it Engineering-Service-Network.

Under VPC Associations, associate both VPC-A and VPC-B. Select the appropriate security groups (lattice-workshop-client-sg and lattice-workshop-backend-sg).

Facilitator's Insight:

Explain to attendees: "When we associate these VPCs, AWS dynamically provisions Lattice VPC endpoints in your subnets. The security group you select attaches directly to these managed ENIs. Client requests route directly to these managed endpoints using link-local addressing."

Lab 2: Route Traffic & Map Services (Route)

Goal: Define the logical Service, bind it to targets, and make the first microservice calls.

Attendee Actions:

Create Target Groups:

TG-EC2-V1: Target type: Instances, Port $80$, Protocol: HTTP, register the VPC B instance.

TG-Lambda-V2: Target type: Serverless, select the V2 Lambda function.

Create the Lattice Service:

Go to VPC Lattice -> Services -> Create service. Name it order-service.

Set the Listener to HTTP on Port 80.

Configure the Default Route Action to forward $100\%$ of traffic to TG-EC2-V1.

Associate Service with Service Network:

Link order-service to the Engineering-Service-Network.

Verify Connectivity:

Connect via SSM into the Client EC2 instance in VPC-A.

Run a basic curl command:

curl http://<AUTO_GENERATED_LATTICE_DNS_NAME>



Confirm it successfully resolves and returns "Hello from App V1".

Lab 3: Secure the API (Secure)

Goal: Transition from open connectivity to a Zero-Trust architecture using IAM policies and AWS SigV4.

Attendee Actions:

Enable Authentication:

Select order-service -> Access tab -> Edit.

Switch Auth type from NONE to AWS_IAM.

Define Auth Policy:

Apply a strict Auth Policy:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "vpc-lattice-svc:Invoke",
      "Resource": "*"
    }
  ]
}



Test Blocked Access:

Run curl -i http://<LATTICE_DNS_NAME> again from the client instance. Confirm it fails with an HTTP 403 Forbidden error.

Sign Requests (SigV4):

Execute an authenticated call with native curl SigV4 signing:

curl --aws-sigv4 "aws:amz:us-east-1:vpc-lattice-svc" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     http://<LATTICE_DNS_NAME>



Lab 4: Canary Deployment / Traffic Splitting (Split)

Goal: Implement a progressive deployment by shifting target group weights.

Attendee Actions:

Select order-service -> Listeners -> HTTP listener -> Edit rules.

Define weights:

TG-EC2-V1: Weight $80$

TG-Lambda-V2: Weight $20$

Validate Canary Splitting:

Execute a loop script from the Client EC2 instance:

for i in {1..20}; do
  curl -s --aws-sigv4 "aws:amz:us-east-1:vpc-lattice-svc" \
       --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
       http://<LATTICE_DNS_NAME>
  echo ""
  sleep 0.3
done



Observe that approximately $80\%$ of responses yield "Hello from App V1" and $20\%$ yield the Lambda JSON response.

4. Troubleshooting Matrix & Security Group Rules

Keep this reference ready for attendees encountering network issues:

|

| Issue | Root Cause | Solution |
| Could not connect to server (Timeout) | Client Association SG (client_sg) lacks Inbound rules. | Edit client_sg to allow Inbound HTTP (80) & HTTPS (443) from $10.0.0.0/16$. |
| Target health check failing in VPC B | Backend SG (backend_sg) blocking Lattice traffic. | Allow Inbound HTTP (80) from 169.254.171.0/24 on backend_sg. |
| HTTP 403 Forbidden on signed calls | IAM policy mismatch or clock drift. | Verify client IAM role has vpc-lattice-svc:Invoke permission and system time is synchronized. |
| DNS Resolution Failure | VPC Association DNS setting disabled. | Check "Enable DNS resolution" in VPC Lattice -> Service Network -> VPC Associations. |

5. Suggested Workshop Timing

| Time Block | Topic / Activity | Format |
| 00:00 - 00:30 | Presentation & Architecture Deep Dive | Slides 1–11 |
| 00:30 - 00:45 | Prerequisites & Sandbox Setup Walkthrough | Slide 2 & Architecture Review |
| 00:45 - 01:15 | Lab 1 & 2: Network Setup & Service Routing | Hands-on execution |
| 01:15 - 01:30 | Mid-Lab Debrief & Link-Local Routing Discussion | Q&A |
| 01:30 - 02:00 | Lab 3: IAM Auth Policies & SigV4 Signing | Hands-on execution |
| 02:00 - 02:25 | Lab 4: Canary Traffic Splitting | Hands-on execution |
| 02:25 - 02:45 | Q&A, Cleanup & Wrap-Up | Slide 13 & Infrastructure teardown |