# Ruby on Rails Application Deployment with Kubernetes and ArgoCD

This repository contains the necessary configuration files to deploy a Ruby on Rails application (OpenFlights) on Kubernetes using GitOps principles with ArgoCD. **Note: The application is not currently deployed and requires additional setup steps.**

## Project Structure

```
.
├── argocd/                         # ArgoCD configuration files
│   ├── application.yaml            # Application definition for ArgoCD
│   ├── argocd-cm.yaml              # ArgoCD ConfigMap
│   ├── argocd-rbac-cm.yaml         # RBAC configuration for ArgoCD
│   └── repo-credentials.yaml       # Git repository configuration (template)
├── DockerFiles/                    # Dockerfile for containerizing the application
├── K8s/                            # Kubernetes manifests
│   └── ruby-app/                   # Helm chart for the Ruby application
│       ├── output.yaml             # Single YAML output generated by Helm template
│       └── templates/              # Helm templates
└── tekton/                         # Tekton CI pipeline configuration
    ├── pipeline.yaml               # Pipeline definition for building and pushing images
    ├── tasks.yaml                  # Custom tasks for git clone and image building
    └── pipelinerun.yaml            # PipelineRun template for execution
```

## Application Components

The deployment includes the following components:

1. **Ruby on Rails Application**: A containerized version of the OpenFlights application
2. **PostgreSQL Database**: A stateful database for the application
3. **Nginx Ingress Controller**: For routing external traffic to the application
4. **Tekton CI Pipeline**: For continuous integration (building and pushing Docker images)
5. **ArgoCD**: For continuous deployment following GitOps principles

## Prerequisites

- Kubernetes cluster (e.g., minikube, EKS)
- kubectl configured to communicate with your cluster
- Helm (v3+)
- Git (for version control)
- Docker Hub account (for container images)

## Installation Steps

### 1. Setting up the Kubernetes Cluster

If using minikube:

```bash
minikube start
minikube addons enable ingress
```

### 2. Deploying ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD components to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 3. Configure ArgoCD

```bash
# Before applying repo-credentials.yaml, replace placeholder credentials
# DO NOT COMMIT ACTUAL CREDENTIALS to Git
# Make sure to generate a GitHub Personal Access Token (PAT) with appropriate permissions
kubectl apply -f argocd/

# This will apply all configuration files in the argocd directory
```

### 4. Access ArgoCD Dashboard

```bash
# Port forward to ArgoCD service
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open your browser and go to https://localhost:8080

Login credentials:
- Username: admin
- Password: Get the initial password by running:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

### 5. Setting up Tekton Pipeline

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# update docker secret in dockerhub-secret.yaml file (Use your credentials as the value of the data field.)

# Install dashboard
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release-full.yaml 
  

# Apply resources under tekton folder
kubectl apply -f tekton/

```

### 6. Run the Tekton Pipeline

```bash
# Access the Tekton Dashboard:

kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
```
### 7. Run the Pipeline:
```
kubectl create -f tekton/pipelinerun.yaml
```
Alternatively, just run it from below steps:
- In the Tekton Dashboard:
- Go to "PipelineRuns"
- Click "Create"
- Select your pipeline "open-flights-pipeline"
- Fill in the parameters (git URL and image name)
- Click "Create"



### 7. Accessing the Application

If using minikube with Docker driver on Windows:

```bash
# Start a tunnel to the ingress controller
minikube service ingress-nginx-controller -n ingress-nginx
```

This will create a tunnel and provide a URL like http://127.0.0.1:xxxxx

Access the application at:
- http://localhost:xxxxx (if your ingress host is set to "localhost")
- or http://openflights.local:xxxxx (if using a custom hostname, remember to add it to your hosts file)

## Working with ArgoCD

### Manual Sync

If you need to manually sync your application:
1. Open the ArgoCD UI
2. Select your application
3. Click the "SYNC" button
4. Select resources to sync
5. Click "SYNCHRONIZE"

