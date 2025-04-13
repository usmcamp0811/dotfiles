# k0s High Availability with NixOS Modules

This README documents important nuances and implementation notes when running k0s in high availability (HA) mode using a custom NixOS module and Vault-based secret distribution.

---

## ✅ Basic Setup Flow

1. **Designate one controller as the leader** using `isLeader = true;` in the module options.
2. Boot the leader controller first.
3. It will generate:
   - Join tokens
   - Cluster certificates
   - Admin kubeconfig
   - Then store all of it in Vault.
4. Non-leader controllers and workers fetch these from Vault and join using the token files.

---

## ⚠️ Required Behavior (Observed in Practice)

> This is not clearly stated in the k0s docs, but is necessary for a successful multi-controller setup.

### 🔄 Controller Boot Order

- After bringing up the first controller:
  - Boot the second controller using the token from the first.
  - **Before booting the third controller**, you must:
    1. Run `k0s token create --role controller` on the **second** controller.
    2. Use that token to start the third controller.

This is counterintuitive (you’d think all tokens would come from the first controller), but in practice **this chaining is required**.

---

## 🛑 HAProxy Backend Health Checks

If you see backends as DOWN in HAProxy stats:

- Ensure `k0s.yaml` was loaded on that controller (some ports aren't bound otherwise)
- Verify all controller nodes are using identical configuration
- Check that the service is running with `--config` (not just `--token-file`)

---

## 🧪 Kubeconfig Fallbacks

If you want `k9s` or `kubectl` to work even if the leader is offline:

- All controllers must bind the API on `externalAddress` + `sans`
- Set `isLeader = true` on all controllers if necessary (experimental workaround)
- Future improvement: generate kubeconfigs with multiple server entries for fallback

---

## 🔒 Vault Tokens

Each node fetches token and cert material from Vault:

- `k0s-token-controller` or `k0s-token-worker`
- Required PKI: `ca.key`, `sa.key`, `etcd-ca.key`, etc.

If you’re reusing the Vault secrets, ensure consistency across reboots or reinstallations.

---

## 🛠️ Module Improvements To-Do

- [ ] Share `k0s.yaml` across all controllers automatically
- [ ] Fix need for chaining tokens per controller
- [ ] Support fallback HA in kubeconfig
- [ ] Create a “first-run-only” system for the leader

---

> Inspired by the k0s docs: https://docs.k0sproject.io/v1.32.3+k0s.0/configuration/ha/
