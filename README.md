# 3-Tier-Web-Application-with-Auto-Scaling-in-AWS


---

### 3-Tier Web Application with Auto-Scaling in AWS

**Technologies Used**: AWS (VPC, EC2, RDS, ALB, ASG), Terraform, MySQL, NGINX, Flask, Python

**Project Overview**:
Designed and deployed a highly scalable 3-tier web application on AWS using Terraform. The application includes a **web tier**, **application tier**, and **database tier** with seamless auto-scaling capabilities and robust load balancing for high availability and fault tolerance. The infrastructure was fully automated using **Terraform**, ensuring a repeatable and efficient deployment process.

**Key Responsibilities**:

* **Infrastructure Setup**:

  * Designed a **custom VPC** with **public** and **private subnets** across multiple **availability zones** for high availability.
  * Configured **security groups** to ensure secure communication between web, application, and database layers.
  * Deployed **RDS MySQL database** instance within private subnets for secure data storage, ensuring **high availability** and **fault tolerance**.

* **Web Tier Configuration**:

  * Provisioned **EC2 instances** in **auto-scaling groups** (ASGs) with **NGINX** acting as a reverse proxy, directing traffic to the **internal app tier**.
  * Set up **Application Load Balancer (ALB)** for the web tier to distribute incoming traffic across EC2 instances, ensuring optimal resource utilization and minimal latency.

* **App Tier Configuration**:

  * Developed and deployed a **Flask**-based web application on EC2 instances, enabling API responses via **HTTP** on port 5000.
  * Configured an **internal ALB** for routing traffic between the **web tier** and **app tier** for secure, internal communication.
  * Implemented **auto-scaling** policies to dynamically scale EC2 instances in response to varying traffic loads.

* **Database Tier**:

  * Configured **RDS MySQL** instance with proper subnet group and security group settings for internal access only by the app tier.
  * Ensured secure database connectivity between EC2 app instances and RDS using **IAM roles** and **security groups**.

* **Automation with Terraform**:

  * Utilized **Terraform modules** to automate the provisioning of VPC, subnets, security groups, and auto-scaling resources.
  * Implemented **CI/CD**-like automation for repeatable infrastructure provisioning, reducing manual errors and deployment time.

* **Performance and Monitoring**:

  * Configured **health checks** and **auto-scaling policies** for both web and app tiers to automatically adjust resources based on real-time traffic.
  * Integrated **CloudWatch Logs** for monitoring the application performance and **CloudWatch Alarms** for resource utilization.

**Results**:

* Achieved **high availability** and **scalability**, ensuring the application can handle increased traffic during peak periods.
* Reduced infrastructure management overhead by automating the deployment using Terraform.
* Improved performance and response times with load balancing and auto-scaling, optimizing cost by scaling resources dynamically.

---

This description highlights your ability to design, deploy, and automate scalable architectures using **AWS** services and **Terraform**, which is an important skill for cloud engineers or DevOps roles.
