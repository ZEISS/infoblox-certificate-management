# Introduction 
Contains resources to manage certificate challanges with InfoBlox backend via ESB.

- CertBot Plugin --> /certbot
- Posh-ACME Plugin --> /posh-acme
- Cert-Manager Webhook --> /certmanager

# Authentication
All resources need specifc credentials to work:

- ESB API Key
- Infoblox User
- Infoblox Password

# Installation of cert-manager custom webhook

1. Install Cert-Manager

2. Add Helm Repository
```
helm repo add certmanager-webhook-infoblox https://zeiss.github.io/infoblox-certificate-management/certmanager/charts
```

3. Install Helm-Chart
```
helm install infoblox-solver certmanager-webhook-infoblox/infoblox-solver -n cert-manager
```

4. Add Secret with Infoblox & ESB credentials (will be referenced in CluserIssuer)
```
apiVersion: v1
kind: Secret
metadata:
  name: infoblox-secret
  namespace: cert-manager
type: Opaque
stringData:
  esbApiKey: <ESB API Key>
  infobloxUser: <InfoBlox User>
  infobloxPassword: <InfoBlox Password>
```

5. Add ClusterIssue to cert-manager
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-infoblox
spec:
  acme:
    # The ACME server URL
    # staging server: https://acme-staging-v02.api.letsencrypt.org/directory
    server: https://acme-v02.api.letsencrypt.org/directory
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
6. Add Certificate
```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <name>
  namespace: <namespace>
spec:
  dnsNames:
    # can include multiple dnsNames
    - '*.test.zeiss.com'
  issuerRef:
    name: letsencrypt-infoblox
    kind: ClusterIssuer
  secretName: <name of the tls secret>
```
