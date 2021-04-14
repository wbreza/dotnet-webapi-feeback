#!/usr/bin/env bash

# Pipelines are considered failed if any of the constituent commands fail
set -o pipefail

usage()
{
    cat <<END
dev-deploy [-u | --uninstall] [--no-build] [--no-deploy] <resource name prefix> <environment prefix> <region>

Deploys the dotnet-webapi sample to specified Azure region by performing the following steps:
  1. Build the Bicep template for creating application's Azure assets.
  2. Build the application and zip the binaries for deployment.
  3. Create resource gropup for the application.
  4. Create Azure assets: the secret key vault, storage account
     App Service instance, and SQL server instance.
  5. Initialize and seed the database.
  6. Deploy the web site to the App Service instance.

Options:
  -u --uninstall
    Instead of installing, un-installs the app by deleting the application 
    resource group and purging its key vault.
    Region parameter can be omitted when uninstalling
  --no-build
    Do not perform ARM template and application build, just deploy the app.
  --no-deploy
    Just do the ARM template and application build, do not deploy the app.

Example invocation: dev-deploy nwa210310a dev westus2

Assumptions: 
  1. Current directory is the repository root.
  2. The environment has Azure CLI, jq, sed, and openssl installed.
  3. The user is logged in into Azure via Azure CLI, 
     and the desired Azure subscription is set.

Names of Azure resources often need to be globally unique. 
Use <resource name prefix> parameter to ensure that.
To avoid name validation issues use only lowercase letters and numbers 
for both parameter values.
END
}

uninstalling=""
no_build=""
no_deploy=""

while :
do
    case "$1" in
        -u | --uninstall )
            uninstalling='yes'; shift ;;
        --no-build )
            no_build='yes'; shift ;;
        --no-deploy )
            no_deploy='yes'; shift ;;
        *)
            break ;;
    esac
done

