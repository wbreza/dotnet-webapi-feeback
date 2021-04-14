# **Tips and Tricks**

As you get more familiar with the code base, we want you to feel empowered to customize and run the Accelerator however you wish. This section provides some tips to modify the build and deployment process.

## Run your app in a VS Code development container

If you do not have access to Codespaces or would like to try using an Accelerator in a VS Code dev container, follow these steps:

1. Install [VS Code](https://code.visualstudio.com/download).
1. Install the [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) to take advantage of the [`devcontainer.json`](../.devcontainer/devcontainer.json) file.
1. Install [Docker Desktop or Docker Engine](https://www.docker.com/get-started) to ensure a dev container can be built locally.
1. Open a terminal on your PC and use Git to clone the repository you just created.
1. Change the directory to the new folder (``cd <git-clone-folder-name>``)
1. Enter `code .` to launch VS Code from this folder.
1. When prompted, click **Reopen in Container** in the lower right. This command leverages the [`devcontainer.json`](../.devcontainer/devcontainer.json) file to run VS Code inside of a development environment with all required installations and extensions.
1. Return to the [Run the app](../README.md#run-the-app) section to continue the Quick Start.

### Run your app in Visual Studio (Windows)

If you do not have access to Codespaces nor VS Code, you have the option to run the .NET Accelerator in Visual Studio.

1. Install [Visual Studio](https://visualstudio.microsoft.com/downloads/).
1. Install [Docker Desktop](https://www.docker.com/get-started) so the SQL database can be run in a container locally.
1. Open a terminal on your PC and use Git to clone the repository you just created.
1. Change the directory to the new folder (``cd <git-clone-folder-name>``)
1. Open the solution file named `webapi-dotnet.sln` in Visual Studio.
1. Open a command prompt in the repository root folder (**Tools** -> **Command Prompt**) and run the initialization script:

    ```shell
    C:\code\webapi-dotnet> .\init.cmd
    ```

    This script will start and populate the database used by the web API.
1. Hit <kbd>F5</kbd> to start debugging.

## Run the app without debugging

- Enter `dotnet run --project src/webapi/webapi.csproj` from the terminal.
- Open a browser to http://localhost:5000/index.html.

## Web API modifications

This is a standard .NET Web API. The source code is in the [`src/webapi folder`](../src/webapi/). To edit which APIs are available, modify [`src/webapi/Controllers/MyDataController.cs`](../src/webapi/Controllers/MyDataController.cs).

## Database modifications

There are two scripts that create and populate the database. First, [`scripts/webapi/create-structure.sql`](../scripts/webapi/create-structure.sql) creates the data model, then [`scripts/webapi/sample-data.sql`](../scripts/webapi/sample-data.sql) adds sample data to the table.

**Exporting SQL database schema and data to a BACPAC file** <br/>
During cloud deployment, the database is created and seeded using a BACPAC file. If you need to change your database structure, you can use the following steps to produce a new BACPAC file that reflects the updated schema:

1. Install the [sqlpackage tool](https://docs.microsoft.com/sql/tools/sqlpackage/sqlpackage-download)
2. Export the database content to the BACPAC file. Replace `your-password` as necessary:

    ```shell
    ~/bin/sqlpackage/sqlpackage /Action:export /OverwriteFiles:true /SourceServerName:localhost /SourceDatabaseName:webapidb /SourceUser:sa /SourcePassword:your-password /p:TableData=dbo.MyData /TargetFile:./scripts/bundle/webapidb.bacpac
    ```

## GitHub Workflow modifications

A GitHub Workflow is comprised of multiple GitHub Actions to automate tasks in the development outer loop. The build workflow is found in [`.github/workflows/build.yaml`](../.github/workflows/build.yaml) and the deploy workflow is found in [`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml). Learn more about [creating a new workflow](https://docs.github.com/en/actions/quickstart).

## Porter deployment modifications

Porter executes a series of tasks in order to bundle your code for deployment. The Porter manifest is found in [`src/bundle/porter.yaml`](../src/bundle/porter.yaml). Learn more about [authoring Porter bundles](https://porter.sh/author-bundles/).

> **Note:** When changes to `porter.yaml` are pushed to the repo, this will automatically trigger the [`build.yaml`](../.github/workflows/build.yaml) workflow.

## Bicep deployment modifications

The [`src/infra folder`](../src/infra/) contains multiple `.bicep` files. Each file declares Azure resources required by the application (Web API, Azure SQL, Application Insights). The [`main.bicep`](../src/infra/main.bicep) file joins the declarations of each component. Learn more about [authoring Bicep files](https://github.com/Azure/bicep/tree/main/docs/tutorial).

## Environments YAML file

The [`.github/environments/environments.yaml`](../.github/environments/environments.yaml) file manages the configuration of the Azure deployment.

> **Note:** When changes to `environments.yaml` are pushed to the repo, this will automatically trigger the [`deploy.yaml`](../.github/workflows/deploy.yaml) workflow.

## Modifying the deployment resource group name

The `ENVIRONMENT_NAME_PREFIX` attribute prefixes the selected value to both the resource group and each resource deployed by the application. Modify this attribute in [`.github/environments/environments.yaml`](../.github/environments/environments.yaml).

```yml
...
config:
    AZURE_LOCATION: "northeurope"
    ENVIRONMENT_NAME_PREFIX: "test"
```

## Clean and Rebuild your dev environment

The [`.devcontainer folder`](../.devcontainer/) contains all of the development environment configuration to run the application in Codespaces or a dev container. When changes are made to **any file** in this folder, you must open the Command Palette (`Ctrl + Shift + P`  or `CMD + Shift + P`) and run **Remote-Containers: Rebuild and Reopen in Container**.