### Auto-Sync Configuration

The application is configured with auto-sync enabled. It will:
- Automatically detect changes in the Git repository
- Apply changes to the cluster
- Prune resources that are no longer in the Git repo
- Self-heal if manual changes are made to cluster resources

### Testing the GitOps Workflow

1. Make changes to your Kubernetes manifests (or regenerate output.yaml with Helm)
2. Commit and push changes to your Git repository
3. ArgoCD will detect changes and automatically apply them to your cluster

## CI/CD Pipeline with Tekton

The project implements a complete CI/CD pipeline:

1. **Continuous Integration (Tekton)**:
   - Automatically clones the source code repository
   - Builds a Docker image with the application
   - Pushes the image to Docker Hub

2. **Continuous Deployment (ArgoCD)**:
   - Monitors the Git repository for changes
   - Automatically applies updated Kubernetes manifests
   - Ensures the deployed state matches the desired state in Git

You can automate the pipeline further by:
- Adding Tekton Triggers to start pipelines based on GitHub webhooks
- Implementing a GitOps workflow where image tags are updated in the manifest repository
- Setting up notifications for successful/failed builds and deployments

## Troubleshooting

### ArgoCD Not Syncing

If auto-sync isn't working:
1. Check if the correct branch is specified in `targetRevision` (should match your main branch name)
2. Verify repository connectivity in ArgoCD UI under Settings > Repositories
3. Check ArgoCD logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
   ```
4. Force a refresh:
   ```bash
   kubectl patch application ruby-app -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"main"}}}'
   ```
5. Make sure you have the correct PAT token (GitHub token) generated and replaced with the password field in repo-credentials.yaml file

### Tekton Pipeline Failures

If your Tekton pipeline fails:
1. Check the PipelineRun status:
   ```bash
   kubectl get pipelinerun
   ```
2. Examine the TaskRun logs:
   ```bash
   kubectl get taskrun
   kubectl logs taskrun/[taskrun-name]
   ```
3. Ensure Docker credentials are correctly configured:
   ```bash
   kubectl get secret docker-credentials -o yaml
   ```
4. Verify workspace PVC is bound:
   ```bash
   kubectl get pvc tekton-workspace-pvc
   ```

### Application Not Accessible

If you cannot access the application:
1. Check if all pods are running:
   ```bash
   kubectl get pods
   ```
2. Verify the ingress configuration:
   ```bash
   kubectl get ingress
   kubectl describe ingress ruby-app
   ```
3. For minikube, ensure the tunnel is running
4. If using a custom hostname, verify it's added to your hosts file

### Rails Host Validation Error

If you see a "Blocked host" error from Rails:
1. Modify your ingress to use "localhost" as the host
2. Or update your Rails application to accept the custom hostname

### Debugging Deployment Issues

If your application is not deploying correctly:
1. Check the status of all resources:
   ```bash
   kubectl get all
   ```
2. Review application logs:
   ```bash
   kubectl logs deployment/ruby-app
   ```
3. Check if services are properly connecting:
   ```bash
   kubectl describe svc ruby-app
   ```
4. Verify database connectivity from within the application pod:
   ```bash
   kubectl exec -it deployment/ruby-app -- curl postgresql.default.svc.cluster.local:5432
   ```

## GitOps Workflow Implementation

This project follows GitOps principles for deployment:

1. The Git repository is the single source of truth for the application infrastructure
2. All changes to the infrastructure are made through Git commits
3. ArgoCD continuously monitors the Git repository for changes
4. When changes are detected, ArgoCD automatically applies them to the cluster

To make changes to your deployment:
1. Modify the Kubernetes manifests or regenerate the output.yaml using Helm
2. Commit and push changes to your Git repository
3. ArgoCD will detect and apply the changes automatically (if auto-sync is enabled)
   
## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Ruby on Rails Documentation](https://guides.rubyonrails.org/)
- [Tekton Pipelines Documentation](https://tekton.dev/docs/)