if [[ (($# -lt 2) || ($# -gt 3)) && (! $no_deploy) ]]; then
    usage
    exit 1
fi

resource_name_prefix=$1
environment_prefix=$2
region=$3

if [[ (! $uninstalling) && (! $no_deploy) && (! $region) ]]; then
    usage
    exit 1
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

get_name_suffix() {
    declare -r resource_group_name=$1
    declare resource_group_id
    
    resource_group_id=$(az group show --resource-group "$resource_group_name" | jq -r '.id')
    if [[ $? -ne 0 ]]; then
        echo "Resource group id could not be retrieved"
        exit 201
    fi

    declare -r suffix=$(${script_dir}/str-hash.sh ${resource_group_id})
    echo $suffix
}

if [[ (! $no_build) && (! $uninstalling) ]]; then
    echo "Building ARM template..."
    mkdir --parents "${script_dir}/output/arm" && \
        az bicep build -f "${script_dir}/../infra/main.bicep" && \
        az bicep build -f "${script_dir}/../infra/dbrestore.bicep" && \
        mv "${script_dir}/../infra/main.json" "${script_dir}/output/arm" && \
        mv "${script_dir}/../infra/dbrestore.json" "${script_dir}/output/arm"
    if [[ $? -ne 0 ]]; then
        echo "There was an error in the ARM template build"
        exit 2
    fi 

    echo "Building the application..."
    dotnet publish --output "${script_dir}/output/webapi" "${script_dir}/../webapi/webapi.csproj" && \
        pushd "${script_dir}/output/webapi" && \
        zip -r ../webapi.zip . && \
        mv -f ../webapi.zip . && \
        popd
    if [[ $? -ne 0 ]]; then
        echo "There was an error during application build"
        exit 3
    fi
fi

if [[ $no_deploy ]]; then
    exit 0
fi

resource_group_name="rg-dotnetwebapi-${resource_name_prefix}-${environment_prefix}"

if [[ $uninstalling ]]; then
    echo "Uninstalling application..."

    suffix=$(get_name_suffix ${resource_group_name})

    az group delete --yes --resource-group "$resource_group_name"
    if [[ $? -ne 0 ]]; then
        echo "Application could not be uninstalled"
        exit 103
    fi

    keyvault_name="${resource_name_prefix}-${environment_prefix}-${suffix}"
    az keyvault purge --name "$keyvault_name"
    if [[ $? -ne 0 ]]; then
        echo "Key valut '${keyvault_name}' could not be deleted"
        exit 104
    fi

    echo "Application uninstalled"
    exit 0
fi

echo "Creating resource group '${resource_group_name}'..."
az group create --resource-group "$resource_group_name" --location "$region"
if [[ $? -ne 0 ]]; then
    echo "Resource group could not be created"
    exit 4
fi

suffix=$(get_name_suffix ${resource_group_name})
keyvault_name="${resource_name_prefix}-${environment_prefix}-${suffix}"
deployment_name="deploy-${resource_name_prefix}-${environment_prefix}"
db_deployment_name="db-deploy-${resource_name_prefix}-${environment_prefix}"
website_name="web-${resource_name_prefix}-${environment_prefix}-${suffix}"
storage_account_name="stor${resource_name_prefix}${environment_prefix}${suffix}"
storage_container_name="storct-${resource_name_prefix}-${environment_prefix}"
sql_server_name="sql-${resource_name_prefix}-${environment_prefix}-${suffix}"
web_app_name="app-${resource_name_prefix}-${environment_prefix}-${suffix}"
log_analytics_workspace_name="log-${resource_name_prefix}-${environment_prefix}-${suffix}"

echo "Creating storage account..."
az storage account create \
    --name "$storage_account_name" \
    --resource-group "$resource_group_name" \
    --location "$region" \
    --sku Standard_LRS
if [[ $? -ne 0 ]]; then
    echo "Storage account could not be created"
    exit 5
fi

echo "Retrieving storage account key..."
storage_account_key=$(az storage account keys list --account-name "$storage_account_name" --resource-group "$resource_group_name" | jq --raw-output '.[0].value')
if [[ $? -ne 0 ]]; then
    echo "Storage account key could not be retrieved"
    exit 6
fi

echo "Creating storage container for database intialization file..."
az storage container create \
    --name "$storage_container_name" \
    --account-key "$storage_account_key" \
    --account-name "$storage_account_name"
if [[ $? -ne 0 ]]; then
    echo "Storage container could not be created"
    exit 7
fi

echo "Uploading database initialization file..."
az storage blob upload \
    --container-name "$storage_container_name" \
    --file "$script_dir/webapidb.bacpac" \
    --account-key "$storage_account_key" \
    --account-name "$storage_account_name" \
    --name webapidb.bacpac 
if [[ $? -ne 0 ]]; then
    echo "Database initialization file could not be uploaded"
    exit 8
fi

echo "Create Azure assets..."
sql_password=$(openssl rand -base64 14 | sed 's/[^a-zA-Z0-9]//g')
deployment_result=$(az deployment group create \
    --resource-group "$resource_group_name" \
    --name "$deployment_name" \
    --template-file "${script_dir}/output/arm/main.json" \
    --parameters \
        defaultResourceNamePrefix=${resource_name_prefix} \
        environmentNamePrefix=${environment_prefix} \
        sqlServerAdminPassword=${sql_password} \
        sqlServerName=${sql_server_name} \
        keyVaultName=${keyvault_name} \
        webAppName=${web_app_name} \
        logAnalyticsWorkspaceName=${log_analytics_workspace_name})
if [[ $? -ne 0 ]]; then
    echo "App Service and SQL Server deployment failed"
    exit 9
fi

web_app_name=$(echo "$deployment_result" | jq -r '.properties.outputs.webAppFinalName.value')
sql_database_name=$(echo "$deployment_result" | jq -r '.properties.outputs.sqlDatabaseFinalName.value')

echo "Initializing the database..."
storage_account_endpoint="$(az storage account show --name ${storage_account_name} | jq -r '.primaryEndpoints.blob')"
db_initialization_file_url="${storage_account_endpoint}${storage_container_name}/webapidb.bacpac"
az deployment group create \
    --resource-group "$resource_group_name" \
    --name "$db_deployment_name" \
    --template-file "${script_dir}/output/arm/dbrestore.json" \
    --parameters \
        sqlDatabaseName=${sql_database_name} \
        sqlServerAdminPassword=${sql_password} \
        dbInitializationFileUrl=${db_initialization_file_url} \
        dbInitializationFileAccessKey=${storage_account_key}
# If we redeploy and the database exists, the above command might fail, but that is OK
# Eventually we will use a more robust database migration solution and handle errors better

echo "Deploying the website..."
az webapp deployment source config-zip \
    --name "$web_app_name" \
    --resource-group "$resource_group_name" \
    --src "${script_dir}/output/webapi/webapi.zip"
if [[ $? -ne 0 ]]; then
    echo "Website deployment failed"
    exit 10
fi

host_name=$(az webapp show --name "$web_app_name" --resource-group "$resource_group_name" | jq -r '.defaultHostName')
echo "Application deployed, the URL is https://${host_name}"
