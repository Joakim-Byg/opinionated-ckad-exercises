# Opinionated CKAD: Workshop Exercises & Commands
This document contains the step-by-step instructions, commands, and reflection questions for each lab session. The goal is not just to run the commands, but to understand the output and what is happening in the cluster.

## Prerequisites:

* A working KinD cluster.

* ```kubectl``` configured to point to your KinD cluster.

* A copy of this workshop's application repository.

## Lab 4: Visualizing Your Application's Health
**Objective:** Gain visibility into the application using the Grafana stack.

1. **Deploy the Observability Stack:**

   * (Instructor will provide manifests/commands to deploy Grafana, Loki, Tempo, Prometheus, and the Otel Collector).

2. **Access Grafana:**

   * The instructor will provide the URL or port-forward command to access the Grafana UI.

3. **Guided Exploration:**

   * **Find Your Logs:**

     * In Grafana, go to the "Explore" tab.
    
     * Select the "Loki" data source.
    
     * Use the Log browser or a LogQL query like ```{namespace="workshop"}``` to find your application's logs.

   * **Find Your Metrics:**

     * In the "Explore" tab, select the "Prometheus" or "Mimir" data source.

     * In the query box, start typing ```http_requests_total``` and select the metric for your app.

     * Click "Run query" to see a graph of requests over time.

   * **Find Your Traces:**

     * In the "Explore" tab, select the "Tempo" data source.

     * Click "Search" to find recent traces from your application. Click on one to see the full request lifecycle.

4. **Bonus Lab: Create an Alert:**

   * Navigate to "Alerting" in the Grafana side menu.

   * Create a new "Alert rule".

   * Use the Prometheus data source.

   * Create a query that will trigger an alert. For example: ```http_requests_total{job="echo-app"} == 0```

   * Configure the rule to fire if the condition is met for 1 minute.

### 🤔 Reflection Questions:

* How could you use metrics to decide when to scale your application?

* You see an error in the logs. How would you use a trace to find out what caused it?

## Lab 5: Automated Reconciliation with FluxCD
**Objective:** Manage the application's lifecycle declaratively using GitOps.

1. **Clean Up:**

    We will let FluxCD manage everything from now on.

    kubectl delete namespace workshop

2. **Prepare Your Repository:**

   * Ensure your forked Git repository contains the final ```deployment.yaml``` from Lab 3, along with manifests for the ```namespace```, ```service```, ```configmap```, and ```secret```.

3. **Install Flux CLI:**

   * (Instructor will provide OS-specific instructions for installing the ```flux``` CLI).

4. **Bootstrap FluxCD:**

   * This magical command installs Flux into your cluster and configures it to watch your repository.
     ```shell
     # Replace with your GitHub username and repository name
     flux bootstrap github \
         --owner=<YOUR_GITHUB_USERNAME> \
         --repository=<YOUR_REPOSITORY_NAME> \
         --branch=main \
         --path=./ \
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