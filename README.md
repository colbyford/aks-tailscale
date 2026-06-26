# AKS + Tailscale

<h3 align="right">Colby T. Ford, Ph.d.</h3>

Azure Kubernetes Deployment with Tailscale Network Integration

> [!NOTE]
> This assumes you have the Azure CLI and kubectl installed and configured on your local machine. Plus, you need to have an Azure account and Subscription along with a Tailscale account and be able to generate an auth key.


## Deploy

After creating a Resource Group, login using `az login` and deploy with the Bicep using the following command:

```sh
az deployment group create \
  --resource-group rg-tsk8s-dev-eastus-001 \
  --template-file main.bicep
```

Next, connect to your AKS cluster using the following command:

```sh
az aks get-credentials \
    --resource-group rg-tsk8s-dev-eastus-001 \
    --name aks-tsk8s-dev-eastus-001 \
    --overwrite-existing
```

## Configure

From the Tailscale site, navigate to your Access Controls (https://login.tailscale.com/admin/acls/file) screen and modify/add the following entries in the tagOwners section:

```json
"tagOwners": {
  "tag:k8s-operator": [],
  "tag:k8s": ["tag:k8s-operator"],
}
```



### Create an OAuth Client

Go to the Tailscale Admin Console - OAuth Clients (https://login.tailscale.com/admin/settings/oauth)

Click *Generate OAuth client*.

Grant the client the write scope for:
- General/Services (add tag:k8s-operator)
- Devices/Core (add tag:k8s-operator)
- Keys/Auth Keys (add tag:k8s-operator)

The operator uses tags to identify the devices it creates in your tailnet.

```sh
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="<CLIENT ID>" \
  --set-string oauth.clientSecret="<CLIENT SECRET>" \
  --wait
```

### Create the Tailnet API Service and ProxyGroup

For the API service, run `kubectl apply -f tailnet-service.yaml`

For the ProxyGroup, run `kubectl apply -f proxy-group.yaml`


## Test

Once you see all of the pods running in AKS, and the devices in your Tailscale account, you can test the connectivity by running the following command to describe the proxy group:

```sh
kubectl describe proxygroup aks-cluster
```

You should look for a status message of "ProxyGroupReady". Then, at the bottom of the output, you should see the IP addresses to the devices along with a URL to the service.

```yaml
... 
 Devices:
    Hostname:  aks-cluster-0
    Tailnet I Ps:
      100.91.137.1
      fd7a:115c:a1e0::ce39:8902
    Hostname:  aks-cluster-1
    Tailnet I Ps:
      100.104.66.16
      fd7a:115c:a1e0::eb39:4211
  URL:   https://aks-cluster.tailf28a3c.ts.net
Events:  <none>
```

Now update kubectl to use your new Tailscale-based connection. Run the following command: (and change the URL to yours from above)

```sh
kubectl config set-cluster aks-tailscale \
  --server=https://aks-cluster.<YOUR TAILNET>.ts.net
```