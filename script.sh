#!/usr/bin/env bash

#set -x

#dns create_hosted_zone drosi.k8s

export S3_KOPS_STATE_STORE=s3://pmalek-kops-state
export REGION=eu-west-1
export ZONE=${REGION}a
export FILE_OUT_YAML=./out.yaml
export DESTROY_LOG=./destroy.log
export SSH_RSA_PUB=${HOME}/.ssh/prod_rsa.pub
export DOMAIN=pmal.k8s.sumologic.net
# got with:
# dev hcvault cli_env

source .env

case $1 in
    create)
        set -e

        # https://devhints.io/bash
        # Getting options section
        while [[ "$2" =~ ^- ]] ; do
          case $2 in
          -i | --interactive )
            INTERACTIVE_YAML_EDIT=1
            ;;

          *)
            ;;
        esac; shift; done

        aws s3 ls "${S3_KOPS_STATE_STORE}" >/dev/null 2>&1 || \
          aws s3 mb "${S3_KOPS_STATE_STORE}" --region "${REGION}" >/dev/null 2>&1

        echo "kops is creating .yaml..."
        kops create cluster \
          --name "${DOMAIN}" \
          --zones "${ZONE}" \
          --state "${S3_KOPS_STATE_STORE}" \
          --container-runtime containerd \
          --yes --dry-run --output yaml \
          --kubernetes-version=1.18.16 > "${FILE_OUT_YAML}"


        # This is for instance needed to add e.g.:
        # kubelet:
        #   anonymousAuth: false
        #   authenticationTokenWebhook: true
        #   authorizationMode: Webhook
        #
        # Requirement listed here https://github.com/kubernetes-sigs/metrics-server#requirements
        #
        # ref: https://github.com/kubernetes-sigs/metrics-server/issues/212#issuecomment-459321884
        if [[ ${INTERACTIVE_YAML_EDIT} ]]; then
          read -r -p "You may now edit ${FILE_OUT_YAML} before kops will apply it. When ready press enter..."
        fi

        echo "kops is creating the cluster..."
        kops create \
          --name "${DOMAIN}" \
          --state "${S3_KOPS_STATE_STORE}" -f "${FILE_OUT_YAML}"

        echo "kops is creating the secret..."
        kops create secret \
          --name "${DOMAIN}" \
          --state "${S3_KOPS_STATE_STORE}" \
          sshpublickey admin -i "${SSH_RSA_PUB}"

        echo "kops update cluster..."
        kops update cluster \
          --state "${S3_KOPS_STATE_STORE}" \
          "${DOMAIN}" --yes
        ;;

    validate)
        echo "kops describe cluster..."
        kops validate cluster \
          --state "${S3_KOPS_STATE_STORE}"
        ;;

    edit)
        echo "kops edit cluster..."
        kops edit cluster \
          --state "${S3_KOPS_STATE_STORE}" \
          "${DOMAIN}"
        ;;

    edit-instancegroups)
        echo "kops edit instancegroups..."
        kops edit instancegroups \
          --state "${S3_KOPS_STATE_STORE}" \
          "nodes-${ZONE}"
        ;;

    get)
        echo "kops get cluster..."
        kops get cluster -o yaml \
          --state "${S3_KOPS_STATE_STORE}" \
          "${DOMAIN}"
        ;;

    export)
        echo "kops export..."
        set -x
        kops export kubecfg "${DOMAIN}" \
          --state "${S3_KOPS_STATE_STORE}" \
          --admin
        ;;

    update)
        echo "kops update cluster..."
        kops update cluster \
          --state "${S3_KOPS_STATE_STORE}" \
          "${DOMAIN}" --yes

        echo "kops rolling-update cluster..."
        kops rolling-update cluster \
          --state "${S3_KOPS_STATE_STORE}" \
          "${DOMAIN}" --yes
        ;;

    destroy)
        echo "kops delete cluster..."
        kops delete cluster \
          --name "${DOMAIN}" \
          --state "${S3_KOPS_STATE_STORE}" \
          --yes | tee "${DESTROY_LOG}"

        echo "aws delete bucket..."
        ;;

    delete-state-bucket)
        aws s3 ls "${S3_KOPS_STATE_STORE}" >/dev/null 2>&1 && \
          aws s3 rb "${S3_KOPS_STATE_STORE}" >/dev/null 2>&1

        # czyszczenie
        # kops delete -f ${FILE_OUT_YAML} --yes
        ;;

    *)
        # For invalid arguments, print the usage message.
        echo "Invalid usage"
        exit 2
        ;;
esac


