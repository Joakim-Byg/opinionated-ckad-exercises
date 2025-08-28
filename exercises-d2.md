# Opinionated CKAD: Workshop Exercises & Commands
This document contains the step-by-step instructions, commands, and reflection questions for each lab session. The goal is not just to run the commands, but to understand the output and what is happening in the cluster.

## Prerequisites:

* A working KinD cluster.

* ```kubectl``` configured to point to your KinD cluster.

* A copy of this workshop's application repository.

## Bonus Lab A: Crafting the Perfect Service
**Objective:** To understand how a Service uses labels and selectors to connect to a Deployment's Pods.

**Scenario:** The ```kubectl expose``` command is shortcut, but you will most likely write your own Service manifests. 
Your task is to manually create a ```ClusterIP``` Service that correctly routes traffic to the ```echo-app``` deployment.


1. **Create a Service Manifest:**

   * Create a new file named ```service.yaml```.

   * Write the YAML for a Service from scratch. Pay close attention to the selector field. It must match the labels on the Pods created by your Deployment.
     ```yaml
     apiVersion: v1
     kind: Service
     metadata:
       name: echo-app-service
       namespace: workshop
     spec:
       type: ClusterIP
       # This selector is the crucial link.
       # It must match the labels in your Deployment's pod template.
       selector:
         app: echo-app
       ports:
         - protocol: TCP
           port: 8080        # The port the Service will be available on
           targetPort: 8080  # The port the container is listening on
     ```

2. **Apply the Service Manifest:**
    ```shell
    kubectl apply -f service.yaml
    ```

3. **Verify the Connection:**

    * The most important verification step is to check the Service's "Endpoints". If the selector is correct, Kubernetes 
      will list the IP addresses of your ```echo-app``` Pods here.
      ```shell
      # Describe the service and look for the "Endpoints" section
      kubectl describe service echo-app-service -n workshop
      ```
   
    * If you see valid IP addresses listed, your Service is correctly connected!

4. **Test Access:**

    * Use ```port-forward``` to connect to your new manual service and test it.
      ```shell
      # In a new terminal
      kubectl port-forward svc/echo-app-service 8080:8080 -n workshop
      
      # Test it
      curl http://localhost:8080
      ```

### 🤔 Reflection Questions:

* What would happen if the ```selector``` in ```service.yaml``` did not match the labels on the Pods? What would you 
  see in the Endpoints list?

* A Service can select Pods from different Deployments. Why might this be useful?

## Bonus Lab B: "Exposing Services with Ingress"
The first step is to install one an ingress controller (KinD is not shipped with one). 
For this we pick the NGINX Ingress Controller is very common and easy to set up with a single command:
1. **Install an Ingress Controller:**
    ```shell
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   ```
2. **Create an Ingress Manifest:** Participants would create an ```ingress.yaml``` file to route traffic to their 
   ```echo-app-service```
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: echo-ingress
     namespace: workshop
   spec:
     rules:
       - host: "echo.local"
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: echo-app-service
                   port:
                     number: 8080
   ```
3. **Apply and Test:**  Since ```echo.local``` isn't a real domain, we should use ```curl``` command with a ```--resolve``` 
   flag to simulate DNS:

### 🤔 Reflection Questions:

* How could you use metrics to decide when to scale your application?

* You see an error in the logs. How would you use a trace to find out what caused it?

## Lab 5: Automated Reconciliation with FluxCD
**Objective:** Manage the application's lifecycle declaratively using GitOps.

### Prerequisites: Setting up a Local Git Server (Gitea)
For this lab, we will use a Git server running locally in a Docker container. This keeps the entire exercise on your 
machine.
1. **Run Gitea Container:** Start a Gitea Git server.
   ```shell
   docker run -d --name=gitea \
        -p 3000:3000 \
        -p 2222:22 \
        -v gitea-data:/data \
        gitea/gitea:latest
   ```
2. **Configure Gitea:**
   * Open http://localhost:3000 in your browser and complete the initial setup. 
   * Create a user (e.g., ```workshop``` with password ```workshop```). 
   * Create a new, empty repository named ```echo-app-flux```.

### Main Lab Steps

1. **Clean Up:**

    We will let FluxCD manage everything from now on.

    kubectl delete namespace workshop

2. **Prepare Your Repository:**

    * Clone your new, empty repository:
      ```shell
      git clone http://localhost:3000/workshop/echo-app-flux.git
      cd echo-app-flux
      ```
    * Create a Kustomize structure. This is a best practice for managing different environments.
      ```shell
      mkdir -p base overlays/staging
      ```
    * Move your manifests into ```base/```. This directory holds the common, unmodified YAML files.
      ```shell
      # Assuming your YAML files are in the current directory
      mv deployment.yaml service.yaml ingress.yaml ... base/
      ```
    * Create ```base/kustomization.yaml```. This file tells Kustomize which resources are part of the base.
      ```yaml
      # base/kustomization.yaml
      apiVersion: kustomize.config.k8s.io/v1beta1
      kind: Kustomization
      resources:
       - deployment.yaml
       - service.yaml
       - ingress.yaml
      # Add other base resources here
      ```
    * Create ```overlays/staging/kustomization.yaml```. This file defines our staging environment. It uses the base and
      can apply patches.
      ```yaml
      # overlays/staging/kustomization.yaml
      apiVersion: kustomize.config.k8s.io/v1beta1
      kind: Kustomization
      bases:
        - ../../base
      patchesStrategicMerge:
        - patch-replicas.yaml 
      ```
    * Commit and push the files:
      ```shell
      git add .
      git commit -m "Initial application manifests"
      git push
      ```

3. **Install Flux CLI:**
   * Install the CLI
     ```shell
     sudo curl -s https://fluxcd.io/install.sh | sudo bash
     ```
   * Install the flux-operator:
     ```shell
     helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
          --namespace flux-system \
          --create-namespace
     ```
4. **Bootstrap FluxCD:**
5. 
   * Now bootstrap the git-repo and the cluster:
     ```shell
     # Replace with the gitea username and repository name
     flux bootstrap gitea \
          --token-auth \
          --owner=my-gitea-username \
          --repository=my-repository-name \
          --branch=main \
          --path=clusters/my-cluster \
          --personal
     ```

5. **Watch it Work:**

   * Flux will now start reconciling the state defined in your Git repo with the cluster.

     ```shell
     # Watch the status of the reconciliation
     flux get kustomizations --watch
     
     # After a minute or two, check for your resources
     kubectl get all -n workshop
     ```

6. **The GitOps Loop in Action:**

   * Clone your forked repository locally.

   * Edit ```deployment.yaml``` and change the image tag to ```docker.io/jannemattila/echo-app:2.0```.

   * Commit and push the change:
     ```shell
     git add .
     git commit -m "Update application to v2.0"
     git push
     ```

7. **Observe the Automation:**

   * Flux checks the repository every minute by default. Watch as it detects your new commit and automatically updates the application.
     ```shell
     # Watch the commit SHA change and the reconciliation happen
     flux get gitrepository --watch
     flux get kustomizations --watch
     
     # Verify the image was updated in the deployment
     kubectl describe deployment echo-app -n workshop | grep Image
     ```

### 🤔 Reflection Questions:

* What is the "single source of truth" in this new workflow?

* What are the security and auditing benefits of managing your cluster state via Git commits?