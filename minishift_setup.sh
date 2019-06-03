#!/bin/bash

# =============================================================================
# Define Arguments and defaults
# =============================================================================

declare -A DEFAULTS

DEFAULTS[MINISHIFT_HOME]=${HOME}
# DEFAULTS[MINISHIFT_BIN]=${DEFAULTS[MINISHIFT_HOME]}/bin
DEFAULTS[MINISHIFT_TARBALL]=${DEFAULTS[MINISHIFT_HOME]}/minishift.tar.gz
DEFAULTS[MINISHIFT_VERSION]=1.34.0
DEFAULTS[KVM_DRIVER_VERSION]=0.10.0
DEFAULTS[KUBEVIRT_VERSION]=0.17.0
DEFAULTS[KUBECONFIG]=${DEFAULTS[MINISHIFT_HOME]}/kubeconfig

function usage() {
   echo "usage: $0 [options]
 -c               - CLEANUP - remove old stuff
 -d               - DEBUG - debug output
 -h               - help: print this message
 -H <directory>   - MINISHIFT_HOME - Where the .minishift cache directory is
 -B <directory>   - MINISHIFT_BIN  - Where the minishift binaries will be
 -m <version>     - MINISHIFT_VERSION
 -K <version>     - KVM_DRIVER_VERSION
 -k <version>     - KUBEVIRT_VERSION
 -C <file>        - KUBECONFIG    - The kubeconfig file
 -v               - VERBOSE - informative output
"
}

function process_args() {
    while getopts "cdhvH:B:m:k:C:" opt; do
        case $opt in
            H )
                MINISHIFT_HOME=$OPTARG
                ;;
            B )
                MINISHIFT_BIN=$OPTARG
                ;;
            m )
                MINISHIFT_VERSION=$OPTARG
                ;;
            K )
                KVM_DRIVER_VERSION=$OPTARG
                ;;
            k )
                KUBEVIRT_VERSION=$OPTARG
                ;;
            C )
                KUBECONFIG=$OPTARG
                ;;
            c ) CLEANUP='true'
                ;;
            d ) DEBUG='true'
                ;;
            v ) VERBOSE='true'
                ;;
            h ) usage
                exit
                ;;
        esac
    done
}

function apply_defaults() {
    for KEY in "${!DEFAULTS[@]}"; do
        if [ -z $(eval 'echo $'${KEY}) ] ; then
            eval "$KEY=${DEFAULTS[$KEY]}"
        fi
    done

    if [ -z "${MINISHIFT_BIN}" ] ; then
        MINISHIFT_BIN=${MINISHIFT_HOME}/bin
    fi

    export MINISHIFT_HOME
    export PATH=${MINISHIFT_BIN}:$PATH
}

# function apply_defaults() {
#     for KEY in "${!DEFAULTS[@]}"; do
#         if $(eval "[ $(echo $KEY)z != z ]")  ; then
#             eval "$KEY=${DEFAULTS[$KEY]}"
#         fi
#     done
# }

function verbose_args() {
    echo "--- ARGS ---"
    echo "MINISHIFT_HOME=${MINISHIFT_HOME}"
    echo "MINISHIFT_BIN=${MINISHIFT_BIN}"
    echo "MINISHIFT_VERSION=${MINISHIFT_VERSION}"
    echo "KVM_DRIVER_VERSION=${KVM_DRIVER_VERSION}"
    echo "KUBEVIRT_VERSION=${KUBEVIRT_VERSION}"
    echo "KUBECONFIG=${KUBECONFIG}"
    echo "------------"
}

function cleanup() {
    [ -x ${MINISHIFT_BIN}/minishift ] && ${MINISHIFT_BIN}/minishift delete --force
    rm -f ${MINISHIFT_BIN}/{minishift,docker-machine-driver-kvm,virtctl,kubectl,oc}
    rm -f ${MINISHIFT_TARBALL}
    [ -d ${MINISHIFT_HOME}/.minishift ] && rm -r ${MINISHIFT_HOME}/.minishift
    rm -f ${KUBECONFIG}
}

function cleanup_old_runs() {
    rm -rf ${MINISHIFT_HOME}/.minikube
    rm -f ${KUBECONFIG}
}

# ============================================================================
# Utility Functions
# ============================================================================
function verbose() {
    [ -z "${VERBOSE+x}" ] || echo $*
}

function debug() {
    [ -z "${DEBUG+x}" ] || echo $*
}

# =============================================================================
# Process Functions
# =============================================================================

function define_file_locations() {
    KUBECTL=${MINISHIFT_BIN}/oc
    MINISHIFT=${MINISHIFT_BIN}/minishift
    KVM_DRIVER=${MINISHIFT_BIN}/docker-machine-driver-kvm
    VIRTCTL=${MINISHIFT_BIN}/virtctl
}

function create_working_directories() {
    [ -d ${MINISHIFT_BIN} ] || mkdir -p ${MINISHIFT_BIN}
    [ -d ${MINISHIFT_HOME} ] || mkdir -p ${MINISHIFT_HOME}
}

function install_openshift_client() {
    echo installing openshift client
}

function install_kubectl() {
    curl --silent -L -o ${KUBECTL} https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod a+x ${KUBECTL}
}

function install_minishift() {
    verbose installing minishift
    curl -L -o ${MINISHIFT_TARBALL} https://github.com/minishift/minishift/releases/download/v${MINISHIFT_VERSION}/minishift-${MINISHIFT_VERSION}-linux-amd64.tgz

    tar -xzvf ${MINISHIFT_TARBALL} \
        minishift-${MINISHIFT_VERSION}-linux-amd64/minishift \
        --to-stdout >  ${MINISHIFT_BIN}/minishift
    chmod a+x ${MINISHIFT_BIN}/minishift
}

function copy_oc() {
    find ${MINISHIFT_HOME}/cache/oc -type f -name oc | xargs -I{} cp {} ${MINISHIFT_BIN}/oc
    chmod a+x ${MINISHIFT_BIN}/oc
}

function install_kvm_driver() {
    curl -L -o ${KVM_DRIVER} https://github.com/dhiltgen/docker-machine-kvm/releases/download/v${KVM_DRIVER_VERSION}/docker-machine-driver-kvm-centos7 
    chmod +x ${KVM_DRIVER}
}

function install_virtctl() {
    curl --silent -L -o ${VIRTCTL} https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/virtctl-v${KUBEVIRT_VERSION}-linux-amd64
    chmod a+x ${VIRTCTL}
}

function enable_nested_virt_emulation() {
    ${KUBECTL} create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
}

function install_kubevirt() {
    local version=$1
    ${KUBECTL} apply -f https://github.com/kubevirt/kubevirt/releases/download/v${version}/kubevirt-operator.yaml
    enable_nested_virt_emulation
    ${KUBECTL} apply -f https://github.com/kubevirt/kubevirt/releases/download/v${version}/kubevirt-cr.yaml
}

# ============================================================================
# MAIN
# ============================================================================
process_args $@
apply_defaults

[ -z "${VERBOSE+x}" ] || verbose_args

if [ ! -z "${CLEANUP+x}" ] ; then
    cleanup
    exit
fi

define_file_locations
create_working_directories

install_openshift_client
install_minishift
copy_oc
install_kvm_driver
install_virtctl

${MINISHIFT_BIN}/minishift start

oc login -u system:admin

enable_nested_virt_emulation
install_kubevirt ${KUBEVIRT_VERSION}
