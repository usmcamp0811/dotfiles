# 🧠 k0s Troubleshooting Guide (NixOS)

This doc summarizes all issues encountered across **controllers and workers** in my NixOS-based k0s cluster, along with how I fixed them. For future me.

---

## 1. ❌ kube-router CrashLoopBackOff

**Symptoms:**

- `CrashLoopBackOff` on `kube-router`
- Logs show: `failed to list *v1.Pod: dial tcp 10.96.0.1:443: i/o timeout`

**Cause:** API server unreachable due to either CNI failure or controller down.

**Fix:**

```sh
# Ensure kube-router's CNI config exists and is valid
cat /etc/cni/net.d/10-kuberouter.conflist

# Restart DaemonSet to trigger retry
kubectl rollout restart ds kube-router -n kube-system
```

---

## 2. ❌ API Server Unreachable (`10.96.0.1:443`)

**Symptoms:**

- All control plane traffic fails
- `curl -k https://10.96.0.1:443` hangs or fails

**Cause:** `k0s-controller` service is not running

**Fix:**

```sh
sudo systemctl restart k0s-controller
```

---

## 3. ❌ Etcd Certificate IP Mismatch

**Symptoms:**

- `x509: certificate is valid for <old IP>, not <current IP>`
- etcd peer connection errors

**Fix:**

```sh
stop k0s-controller
sudo rm -rf /var/lib/k0s
start k0s-controller
```

---

## 4. ❌ Konnectivity Tunnel Failure (`No agent available`)

**Symptoms:**

- Logs show: `Failed to get a backend: No agent available`
- Metrics server or other API extensions fail

**Cause:** konnectivity-agent failed or can’t connect

**Fix:**

```sh
kubectl rollout restart ds konnectivity-agent -n kube-system
```

---

## 5. ❌ Unable to Wipe `/var/lib/k0s/` (Device Busy)

**Symptoms:**

- `rm -rf /var/lib/k0s` fails with `Device or resource busy`

**Cause:** kubelet mountpoints still active

**Fix:**

```sh
stop k0s-worker

mount | grep /var/lib/k0s/kubelet | awk '{print $3}' | xargs -r sudo umount -l
sudo rm -rf /var/lib/k0s
```

---

## 6. ✅ How to Reset a Worker (NixOS)

**Fix:**

```sh
# Stop services and clear state
stop k0s-worker
sudo rm -rf /var/lib/k0s

# Recreate using flake config and rebuild
sudo nixos-rebuild switch --flake .#<hostname>
```

---

## 7. 🧪 Quick API Server Test

```sh
curl -k https://10.96.0.1:443
```

If unreachable, control plane is broken or CNI is borked.

---

## Notes

- Always regenerate PKI on IP changes
- Never mix k0s-managed CNI with other CNI plugins
- NixOS flake drives system config — no `k0s install` needed
- Store tokens/certs in `/config` or secrets-managed volume

---
