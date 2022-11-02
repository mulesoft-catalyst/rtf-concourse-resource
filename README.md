# rtf-concourse-resource

## About

A custom [Concourse](https://concourse-ci.org/) Resource Type for [Anypoint Runtime Fabric](https://docs.mulesoft.com/runtime-fabric/).

Resources represent all external inputs to and outputs of jobs in the pipeline. Concourse comes with a few "core" resource types (e.g. git and s3), the rest are developed and supported by the Concourse [Community](https://resource-types.concourse-ci.org/).

Concourse Resource Types are implemented by a Docker container image with 3 scripts:

1. `/opt/resource/check` for checking for new versions of the resource
2. `/opt/resource/in` for pulling a version of the resource down
3. `/opt/resource/out` for idempotently pushing a version up

See [Resource Types](https://concourse-ci.org/resource-types.html) for additional information.

## Description

This Concourse Resource Type can be used for **get** & **put** operations of Mule Application assets in Anypoint Runtime Fabric. Application assets are identified using [Maven Coordinates](https://maven.apache.org/pom.html#Maven_Coordinates):

1. **G**roup Id (= Platform Organization Id)
2. **A**rtifact Id
3. **V**ersion

### `Check` Operation

The **check** operation checks the Runtime Fabric instance for new(er) deployed versions of the application asset.

* **Sample Payload**
    ```
    {
        "source": {
            "artifact_id": "mule4-workerinfo",
            "client_id": "[CLIENT ID]",
            "client_secret": "[CLIENT SECRET]",
            "environment_name": "Development",
            "fabric_name": "dev-fabric",
            "group_id": "[GROUP ID]",
            "mule_env": "dev",
            "mule_rt_version": "4.3.0",
            "uri": "anypoint.mulesoft.com"
        },
        "version": {
            "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c"
        }
    }
    ```

* **Sample Response**
    ```
    {
        "version": {
            "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c"
        },
        "metadata": [
            {
                "name": "group_id",
                "value": "8cc90329 ... 5db10edc3257"
            },
            {
                "name": "artifact_id",
                "value": "mule4-workerinfo"
            }
        ]
    }
    ```

* **Sample Output**
    ```
    echo "Runtime Fabric Concourse Resource 'check' settings"
    echo " - Using URI: ${URI}"
    echo " - Using MULE_ENV: ${MULE_ENV}"
    echo " - Using ENVIRONMENT_NAME: ${ENVIRONMENT_NAME}"
    echo " - Using GROUP_ID: ${GROUP_ID}"
    echo " - Using ARTIFACT_ID: ${ARTIFACT_ID}"

    get_token_for_connected_app
    in - client_id: [CLIENT ID]
    in - client_secret: [CLIENT SECRET]
    post - endpoint: https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token
    out - token: [OAUTH TOKEN]

    get_application_asset_from_rtf
    in - mule_env: dev
    in - environment_name: Development
    in - group_id: [GROUP ID]
    in - artifact_id: mule4-workerinfo
    in - arm_application_name: mule4-workerinfo-dev

    _get_environment_id
    in - environment_name: Development
    in - group_id:[GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/accounts/api/organizations/8cc90329 ... 5db10edc3257/environments
    out - environment_id: [ENVIRONMENT ID]

    _get_deployment_id
    in - arm_application_name: mule4-workerinfo-dev
    in - environment_id: [ENVIRONMENT ID]
    in - group_id:[GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/hybrid/api/v2/organizations/8cc90329 ... 5db10edc3257/environments/c02e8cc1 ... 3551dd0e0f75/deployments
    out - environment_id: [ENVIRONMENT ID]

    _get_deployment_version
    in - environment_id: [ENVIRONMENT ID]
    in - deployment_id: [DEPLOYMENT ID]
    in - group_id: [GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/hybrid/api/v2/organizations/8cc90329 ... 5db10edc3257/environments/c02e8cc1 ... 3551dd0e0f75/deployments/fbac10d4 ... 6d1b25994120
    out - version: 1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c

    out - version: 1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c
    ```

### `In` Operation

The **in** operation checks the Runtime Fabric instance for existing deployed application assets.

* **Sample Payload**
    ```
    {
        "source": {
            "artifact_id": "mule4-workerinfo",
            "client_id": "[CLIENT ID]",
            "client_secret": "[CLIENT SECRET]",
            "environment_name": "Development",
            "fabric_name": "dev-fabric",
            "group_id": "[GROUP ID]",
            "mule_env": "dev",
            "mule_rt_version": "4.3.0",
            "uri": "anypoint.mulesoft.com"
        },
        "version": {
            "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c"
        }
    }
    ```

* **Sample Response**
    ```
    {
        "version": {
            "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c"
        },
        "metadata": [
            {
                "name": "group_id",
                "value": "[GROUP ID]"
            },
            {
                "name": "artifact_id",
                "value": "mule4-workerinfo"
            }
        ]
    }
    ```

* **Sample Output**
    ```
    Runtime Fabric Concourse Resource 'in' settings
    - Using URI: anypoint.mulesoft.com
    - Using ENVIRONMENT_NAME: Development
    - Using GROUP_ID: [GROUP ID]
    - Using ARTIFACT_ID: mule4-workerinfo
    - Using VERSION: 1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c
    - Using FABRIC_NAME: dev-fabric
    - Using MULE_RT_VERSION: 4.3.0

    get_token_for_connected_app
    in - client_id: [CLIENT ID]
    in - client_secret: [CLIENT SECRET]
    post - endpoint: https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token
    out - token: [OAUTH TOKEN]

    out - response: {   "version": { "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c" },   "metadata": [     { "name": "group_id", "value": "[GROUP ID]"},     { "name": "artifact_id", "value": "mule4-workerinfo" }   ] }
    ```

### `Out` Operation

The **out** operation (re)deploys the application asset to the Runtime Fabric instance.

* **Sample Payload**
    ```
    {
        "source": {
            "artifact_id": "mule4-workerinfo",
            "client_id": "[CLIENT ID]",
            "client_secret": "[CLIENT SECRET]",
            "environment_name": "Development",
            "fabric_name": "dev-fabric",
            "group_id": "[GROUP ID]",
            "mule_env": "dev",
            "mule_rt_version": "4.3.0",
            "uri": "anypoint.mulesoft.com"
        },
        "params": {
            "CPU_ALLOCATION_LIMIT": "1000m",
            "CPU_ALLOCATION_RESERVED": "500m",
            "ENV_CLIENT_ID": "[CLIENT ID]",
            "ENV_CLIENT_SECRET": "[CLIENT SECRET]",
            "HAS_ENFORCE_DEPLOYING_REPLICAS_ACROSS_NODES": "false",
            "HAS_FORWARD_SSL_SESSION": "false",
            "HAS_LAST_MILE_SECURITY": "false",
            "IS_CLUSTERED": "false",
            "MEM_ALLOCATION_LIMIT": "3500Mi",
            "MEM_ALLOCATION_RESERVED": "3500Mi",
            "NUM_REPLICAS": 1,
            "PUBLIC_URL": "https://mule4-workerinfo.api-dev.example.org",
            "UPDATE_STRATEGY": "rolling"
        }
    }
    ```

* **Sample Response**
    ```
    {
        "version": {
            "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c"
        },
        "metadata": [
            {
                "name": "group_id",
                "value": "[GROUP ID]"
            },
            {
                "name": "artifact_id",
                "value": "mule4-workerinfo"
            }
        ]
    }
    ```

* **Sample Output**
    ```
    Runtime Fabric Concourse Resource 'out' settings
    - Using URI: anypoint.mulesoft.com
    - Using MULE_ENV: dev
    - Using ENVIRONMENT_NAME: Development
    - Using GROUP_ID: [GROUP ID]
    - Using ARTIFACT_ID: mule4-workerinfo
    - Using VERSION: 1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c
    - Using FABRIC_NAME: dev-fabric
    - Using MULE_RT_VERSION: 4.3.0
    - Using CPU_ALLOCATION_RESERVED: 500m
    - Using CPU_ALLOCATION_LIMIT: 1000m
    - Using MEM_ALLOCATION_RESERVED: 3500Mi
    - Using MEM_ALLOCATION_LIMIT: 3500Mi
    - Using IS_CLUSTERED: false
    - Using HAS_ENFORCE_DEPLOYING_REPLICAS_ACROSS_NODES: false
    - Using APPLICATION_DOMAIN_NAME: example.org
    - Using HAS_LAST_MILE_SECURITY: false
    - Using HAS_FORWARD_SSL_SESSION: false
    - Using UPDATE_STRATEGY: rolling
    - Using NUM_REPLICAS: 1
    - Using ENV_CLIENT_ID: [CLIENT ID]
    - Using ENV_CLIENT_SECRET: [CLIENT SECRET]

    get_token_for_connected_app
    in - client_id: [CLIENT ID]
    in - client_secret: [CLIENT SECRET]
    post - endpoint: https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token
    out - token: [OAUTH TOKEN]

    deploy_application_asset_to_rtf
    in - mule_env: dev
    in - environment_name: Development
    in - group_id: [GROUP ID]
    in - artifact_id: mule4-workerinfo
    in - version: 1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c
    in - fabric_name: dev-fabric
    in - mule_rt_version: 4.3.0
    in - arm_application_name: mule4-workerinfo-dev

    _get_environment_id
    in - environment_name: Development
    in - group_id: [GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/accounts/api/organizations/8cc90329 ... 5db10edc3257/environments
    out - environment_id: [ENVIRONMENT ID]

    _get_fabric_id
    in - fabric_name: dev-fabric
    in - group_id: [GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/workercloud/api/organizations/8cc90329 ... 5db10edc3257/fabrics
    out - fabric_id: 54111d24 ... 1deed5227103

    _get_rt_tag_version
    in - mule_rt_version: 4.3.0
    in - fabric_id: 54111d24 ... 1deed5227103
    in - group_id: [GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/runtimefabric/api/organizations/8cc90329 ... 5db10edc3257/targets/54111d24 ... 1deed5227103
    out - tag_version: 20210322-3

    _get_deployment_operation
    in - arm_application_name: mule4-workerinfo-dev
    in - group_id: [GROUP ID]
    get - endpoint: https://anypoint.mulesoft.com/hybrid/api/v2/organizations/8cc90329 ... 5db10edc3257/environments/c02e8cc1 ... 3551dd0e0f75/deployments
    out - deployment_id: [DEPLOYMENT ID]
    out - deployment_operation: PATCH

    in - cpu_allocation_reserved: 500m
    in - cpu_allocation_limit: 1000m
    in - mem_allocation_reserved: 3500Mi
    in - mem_allocation_limit: 3500Mi
    in - is_clustered: false
    in - has_enforce_deploying_replicas_across_nodes: false
    in - public_url: mule4-workerinfo.api-dev.example.org
    in - has_last_mile_security: false
    in - has_forward_ssl_session: false
    in - update_strategy: rolling
    in - num_replicas: 1
    in - env_client_id: [CLIENT ID]
    in - env_client_secret: [CLIENT SECRET]
    patch - endpoint: https://anypoint.mulesoft.com/hybrid/api/v2/organizations/8cc90329 ... 5db10edc3257/environments/c02e8cc1 ... 3551dd0e0f75/deployments/e603a524 ... f53c286ab090
    {         "name": "mule4-workerinfo-dev",         "target": {             "provider": "MC",             "targetId": "54111d24 ... 1deed5227103",             "deploymentSettings": {                 "resources": {                     "cpu": {                         "reserved": "500m",                         "limit": "1000m"                     },                     "memory": {                         "reserved": "3500Mi",                         "limit": "3500Mi"                     }                 },                 "clustered": false,                 "enforceDeployingReplicasAcrossNodes": false,                 "http": {                     "inbound": {                         "publicUrl": "mule4-workerinfo.api-dev.example.org"                     }                 },                 "jvm": {},                 "runtimeVersion": "4.3.0:20210322-3",                 "lastMileSecurity": false,                 "forwardSslSession": false,                 "updateStrategy": "rolling"             },             "replicas": 1         },             "application": {                 "ref": {                     "groupId": "8cc90329 ... 5db10edc3257",                     "artifactId": "mule4-workerinfo",                     "version": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c",                     "packaging": "jar"                 },                 "assets": [],                 "desiredState": "STARTED",                 "configuration": {                     "mule.agent.application.properties.service": {                         "applicationName": "mule4-workerinfo-dev",                         "properties": {                             "mule.env": "dev",                             "anypoint.platform.client_id": "[CLIENT ID]",                             "anypoint.platform.client_secret": "[CLIENT SECRET]"                         }                     }                 }             }         }
    out - deployment_id: [DEPLOYMENT ID]
    out - deployment_status: APPLYING
    out - application_status: RUNNING
    out - application_desired_state: STARTED
    out - response: {   "version": { "ref": "1.0.2-rc.1-4198581b5c7804800ece1cc716eb939b9e017b8c" },   "metadata": [     { "name": "group_id", "value": "8cc90329 ... 5db10edc3257"},     { "name": "artifact_id", "value": "mule4-workerinfo" }   ] }
    ```

## Usage

## Docker Steps

### Docker Registry (Optional)

Docker images are typically uploaded to a central artifact repository. The following steps are optional and describe how to setup a **local** Docker registry and how to push the Anypoint Runtime Fabric Resource image to this **local** registry.

#### Create Certificate

The local Docker registry can be accessed by external processes via HTTP/TLS, a self-signed certificate / key pair can be used, e.g.:

```
$ openssl req -x509 -nodes -new -keyout domain.key -out domain.crt -days 365 -config san.cnf
```

```
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = NL
ST = NH
L = The Hague
O = MuleSoft
OU = Integration
CN = docker.registry.com
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = docker.registry.com
```

**Note**: SAN/DNS + NO passphrase required

#### Start the Docker Registry

The `run` command can be used to start the local Docker registry + HTTP/TLS listen process based on the previously created certificate / key pair:

```
$ docker run -d \
  --restart=always \
  --name registry \
  -v "$(pwd)"/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -p 10443:443 \
  registry:2
```

**Note**: the above example binds host port **10443** to container port 443, this can be any unused port of the host system

#### Update '/etc/hosts'

Add an entry for `docker.registry.com`, e.g.:

```
localhost   docker.registry.com
```

### Docker Image (Manual)

#### Create Docker Image

Execute the Docker build command to build the Docker image, e.g.:

```
$ docker build -t rtf-concourse-resource . --no-cache
```

#### Tag Docker Image

The Docker image must be 'tagged' using the (local) Docker registry reference (e.g. `docker.registry.com:10443`), e.g.: 

```
$ docker tag rtf-concourse-resource docker.registry.com:10443/rtf-concourse-resource
```

#### Push Image to (Local) Docker Registry

Push the Docker image to the (local) Docker registry, e.g.:

```
$ docker push docker.registry.com:10443/rtf-concourse-resource
```

### Docker Image (Concourse)

See [ci](ci/) for 
building and publishing this custom Concourse Resource Type image to a Docker repository using a Concourse pipeline.

## Example Pipelines

See [mule-concourse-pipeline-example](https://github.com/mulesoft-catalyst/mule-concourse-pipeline-example/) for 
pipeline examples for **Mule 4** applications.




