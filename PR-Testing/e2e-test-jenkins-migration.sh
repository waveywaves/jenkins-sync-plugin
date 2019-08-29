#!/bin/bash

wait-for-build () {
    local build_name=$1
    while true; do
        echo "Waiting for ${build_name} to complete"
        status=$( oc get build "${build_name}" -o jsonpath='{ .status.phase }' )
        if [[ "${status}" == "New" ||  "${status}" == "Pending" ||  "${status}" == "Running" ]]; then
            sleep 3
        fi
        if [[  "${status}" == "Complete" ]]; then
            return 0
        fi
        if [[  "${status}" == "Failed" ||  "${status}" == "Error" ||  "${status}" == "Cancelled" ]]; then
            return 1
        fi
    done
}


NAMESPACE=$1
oc project $NAMESPACE || oc new-project $NAMESPACE
oc new-app jenkins-persistent

SRC_PIPELINE=nodejs-ex-pipeline
DST_PIPELINE=nodejs-ex-pipeline-2
GIT_REPO=https://github.com/waveywaves/nodejs-ex
GIT_CONTEXT=openshift/pipelines
JENKINS_BASE_DIR_PREFIX=/var/lib/jenkins/jobs/$NAMESPACE/jobs/${NAMESPACE}


# Waiting for jenkins deployment to be ready
echo "Waiting for jenkins deployment to be ready"
oc rollout status deploymentconfig jenkins --watch

oc new-app $GIT_REPO  --context-dir=$GIT_CONTEXT --name $SRC_PIPELINE
oc patch  bc $SRC_PIPELINE -p '{ "spec" : { "runPolicy" : "Parallel" }}'


# Create 4 others builds in parallel
oc start-build $SRC_PIPELINE &
oc start-build $SRC_PIPELINE &
oc start-build $SRC_PIPELINE &
oc start-build $SRC_PIPELINE &
oc start-build $SRC_PIPELINE &

# Create the destination pipeline for migration, delete the auto-started build and annotate it
oc new-app $GIT_REPO  --context-dir=$GIT_CONTEXT --name $DST_PIPELINE
oc delete build "${DST_PIPELINE}"-1
oc annotate bc $DST_PIPELINE jenkins.openshift.io/disable-job-prune=true


wait-for-build ${SRC_PIPELINE}-5

JENKINS_POD=$(oc get pods --no-headers --selector=name=jenkins | cut -f1 -d\  )
echo "Must execute this in pod $JENKINS_POD"
echo "cp -fr $JENKINS_BASE_DIR_PREFIX-${SRC_PIPELINE}/builds/ $JENKINS_BASE_DIR_PREFIX-${DST_PIPELINE}/builds/"
oc exec $JENKINS_POD -- cp -fr $JENKINS_BASE_DIR_PREFIX-${SRC_PIPELINE}/builds/ $JENKINS_BASE_DIR_PREFIX-${DST_PIPELINE}/
oc get --export builds --selector=buildconfig=$SRC_PIPELINE -o yaml | sed s/$SRC_PIPELINE/$DST_PIPELINE/g | oc create -f -






