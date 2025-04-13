# k0s High Availability Kubernetes on NixOS

This is a summary for bootstrapping and managing your k0s HA control plane using your NixOS system flake setup. It documents the nuanced steps required to stand up a working cluster, especially around the phased leader promotion process and networking configuration.

---

## 🛠 Prerequisites

- A working NixOS flake system with the `campground` Kubernetes suite and services.
- Vault running and preconfigured for AppRole-based secrets exchange.
- At least 3 nodes to build the control plane.
- A shared VIP (e.g. `10.8.0.88`) for HAProxy/Keepalived.

---

## 🚦 Deployment Process

### 1. Bootstrap the First Controller

Deploy your first controller with:

```nix
isLeader = true;
```

Then rebuild:

```sh
sudo nixos-rebuild switch --flake .#first-node
```

This controller will generate and push tokens + certs into Vault.

---

### 2. Add a Second Controller

Deploy second node with:

```nix
isLeader = false;
```

Once up, confirm it joined the etcd cluster:

```sh
sudo k0s etcd member-list
```

Then **redeploy it** with:

```nix
isLeader = true;
```

---

### 3. Add More Controllers

Repeat:

1. Deploy each new controller as `isLeader = false;`
2. Wait until it appears in:

   ```sh
   sudo k0s etcd member-list
   ```

3. Then redeploy it with `isLeader = true;`

This ensures a clean etcd join and safe cluster state.

---

## 🧠 Important Notes

- Use the `kubernetes` suite module to bring in **HAProxy** + **Keepalived** on **worker** nodes.
- All `k0s` tokens and certs are managed by Vault and synced via `vault-agent` and `systemd` oneshot jobs.
- The `k0s` config must keep this networking block **exactly**:

```yaml
network:
  provider: calico
  kubeProxy:
    mode: iptables
  kuberouter:
    autoMTU: true
    mtu: 0
    metricsPort: 9090
  podCIDR: 10.244.0.0/16
  serviceCIDR: 10.96.0.0/12
```

Other values caused CNI failures (pods wouldn't start).

---

## 🔍 Cluster State Check

- Control Plane Health: http://10.8.0.88:9000
- Controllers joined?

```sh
sudo k0s etcd member-list
```

- Workers joined?

```sh
sudo k0s kubectl get nodes
```

- Admin Kubeconfig:

```sh
sudo k0s kubeconfig admin > /etc/k8s/config
```

Then use `k9s` or any kubectl tools.

---

## 🧩 Worker Setup

After control plane is healthy, add workers using:

```nix
role = "worker";
isLeader = false;
```

Tokens will be pulled from Vault and the worker will auto-join via systemd and `vault-agent`.
