# Opinionated CKAD: Workshop Exercises & Commands
This document contains the step-by-step instructions, commands, and reflection questions for each lab session. The goal is not just to run the commands, but to understand the output and what is happening in the cluster.

## Prerequisites:

* A working KinD cluster.

* ```kubectl``` configured to point to your KinD cluster.

* A copy of this workshop's application repository.

* Set up the kubeconfig: 
  ```shell 
  kind get kubeconfig -n observability > ~/kubeconfig
  export KUBECONFIG=~/kubeconfig
  ```

## Lab 1: Deploying Your First Application
**Objective:** Master the fundamentals of deploying and exposing a stateless application.

1. **Create your Workspace:**

   * Namespaces provide logical isolation. Let's create one for our work.

     ```shell
     kubectl create namespace workshop
     ```

   * **Verify:** ```kubectl get namespaces```

2. **Create a Deployment Manifest:**

   * Use the "golden command" to generate the YAML for a Deployment. This saves you from writing it from scratch.
     ```shell
     kubectl create deployment echo-app --image=ockadws.azurecr.io/workshop/echo-app:1.0 --replicas=2 --dry-run=client -o yaml > deployment.yaml
     ```

   * **Inspect:** Open deployment.yaml. Note the replicas, selector, and template sections.

3. **Deploy the Application:**

   * Apply the manifest to your target namespace.

     ```shell 
     kubectl apply -f deployment.yaml -n workshop
     ```
   * **Observe:** What happens?
     * KinD may need to load the image beforehand: ```kind load docker-image ockadws.azurecr.io/workshop/echo-app:1.0 -n observability``` 

4. **Inspect the Deployment:**

   * Check the status of the Deployment and the Pods it created.
     ```bash
     # See the high-level status of the deployment
     kubectl get deployment echo-app -n workshop
     
     # See the individual pods that were created
     kubectl get pods -n workshop
     
     # Get even more details about a specific pod
     kubectl describe pod <your-pod-name> -n workshop
     ```
5. **Scale the Application:**

   * Use an imperative command to change the number of replicas.

     ```shell
     kubectl scale deployment echo-app --replicas=3 -n workshop
     ```

   * Verify: ```kubectl get pods -n workshop```. You should now see three pods.

6. **Expose the Application Internally (ClusterIP):**

   * This service will give our pods a stable internal IP address.
   
     ```shell
     kubectl expose deployment echo-app --port=8080 --name=echo-service -n workshop
     ```
     
   * **Inspect:** ```kubectl get service echo-service -n workshop```. Note the ```CLUSTER-IP```.

7. **Expose the Application Externally (NodePort):**

   * This service will make the application accessible from outside the cluster for testing.

     ```shell
     kubectl expose deployment echo-app --port=8080 --name=echo-service-external --type=NodePort -n workshop
     ```

    * **Inspect:** ```kubectl get service echo-service-external -n workshop```. Note the ```PORT(S)``` value (e.g., ```8080:3xxxx/TCP```).

8. **Test Access:**

   * Forward a local port to the internal ClusterIP service.

     ```shell
     # In a new terminal
     kubectl port-forward svc/echo-service 8080:8080 -n workshop
     ```

   * Now, access the application from your machine: ```curl http://localhost:8080```

### 🤔 Reflection Questions:

* Look at the YAML for the Deployment and the Service. How does the Service know which Pods to send traffic to? (Hint: selector and labels).

* Why did we need a Service at all? What would happen if we tried to connect directly to a Pod's IP address?

## Lab 2: Dynamic Application Configuration
**Objective:** Decouple application configuration from the container image using ConfigMaps.

1. **Create a Configuration File:**
   ```shell
   echo "Welcome to the Opinionated CKAD Workshop!" > message.txt
   ```

2. **Create a ConfigMap:**

   * Create the ConfigMap resource in Kubernetes from your local file.
   ```shell
   kubectl create configmap app-config --from-file=message.txt -n workshop
   ```

   * **Inspect:** kubectl describe configmap app-config -n workshop

