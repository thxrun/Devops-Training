# Exercise 23 – Build CI/CD Pipeline

## Objective

Create an automated CI/CD pipeline using GitHub Actions, Docker, Amazon ECR, GitOps, and ArgoCD.

## Pipeline Flow

GitHub Push
↓
Unit Tests
↓
Docker Build
↓
ECR Push
↓
GitOps Update
↓
ArgoCD Deploy

---

## Prerequisites

* GitHub Account
* AWS Account
* Docker Desktop
* AWS CLI
* Minikube
* kubectl
* ArgoCD
* Python 3.13

---

## Step 1 – Create Application

Created a simple Flask application.

Files:

* app.py
* requirements.txt
* test_app.py

---

## Step 2 – Unit Testing

Installed dependencies:

```bash
pip install -r requirements.txt
```

Executed tests:

```bash
python -m pytest
```

Result:

```text
1 passed
```

---

## Step 3 – Docker Build

Created Dockerfile.

Build image:

```bash
docker build -t cicd-demo .
```

Run container:

```bash
docker run -p 5000:5000 cicd-demo
```

Verified application using:

```text
http://localhost:5000
```

---

## Step 4 – GitHub Repository

Created repository:

```text
cicd-pipeline
```

Pushed source code:

```bash
git add .
git commit -m "Initial commit"
git push
```

---

## Step 5 – GitHub Actions Pipeline

Created workflow:

```text
.github/workflows/cicd.yml
```

Pipeline stages:

* Unit Tests
* Docker Build

Verified successful workflow execution from GitHub Actions.

---

## Step 6 – Amazon ECR Repository

Created repository:

```bash
aws ecr create-repository --repository-name cicd-demo
```

Repository URI:

```text
260969591589.dkr.ecr.us-east-1.amazonaws.com/cicd-demo
```

---

## Step 7 – Push Docker Image to ECR

Login:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 260969591589.dkr.ecr.us-east-1.amazonaws.com
```

Tag image:

```bash
docker tag cicd-demo:latest 260969591589.dkr.ecr.us-east-1.amazonaws.com/cicd-demo:latest
```

Push image:

```bash
docker push 260969591589.dkr.ecr.us-east-1.amazonaws.com/cicd-demo:latest
```

Verified image availability in ECR.

---

## Step 8 – GitOps Update

Created Kubernetes deployment manifest:

```text
deployment.yaml
```

Deployment references the Docker image stored in Amazon ECR.

---

## Step 9 – ArgoCD Deployment

Installed ArgoCD on Minikube.

Created ArgoCD application:

```text
Application Name: cicd-demo
Repository: https://github.com/vikas606-11/cicd-pipeline.git
Path: .
```

Application Status:

```text
Healthy
Synced
```

---

## Failure Scenario 1 – Test Failure

Modified unit test:

```python
assert response.status_code == 500
```

Result:

```text
test ❌
docker-build skipped
```

Pipeline stopped at test stage.

---

## Failure Scenario 2 – Security Violation

Added security validation to the workflow.

Introduced a hardcoded password:

```python
PASSWORD="admin123"
```

Result:

```text
security-check ❌
docker-build skipped
```

Pipeline stopped due to security violation.

---

## Outcome

Successfully implemented a CI/CD pipeline that:

* Runs automated tests
* Builds Docker images
* Pushes images to Amazon ECR
* Uses GitOps deployment manifests
* Deploys through ArgoCD
* Stops execution when tests fail
* Stops execution when security violations are detected

## Screenshots

1. Successful GitHub Actions Workflow
2. Docker Build Success
3. Amazon ECR Repository
4. Docker Image Push to ECR
5. ArgoCD Healthy & Synced Status
6. Test Failure Workflow
7. Security Violation Workflow
