#!/usr/bin/env bash

RESPONSE=$(mktemp /tmp/rtf-concourse-resource-response.XXXXXX)

get_token_for_user() {
    local username="$1"
    local password="$2"
    local endpoint="https://${3}/accounts/login"

    printf "get_token_for_user\n"
    printf "   in - username: ${username}\n"
    printf "   in - password: ****************\n"
    printf " post - endpoint: ${endpoint}\n"
    
    local body="{ 
        \"username\": \"${username}\",
        \"password\": \"${password}\"
    }"
    local status=$(curl --location --request POST "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Content-Type: application/json" \
        --data-raw "${body}")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        ACCESS_TOKEN=$(cat $RESPONSE | jq -r '.access_token')
        printf "  out - token: ${ACCESS_TOKEN}\n"
        export ACCESS_TOKEN 
    fi
}

get_token_for_connected_app() {
    local client_id="$1"
    local client_secret="$2"
    local endpoint="https://${3}/accounts/api/v2/oauth2/token"

    printf "get_token_for_connected_app\n"
    printf "   in - client_id: ${client_id}\n"
    printf "   in - client_secret: ****************\n"
    printf " post - endpoint: ${endpoint}\n"
    
    local body="{ 
        \"client_id\": \"${client_id}\",
        \"client_secret\": \"${client_secret}\",
        \"grant_type\": \"client_credentials\"
    }"
    local status=$(curl --location --request POST "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Content-Type: application/json" \
        --data-raw "${body}")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        ACCESS_TOKEN=$(cat $RESPONSE | jq -r '.access_token')
        printf "  out - token: ${ACCESS_TOKEN}\n"
        export ACCESS_TOKEN
    fi
}

_get_environment_id() {
    environment_name="${2}"
    local group_id="${3}"
    local endpoint="https://${1}/accounts/api/organizations/${group_id}/environments"

    printf "_get_environment_id\n"
    printf "   in - environment_name: ${environment_name}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export environment_name    
        ENVIRONMENT_ID=$(cat $RESPONSE | jq -c '.data[] | select(.name == $ENV.environment_name)' | jq -rc '.id')
        printf "  out - environment_id: ${ENVIRONMENT_ID}\n"
        export ENVIRONMENT_ID
    fi
}

_get_fabric_id() {
    fabric_name="${3}"
    local group_id="${2}"
    local endpoint="https://${1}/workercloud/api/organizations/${group_id}/fabrics"

    printf "_get_fabric_id\n"
    printf "   in - fabric_name: ${fabric_name}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export fabric_name    
        FABRIC_ID=$(cat $RESPONSE | jq -c '.[] | select(.name == $ENV.fabric_name)' | jq -rc '.id')
        printf "  out - fabric_id: ${FABRIC_ID}\n"
        export FABRIC_ID
    fi
}

_get_rt_tag_version() {
    mule_rt_version="${3}"
    local fabric_id="${4}"
    local group_id="${2}"
    local endpoint="https://${1}/runtimefabric/api/organizations/${group_id}/targets/${fabric_id}"

    printf "_get_rt_tag_version\n"
    printf "   in - mule_rt_version: ${mule_rt_version}\n"
    printf "   in - fabric_id: ${fabric_id}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export mule_rt_version    
        TAG_VERSION=$(cat $RESPONSE | jq -c '.runtimes[].versions[] | select(.baseVersion == $ENV.mule_rt_version)' | jq -rc '.tag')
        printf "  out - tag_version: ${TAG_VERSION}\n"
        export TAG_VERSION
    fi
}

_get_deployment_operation() {
    local application_name="${3}"
    local group_id="${2}"
    local endpoint="https://${1}/hybrid/api/v2/organizations/${group_id}/environments/${ENVIRONMENT_ID}/deployments"

    printf "_get_deployment_operation\n"
    printf "   in - arm_application_name: ${arm_application_name}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export application_name    
        DEPLOYMENT_ID=$(cat $RESPONSE | jq -c '.items[] | select(.name == $ENV.application_name)' | jq -rc '.id')
        printf "  out - deployment_id: ${DEPLOYMENT_ID}\n"
        export DEPLOYMENT_ID
        if [ -z "$DEPLOYMENT_ID" ]; then
            export DEPLOYMENT_OPERATION=POST
        else
            export DEPLOYMENT_OPERATION=PATCH
        fi
        printf "  out - deployment_operation: ${DEPLOYMENT_OPERATION}\n"
    fi
}

