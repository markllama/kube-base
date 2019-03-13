# kube-base
A set of scripts to create a small baseline Kubernetes environment

For testing, it is often desirable to run demos and labs in several
different small Kubernetes environments. With this it is possible to
offer people running the labs to use the environment that is best
suited to them.

These scripts use a set of existing tools to deploy one of the listed
kubernetes environments for the user.

The scripts use CLI based tools so that they can be used to automate
the deployment and cleanup process and so that they can be used as a
model for other automation methods.

The cloud based examples require an account, credentials and the
presence of the CLI SDK for that cloud.

## Minikube

    minikube_setup.sh

## Minishift

    minishift-setup.sh

## Kubevirt cloud in AWS

    aws_instance.sh

## Kubevirt cloud in GCP

    gcloud_instance.sh
