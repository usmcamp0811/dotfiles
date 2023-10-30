# Vault Path Checker

If you try to run this flake and are don't have Vault setup with the correct KV engines
the flake might take a long time to fail and it might not be super clear what is wrong.
I made this so that you can just quickly check the table this package outputs to see
if you missed any `vault-path`. This is still very much a work in progress. It currently
requires you to run it from the root of the Flake. 

```bash
nix build .\#check-vault-paths
./result/bin/check-vault-paths
```

This should output a table that looks like this:

```
+-----------------------------------------+------+---------+---------+-----------------+----------+--------+------+--------+------+
|                                         | alex | ata-nuc | ata-xps | ata-xps-mboterf | aws-test | butler | daly | mattis | webb |
+-----------------------------------------+------+---------+---------+-----------------+----------+--------+------+--------+------+
|           boterfhome_v1/wifi            |  -   |    -    |    -    |        X        |    -     |   -    |  -   |   -    |  -   |
|  campground-pki/issue/vpn-client-role   |  -   |    -    |    -    |        -        |    -     |   ✓    |  ✓   |   -    |  -   |
|  campground-pki/issue/vpn-server-role   |  -   |    -    |    -    |        -        |    -     |   -    |  ✓   |   -    |  -   |
|    secret/campground/database-users     |  -   |    -    |    -    |        -        |    -     |   -    |  -   |   ✓    |  ✓   |
|          secret/campground/k0s          |  -   |    -    |    ✓    |        -        |    -     |   -    |  ✓   |   ✓    |  ✓   |
|          secret/campground/k8s          |  -   |    ✓    |    -    |        -        |    -     |   ✓    |  -   |   -    |  -   |
|         secret/campground/ldap          |  -   |    ✓    |    ✓    |        -        |    -     |   ✓    |  ✓   |   ✓    |  ✓   |
| secret/campground/local-users-passwords |  -   |    ✓    |    ✓    |        -        |    -     |   ✓    |  ✓   |   ✓    |  ✓   |
|      secret/campground/photoprism       |  -   |    -    |    -    |        -        |    -     |   -    |  -   |   -    |  ✓   |
|         secret/campground/searx         |  -   |    -    |    -    |        -        |    -     |   -    |  ✓   |   -    |  -   |
|         secret/campground/users         |  -   |    X    |    X    |        -        |    -     |   X    |  X   |   X    |  X   |
|      secret/campground/users/mcamp      |  -   |    ✓    |    ✓    |        -        |    -     |   ✓    |  ✓   |   ✓    |  ✓   |
|      secret/campground/vaultwarden      |  -   |    -    |    -    |        -        |    -     |   -    |  -   |   ✓    |  ✓   |
|         secret/campground/wifi          |  -   |    -    |    -    |        -        |    -     |   ✓    |  -   |   -    |  -   |
|          secret/campground/zfs          |  -   |    -    |    ✓    |        -        |    -     |   -    |  ✓   |   ✓    |  ✓   |
+-----------------------------------------+------+---------+---------+-----------------+----------+--------+------+--------+------+
```


## How it works

- Basically I have a Nix function (`findVaultPaths`) that I added that recursively scans all the modules to find `vault-path` attributes.
It then returns the `vault-path` if the module is enabled. 
- Then there is 2 shell scripts that are written in Nix that get used to turn the output of the Nix function into a `json` grouped by 
system.
- Finally there is a Python script that turns the `json` into a nice pretty table. 


## Bugs / TODOs

- I need to figure out how to not return the `user-secrets` `vault-path` with out the user name appended to it. This is harder than 
it should be. This is due to using a Nix function to get most of the work done and my ignorance with Nix loops.
- The thing takes too long to run. I do some recursive looping over `campground` to find all the modules that contain `vault-path` 
so that I don't have to hard code anything and forget to update it. 
- Want to add an argument to the script so I can pass a single host name and it will only do the table for that host(s). 


