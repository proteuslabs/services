KUBECONFIG=kubeconfig
SERVER=https://$CLUSTER_URL
SERVICE_ACCOUNT=$SERVICE_ACCOUNT
NAMESPACE=$NAMESPACE
CLUSTER_NAME=$CLUSTER_NAME

SECRET_NAME=$(kubectl get --namespace=$NAMESPACE serviceaccounts --namespace=prod -o json $SERVICE_ACCOUNT | jq -r '.secrets[0].name')

echo "secret name: $SECRET_NAME"

kubectl get secret --namespace=$NAMESPACE -o json $SECRET_NAME | jq -r '.data["ca.crt"]' | base64 -d > ca.crt
TOKEN=$(kubectl get secret --namespace=$NAMESPACE -o json $SECRET_NAME | jq -r '.data.token' | base64 -d)

kubectl config --kubeconfig=$KUBECONFIG set-cluster $CLUSTER_NAME --server=$SERVER --certificate-authority=ca.crt --embed-certs=true 
kubectl config --kubeconfig=$KUBECONFIG set-credentials $CLUSTER_NAME --certificate-authority=ca.crt --token=$(echo $TOKEN)
kubectl config --kubeconfig=$KUBECONFIG set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME --user=$CLUSTER_NAME
kubectl config --kubeconfig=$KUBECONFIG use-context $CLUSTER_NAME