3. **Update the Deployment to Use the ConfigMap:**

   * Edit your ```deployment.yaml``` file. You need to add two sections: volumes at the pod level (spec.template.spec) and volumeMounts at the container level (spec.template.spec.containers[0]).
     ```yaml
     # ... inside deployment.yaml
     spec:
       template:
         spec:
           volumes: # Add this section
             - name: config-volume
               configMap:
                 name: app-config
           containers:
             - name: echo-app
               image: ockadws.azurecr.io/workshop/echo-app:1.0
               volumeMounts: # Add this section
                 - name: config-volume
                   mountPath: /config
     # ...
     ```
4. **Apply the Changes:**

   * Kubernetes will perform a rolling update, replacing the old pods with new ones that have the volume mounted.

     ```shell
     kubectl apply -f deployment.yaml -n workshop
     ```

5. **Verify the Configuration:**

   * Check that the application is now using the message from the ConfigMap.
     ```shell
     # Use the port-forward from Lab 1 if it's still running
     curl http://localhost:8080
     ```


6. **Perform a Runtime Update:**

   * This is the powerful part. Edit the ConfigMap directly in the cluster.
     ```shell
     kubectl edit configmap app-config -n workshop
     ```

   * Change the message value inside the editor and save your changes.

   * **Wait about 30-60 seconds.** The Kubelet needs time to sync the change to the mounted file.

   * **Verify again:** ```curl http://localhost:8080```. The message should be updated, and the pods were not restarted!

### 🤔 Reflection Questions:

* Why is mounting a ConfigMap as a volume often better than injecting it as an environment variable?

* What kind of applications can benefit from this live-reload capability? What kind cannot?

## Lab 3: Hardening the Application Spec
**Objective:** Make the application more reliable and secure.

1. **Add Health Probes and Resources:**

   * Edit deployment.yaml again. Add livenessProbe, readinessProbe, and resources blocks to the container spec.
     ```yaml
     # ... inside deployment.yaml, under spec.template.spec.containers[0]
               ports:
                 - containerPort: 8080
               readinessProbe:
                 httpGet:
                   path: /healthz
                   port: 8080
                 initialDelaySeconds: 5
                 periodSeconds: 5
               livenessProbe:
                 httpGet:
                   path: /healthz
                   port: 8080
                 initialDelaySeconds: 15
                 periodSeconds: 20
               resources:
                 requests:
                   cpu: "100m"
                   memory: "64Mi"
                 limits:
                   cpu: "200m"
                   memory: "128Mi"
     # ...
     ```

2. **Add a Security Context:**

   * Still in ```deployment.yaml```, add a securityContext block to the container spec.
     ```yaml
     # ... inside deployment.yaml, under spec.template.spec.containers[0]
               resources:
                 # ...
               securityContext:
                 allowPrivilegeEscalation: false
                 runAsNonRoot: true
                 runAsUser: 1001
                 readOnlyRootFilesystem: true
     # ...
     ```

3. **Create a Secret:**

   * Secrets are for sensitive data. We create them imperatively here for simplicity.
     ```shell
     kubectl create secret generic api-key --from-literal=API_KEY='supersecret123' -n workshop
     ```

4. **Inject the Secret as an Environment Variable:**

   * Finally, add an env block to the container spec in deployment.yaml.

     ```shell
     # ... inside deployment.yaml, under spec.template.spec.containers[0]
               securityContext:
                 # ...
               env:
                 - name: API_KEY
                   valueFrom:
                     secretKeyRef:
                       name: api-key
                       key: API_KEY
     # ...
     ```

5. **Apply and Verify Everything:**
    ```shell
    kubectl apply -f deployment.yaml -n workshop
    
    # Wait for the new pods to be ready
    kubectl get pods -n workshop
    
    # Check that all our new settings are applied
    kubectl describe pod <your-new-pod-name> -n workshop
    
    # Exec into the pod to check the environment variable
    kubectl exec <your-new-pod-name> -n workshop -- env | grep API_KEY
    ```
### 🤔 Reflection Questions:

* In the ```describe pod``` output, what is the "QoS Class"? Why is it set to that value?

* What is the difference between a ```readinessProbe``` failure and a ```livenessProbe``` failure?
