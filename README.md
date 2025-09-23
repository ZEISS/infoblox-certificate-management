# Introduction 
Contains resources to manage certificate challanges with InfoBlox backend via ESB.

# Installation of cert-manager custom webhook

1. Add Helm Repository
```
helm repo add certmanager-webhook-infoblox https://zeiss.github.io/infoblox-certificate-management/certmanager/charts
```

2. Install Helm-Chart
```
helm install infoblox-solver certmanager-webhook-infoblox/infoblox-solver -n cert-manager
```

3. Add ClusterIssue to cert-manager
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-infoblox
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: email@zeiss.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-infoblox-secret
    # Enable the dns01 challenge provider
    solvers:
      - dns01:
          webhook:
            groupName: com.zeiss.infoblox <-- value must not be changed
            solverName: infoblox-solver <-- value must not be changed
            config:
              esbApiKey:
                key: esbApiKey
                name: infoblox-secret
              infobloxUser:
                key: infobloxUser
                name: infoblox-secret
              infobloxPassword:
                key: infobloxPassword
                name: infoblox-secret
```