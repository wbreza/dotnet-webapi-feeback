# **Accelerator Components**

## Build and Run components

### Dev Containers and Codespaces

To run the app inside of a local development container, this Accelerator uses the [VS Code Remote - Containers extension](https://code.visualstudio.com/docs/remote/containers) and [Docker](https://docs.docker.com/) to build a self-contained development environment on your machine. The Remote - Containers extension leverages the [`devcontainer.json`](../.devcontainer/devcontainer.json) file to create a development container with the required settings and extensions installed. This method minimizes the set up a dev machine would require, but it requires Docker to build a container and a local instance of VS Code to connect to the development container.

Our recommended way of running the Accelerator is via [GitHub Codespaces](https://code.visualstudio.com/docs/remote/codespaces). Codespaces are also a development container defined by `devcontainer.json`, but hosted in Azure instead of on your local dev machine. Using a Codespace allows you to run this Accelerator entirely from a browser which means both VS Code and Docker are **not required** on your dev machine. You also have the option of using a local VS Code instance to connect to a Codespace.

### Initialization Script

As soon as the Accelerator is opened in a dev container or Codespace, the application runs [`init.cmd`](../init.cmd) which calls the [`scripts/webapi/init.ps1`](../scripts/webapi/init.ps1) script to build app dependencies and initialize a local instance of the database. This is what makes the Accelerator instantly runnable.

## Deployment components

### GitHub Workflows/Actions

[GitHub Workflows](https://docs.github.com/en/actions/learn-github-actions/introduction-to-github-actions) enable you to run automated tasks when you commit changes to your repo. Workflows invoke GitHub Actions which are simply sequential tasks to complete within the workflow. Workflows can be trigger-based (such as committing code) or manual.

This Accelerator's [`build workflow`](../.github/workflows/build.yaml) invokes Bicep to provision Azure resources and then calls on Porter to bundle the Web API. In the [`deploy workflow`](../.github/workflows/deploy.yaml), the GitHub Actions invoke Porter to publish the app contents to Azure assets provisioned in the build stage.

### Bicep deployment

[Bicep](https://github.com/Azure/bicep) is a Domain Specific Language for authoring Azure Resource Manager (ARM) templates. Bicep files specify which Azure Resources are created for deployment.

In this Accelerator, the build workflow invokes Bicep to create an App Service to host the app, an Azure SQL database, and an [Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview) resource to collect telemetry.

### Porter

[Porter](https://porter.sh/docs/) is a deployment technology that packages your app code, manages secrets, and configures deployment logic to produce a [CNAB bundle](https://porter.sh/faq/). It is a self-describing package that enables anyone to run the application just by Porter installed.

In the build workflow, Porter bundles the app code and sends it to your GitHub Container Registry. In the deploy workflow, Porter executes instructions to deploy the Bicep files which then creates the pre-defined Azure resources. Finally, the deploy workflow runs `porter install` which invokes Porter to pull the bundle from the GitHub Container Registry and unzip the files into an app service.