deploy_application_asset_to_rtf() {
    local uri="${1}"
    local mule_env="${2}"
    local environment_name="${3}"
    local group_id="${4}"
    local artifact_id="${5}"
    local version="${6}"
    local fabric_name="${7}"
    local mule_rt_version="${8}"
    local arm_application_name="${5}-${mule_env}"
    
    printf "deploy_application_asset_to_rtf\n"
    printf "   in - mule_env: ${mule_env}\n"
    printf "   in - environment_name: ${environment_name}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "   in - artifact_id: ${artifact_id}\n"
    printf "   in - version: ${version}\n"
    printf "   in - fabric_name: ${fabric_name}\n"
    printf "   in - mule_rt_version: ${mule_rt_version}\n"
    printf "   in - arm_application_name: ${arm_application_name}\n"
    
    printf "\n" &&  \
    _get_environment_id ${uri} ${environment_name} ${group_id} && \
    printf "\n" &&  \
    _get_fabric_id ${uri} ${group_id} ${fabric_name} && \
    printf "\n" &&  \
    _get_rt_tag_version ${uri} ${group_id} ${mule_rt_version} ${FABRIC_ID} && \
    printf "\n"
    _get_deployment_operation ${uri} ${group_id} ${arm_application_name}
    printf "\n"

    local cpu_allocation_reserved="${9}"
    local cpu_allocation_limit="${10}"
    local mem_allocation_reserved="${11}"
    local mem_allocation_limit="${12}"
    local is_clustered="${13}"
    local has_enforce_deploying_replicas_across_nodes="${14}"
    local public_url="${15}"
    local has_last_mile_security="${16}"
    local has_forward_ssl_session="${17}"
    local update_strategy="${18}"
    local num_replicas="${19}"
    local env_client_id="${20}"
    local env_client_secret="${21}"
    local endpoint="https://${1}/hybrid/api/v2/organizations/${group_id}/environments/${ENVIRONMENT_ID}/deployments"
    if [ ! -z ${DEPLOYMENT_ID} ]; then
        endpoint="${endpoint}/${DEPLOYMENT_ID}"
    fi

    printf "   in - cpu_allocation_reserved: ${cpu_allocation_reserved}\n"
    printf "   in - cpu_allocation_limit: ${cpu_allocation_limit}\n"
    printf "   in - mem_allocation_reserved: ${mem_allocation_reserved}\n"
    printf "   in - mem_allocation_limit: ${mem_allocation_limit}\n"
    printf "   in - is_clustered: ${is_clustered}\n"
    printf "   in - has_enforce_deploying_replicas_across_nodes: ${has_enforce_deploying_replicas_across_nodes}\n"
    printf "   in - public_url: ${public_url}\n"
    printf "   in - has_last_mile_security: ${has_last_mile_security}\n"
    printf "   in - has_forward_ssl_session: ${has_forward_ssl_session}\n"
    printf "   in - update_strategy: ${update_strategy}\n"
    printf "   in - num_replicas: ${num_replicas}\n"
    printf "   in - env_client_id: ${env_client_id}\n"
    printf "   in - env_client_secret: ****************\n"
    if [ ${DEPLOYMENT_OPERATION} == "POST" ]; then
        printf " post - endpoint: ${endpoint}\n"
    else
        printf "patch - endpoint: ${endpoint}\n"
    fi

    local body="{ \
        \"name\": \"${arm_application_name}\", \
        \"target\": { \
            \"provider\": \"MC\", \
            \"targetId\": \"${FABRIC_ID}\", \
            \"deploymentSettings\": { \
                \"resources\": { \
                    \"cpu\": { \
                        \"reserved\": \"${cpu_allocation_reserved}\", \
                        \"limit\": \"${cpu_allocation_limit}\" \
                    }, \
                    \"memory\": { \
                        \"reserved\": \"${mem_allocation_reserved}\", \
                        \"limit\": \"${mem_allocation_limit}\" \
                    } \
                }, \
                \"clustered\": ${is_clustered}, \
                \"enforceDeployingReplicasAcrossNodes\": ${has_enforce_deploying_replicas_across_nodes}, \
                \"http\": { \
                    \"inbound\": { \
                        \"publicUrl\": \"${public_url}\" \
                    } \
                }, \
                \"jvm\": {}, \
                \"runtimeVersion\": \"${mule_rt_version}:${TAG_VERSION}\", \
                \"lastMileSecurity\": ${has_last_mile_security}, \
                \"forwardSslSession\": ${has_forward_ssl_session}, \
                \"updateStrategy\": \"${update_strategy}\" \
            }, \
            \"replicas\": ${num_replicas} \
        }, \
            \"application\": { \
                \"ref\": { \
                    \"groupId\": \"${group_id}\", \
                    \"artifactId\": \"${artifact_id}\", \
                    \"version\": \"${version}\", \
                    \"packaging\": \"jar\" \
                }, \
                \"assets\": [], \
                \"desiredState\": \"STARTED\", \
                \"configuration\": { \
                    \"mule.agent.application.properties.service\": { \
                        \"applicationName\": \"${arm_application_name}\", \
                        \"properties\": { \
                            \"mule.env\": \"${mule_env}\", \
                            \"anypoint.platform.client_id\": \"${env_client_id}\", \
                            \"anypoint.platform.client_secret\": \"${env_client_secret}\" \
                        } \
                    } \
                } \
            } \
        }"
    local status=$(curl --location --request "${DEPLOYMENT_OPERATION}" "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json" \
        --data-raw "${body}")
    if [ ${DEPLOYMENT_OPERATION} == "POST" ]; then
        if [ ${status} != '202' ]; then
            printf "  err - ${status}: $(cat $RESPONSE)\n"
            exit 1
        fi
    else
        if [ ${status} != '200' ]; then
            printf "  err - ${status}: $(cat $RESPONSE)\n"
            exit 1
        fi
    fi
    
    DEPLOYMENTID=("$(cat $RESPONSE | jq -r '.id')")
    DEPLOYMENTSTATUS=("$(cat $RESPONSE | jq -r '.status')")
    APPLICATIONSTATUS=("$(cat $RESPONSE | jq -r '.application.status')")
    APPLICATIONDESIREDSTATE=("$(cat $RESPONSE | jq -r '.application.desiredState')")
    printf "  out - deployment_id: ${DEPLOYMENTID}\n"
    printf "  out - deployment_status: ${DEPLOYMENTSTATUS}\n"
    printf "  out - application_status: ${APPLICATIONSTATUS}\n"
    printf "  out - application_desired_state: ${APPLICATIONDESIREDSTATE}\n"
    export DEPLOYMENTID
}

