### ✅ Create a temporary `Secret` token manually:

```bash
kubectl -n external-secrets create token vault-auth --duration=24h > token.jwt
kubectl -n external-secrets get configmap kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > ca.crt
```

Then run:

```bash
vault auth enable kubernetes

vault write auth/kubernetes/config \
  token_reviewer_jwt="$(< token.jwt)" \
  kubernetes_host="https://10.8.0.197:6443" \
  kubernetes_ca_cert="$(< ca.crt)"

vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces="*" \
  policies=campground \
  ttl=24h


```