_get_deployment_id() {
    local environment_id="${2}"
    arm_application_name="${3}"
    local group_id="${4}"
    local endpoint="https://${1}/hybrid/api/v2/organizations/${group_id}/environments/${environment_id}/deployments"

    printf "_get_deployment_id\n"
    printf "   in - arm_application_name: ${arm_application_name}\n"
    printf "   in - environment_id: ${environment_id}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export arm_application_name 
        DEPLOYMENT_ID=$(cat $RESPONSE | jq -c '.items[] | select(.name == $ENV.arm_application_name)' | jq -rc '.id')
        printf "  out - deployment_id: ${DEPLOYMENT_ID}\n"
        export DEPLOYMENT_ID
    fi
}

_get_deployment_version() {
    local environment_id="${2}"
    local deployment_id="${3}"
    local group_id="${4}"
    local endpoint="https://${1}/hybrid/api/v2/organizations/${group_id}/environments/${environment_id}/deployments/${deployment_id}"

    printf "_get_deployment_version\n"
    printf "   in - environment_id: ${environment_id}\n"
    printf "   in - deployment_id: ${deployment_id}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "  get - endpoint: ${endpoint}\n"

    local status=$(curl --location --request GET "${endpoint}" \
        --output ${RESPONSE} --silent --write-out "%{http_code}" \
        --header "Authorization: bearer ${ACCESS_TOKEN}" \
        --header "Content-Type: application/json")
    if [ ${status} != '200' ]; then
        printf "  err - ${status}: $(cat $RESPONSE)\n"
        exit 1
    else
        export arm_application_name 
        VERSION=$(cat $RESPONSE | jq -rc '.application.ref.version')
        printf "  out - version: ${VERSION}\n"
        export VERSION
    fi
}

get_application_asset_from_rtf() {
    local uri="${1}"
    local mule_env="${2}"
    local environment_name="${3}"
    local group_id="${4}"
    local artifact_id="${5}"
    local arm_application_name="${5}-${mule_env}"

    printf "get_application_asset_from_rtf\n"
    printf "   in - mule_env: ${mule_env}\n"
    printf "   in - environment_name: ${environment_name}\n"
    printf "   in - group_id: ${group_id}\n"
    printf "   in - artifact_id: ${artifact_id}\n"
    printf "   in - arm_application_name: ${arm_application_name}\n"

    printf "\n" &&  \
    _get_environment_id ${uri} ${environment_name} ${group_id} && \
    printf "\n" &&  \
    _get_deployment_id ${uri} ${ENVIRONMENT_ID} ${arm_application_name} ${group_id} && \
    printf "\n" &&  \
    _get_deployment_version ${uri} ${ENVIRONMENT_ID} ${DEPLOYMENT_ID} ${group_id}
    printf "\n"

    printf "  out - version: ${VERSION}\n"
    export VERSION
}